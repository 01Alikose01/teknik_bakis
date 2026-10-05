# KAP Haber Deduplication — Kök Neden Analizi ve Uygulama Planı

> **Dokunulmayacak sistemler:** Trial, Premium, Billing (PurchaseService), back button (PopScope), UpdateService, AI (kap_ai), Borsa haberleri deduplication kodu (BorsaNewsService), news_screen.dart görsel tasarımı, IndexedStack/MainNavigation yapısı.

---

## Kök Neden Analizi

### Neden aynı haber 4 kez görünüyordu?

`KapDisclosureService.fetchLatest()` Firestore'dan `kap_disclosures` koleksiyonunu `orderBy('updated_at', descending: true).limit(60)` ile çekiyor. Cloud Function (`syncKapDisclosures`) her 15 dakikada bir çalışıyor ve `updated_at: FieldValue.serverTimestamp()` değerini **her sync'te güncellenen tüm belgeler için** yeniden yazıyor (`{ merge: true }` ile).

**Problem 1 — Firestore'da aynı KAP bildirimi için birden fazla belge:** Cloud Function `disclosureIndex` alanını belge ID olarak kullanıyor (`db.collection('kap_disclosures').doc(discIdx)`). KAP API'den gelen bazı bildirimlerde `disclosureIndex` eksik/sıfır (`d.disclosureIndex || d.id || ''`) olduğunda `discIdx` ya `"0"` ya da farklı bir şeye çözülüyor — ancak `{ merge: true }` ile yazıldığı için aynı key'e birden fazla kez yazılmıyor. **Asıl problem farklı:**

**Problem 2 — `fetchLatest()` sonuçlarında `dedupe()` HİÇ ÇAĞRILMIYOR:**  
`KapDisclosureService.fetchLatest()` verileri döndürürken deduplication yapmıyor. `dedupe()` fonksiyonu yalnızca `KapNewsService.fetch()` içinde çağrılıyor. `_loadKap()` içinde de `dedupe()` çağrısı yok.

**Problem 3 — `disclosureIndex` olarak `docId` kullanılıyor ama `disclosure_id` alanı göz ardı ediliyor:**  
`_docToNewsItem` şunu yapıyor: `disclosureIndex: docId` (Firestore doc.id). Aynı KAP bildirimi Firestore'da **farklı `doc.id`'lerle** (örn. `"1234567"` ve `"1234567_THYAO"` veya sayısal/string uyumsuzluğu) birden fazla belgede duruyorsa, her biri farklı `IDX:` anahtarı üretiyor ve dedup çalışmıyor. Firestore belgesi ayrıca `disclosure_id` alanı da içeriyor (Cloud Function tarafından ayrıca yazılan) — bu gerçek KAP bildirim ID'si.

**Neden 4 kez:** Büyük olasılıkla Cloud Function bir süre `lastDisclosureIndex` sıfırlanmış/resetlenmiş durumda çalıştı ya da `disclosureIndex`'i yokken `d.id` farklı değerler döndürdü; sonuç olarak aynı KAP bildirimi için 4 farklı `doc.id` değeriyle 4 Firestore belgesi oluştu. Her biri `IDX:docId1`, `IDX:docId2`, `IDX:docId3`, `IDX:docId4` olarak farklı anahtar üretiyor, dedup geçmiyor.

**Neden 2 kez:** Aynı mekanizma, 2 farklı Firestore belgesi.

### Özet kök neden

Deduplication `disclosure_id` alanı (belgenin içindeki gerçek KAP ID) yerine `doc.id` (Firestore belge anahtarı) üzerinden yapılıyor. Eğer aynı KAP bildirimi farklı `doc.id`'lerle Firestore'a yazıldıysa, her biri benzersiz `IDX:` anahtarı üretiyor ve geçiyor.

**İkincil sorun:** `fetchLatest()` sonuçlarına hiç `dedupe()` uygulanmıyor. Dedup sadece `KapNewsService.fetch()` (fallback yol) içinde mevcut.

---

## Uygulama Planı

> **Bağımlılık sırası:** 1 → 2 → 3 (her adım bir öncekine bağlıdır)

---

### Adım 1 — `kap_disclosure_service.dart`: `disclosure_id` alanını `disclosureIndex` olarak kullan + `dedupe()` uygula

**Bağımlılık:** Bağımsız — ilk uygulanacak.

**Ne yapılacak:**

`_docToNewsItem` metodunda `disclosureIndex` şu anda `docId` (Firestore belge ID) ile dolduruluyor. Bunun yerine önce belgenin içindeki `d['disclosure_id']` alanını kullan; yoksa `docId`'ye düş. Cloud Function `disclosure_id: discIdx` olarak yazıyor — bu KAP'ın gerçek bildirim ID'si.

```dart
// eski:
disclosureIndex: docId,

// yeni:
disclosureIndex: d['disclosure_id']?.toString() ?? docId,
```

`fetchLatest()` ve `fetchByStockCode()` metodlarının sonunda, cache'e yazmadan önce `KapNewsService.dedupe(items)` çağır. Bu, `disclosure_id` alanı aynı olan belgeleri `IDX:` anahtarıyla eleyecek.

`fetchLatest()` güncellenmesi:
```dart
static Future<List<KapNewsItem>> fetchLatest({int limit = 60}) async {
  const cacheKey = '__latest__';
  final cached = _cache[cacheKey];
  if (cached != null &&
      DateTime.now().difference(cached.fetchedAt) < _cacheTtl) {
    return cached.items;
  }

  try {
    final snapshot = await _db
        .collection('kap_disclosures')
        .orderBy('updated_at', descending: true)
        .limit(limit)
        .get()
        .timeout(const Duration(seconds: 8));

    final rawItems = snapshot.docs
        .map((doc) => _docToNewsItem(doc.data(), docId: doc.id))
        .where((item) => item.title.isNotEmpty)
        .toList();

    // Aynı KAP bildiriminin birden fazla Firestore belgesi varsa tekilleştir
    final items = KapNewsService.dedupe(rawItems);

    _cache[cacheKey] = _CachedDisclosures(
      items: items,
      fetchedAt: DateTime.now(),
    );
    return items;
  } catch (_) {
    return cached?.items ?? [];
  }
}
```

`fetchByStockCode()` için de aynı pattern — `rawItems` → `KapNewsService.dedupe(rawItems)`.

**Dosyalar:**  
- `lib/services/kap_disclosure_service.dart`

**Import ekle** (dosyanın başına):
```dart
import 'kap_news_service.dart';
```

**Doğrulama:**
```
flutter analyze lib/services/kap_disclosure_service.dart
```
→ Sıfır hata/warning.

---

### Adım 2 — `news_screen.dart`: `_loadKap()` çıktısına da `dedupe()` uygula (ikinci savunma hattı)

**Bağımlılık:** Adım 1 tamamlanmış olmalı.

**Ne yapılacak:**

`_loadKap()` içinde, `setState`'e girmeden önce hem Firestore hem fallback sonuçlarına `KapNewsService.dedupe()` uygula. Bu, farklı kaynaklardan gelen verilerin birleşmesi durumunda da dedup'ı garanti eder.

```dart
Future<void> _loadKap() async {
  if (mounted) setState(() => _loadingKap = true);
  try {
    var items = await KapDisclosureService.fetchLatest();
    if (items.isEmpty) {
      items = await KapNewsService.fetch();
    }
    // İkinci savunma hattı: son noktada dedup
    final deduped = KapNewsService.dedupe(items);
    if (mounted) {
      setState(() {
        _kapNews = deduped;
        _loadingKap = false;
      });
    }
  } catch (_) {
    try {
      final items = KapNewsService.dedupe(await KapNewsService.fetch());
      if (mounted) {
        setState(() {
          _kapNews = items;
          _loadingKap = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingKap = false);
    }
  }
}
```

**Dosyalar:**  
- `lib/screens/news_screen.dart`

**Doğrulama:**
```
flutter analyze lib/screens/news_screen.dart
```
→ Sıfır hata/warning.

---

### Adım 3 — `flutter analyze` + AAB oluşturma

**Bağımlılık:** Adım 1 ve 2 tamamlanmış olmalı.

**Ne yapılacak:**

Tüm proje genelinde analiz çalıştır. Sonra AAB (Android App Bundle) üret.

```
flutter analyze
flutter build appbundle --release
```

**Dosyalar:**  
- Değişiklik yok — yalnızca doğrulama ve build adımı.

**Doğrulama:**
- `flutter analyze` → Bu değişikliklerle ilgili sıfır yeni hata/warning.
- `flutter build appbundle --release` → `build/app/outputs/bundle/release/app-release.aab` başarıyla oluşmalı.

---

## Özet Tablosu

| Sorun | Kök Neden | Düzeltme |
|---|---|---|
| Aynı haber **4 kez** | Firestore'da aynı KAP bildirimi 4 farklı `doc.id` ile → her biri ayrı `IDX:` anahtarı → dedup geçiyor | `disclosure_id` alanı (gerçek KAP ID) öncelikli kullan; `fetchLatest()`'e `dedupe()` ekle |
| Aynı haber **2 kez** | Aynı mekanizma, 2 farklı Firestore belgesi | Aynı düzeltme |
| **Hangi dosyada düzeltildi** | — | `kap_disclosure_service.dart` (birincil), `news_screen.dart` (ikincil savunma) |
| **Deduplication hangi ID üzerinden** | `disclosureIndex` = `d['disclosure_id']` (Firestore belge içindeki alan, Cloud Function tarafından KAP'ın gerçek `disclosureIndex`'inden yazılıyor) → `IDX:{disclosure_id}` anahtarı |

---

## Kesinlikle Dokunulmayacaklar

- `lib/services/borsa_news_service.dart` — Borsa deduplication kodu
- `lib/kap_ai/` — AI sistemleri
- `lib/screens/premium_gate_screen.dart`, `lib/screens/payment_screen.dart` — Trial/Premium/Billing
- `lib/main.dart` PopScope / back button mantığı
- `lib/services/update_service.dart` — UpdateService
- `lib/models/kap_news_item.dart` — model değişikliği yok (zaten doğru)
- `lib/services/kap_news_service.dart` — `dedupe()` ve `_buildDeduplicationKey()` zaten doğru, değiştirme
- `_KapNewsCard`, `_BorsaNewsCard`, `_buildBorsaList()`, `_buildKapList()` widget'ları — görsel tasarım değişikliği yok
