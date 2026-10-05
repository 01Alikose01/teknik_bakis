# Haberler Duplikasyon Düzeltme — Uygulama Planı

> **Bağımlılık sırası:** 1 → 2 → 3 → 4 → 5 (her adım bir öncekinin çıktısına bağlıdır)  
> **Dokunulmayacak:** trial, premium, Google Play Billing, geri tuşu, zorunlu güncelleme, AI sistemleri, haber ekranı görsel tasarımı

---

## Adım 1 — `kap_news_item.dart`: Model genişletme

**Dosya:** `lib/models/kap_news_item.dart`

### Mevcut durum
`KapNewsItem` 6 alanlı immutable bir sınıf: `title`, `summary`, `source`, `time`, `url`, `isWithin72h`.  
`disclosureIndex` ve `disclosureType` alanları **yok**, bu yüzden dedup anahtarı olarak KAP'ın kendi ID'si hiç kullanılamıyor.

### Yapılacak değişiklik

`const KapNewsItem({...})` constructor'ına iki nullable named parametre ekle:

```dart
final String? disclosureIndex;   // KAP bildirimi benzersiz ID (d['id'] veya Firestore docId)
final String? disclosureType;    // d['disclosureClass'] veya d['disclosure_type']
```

Constructor'da varsayılan değerleri `null`:

```dart
const KapNewsItem({
  required this.title,
  required this.summary,
  required this.source,
  required this.time,
  required this.url,
  this.isWithin72h = true,
  this.disclosureIndex,   // YENİ — opsiyonel, geriye dönük uyumlu
  this.disclosureType,    // YENİ — opsiyonel, geriye dönük uyumlu
});
```

`cleanTitle` ve `analysisText` getter'larına **dokunma**.

### Tam değişiklik
- Sınıf tanımına `final String? disclosureIndex;` ve `final String? disclosureType;` ekle (diğer `final` alanların hemen altına)
- Constructor named param listesine `this.disclosureIndex,` ve `this.disclosureType,` ekle
- Başka satır değişikliği yok

### Doğrulama
```
flutter analyze lib/models/kap_news_item.dart
```
→ Sıfır hata, modeli kullanan diğer dosyalarda da hata çıkmamalı (yeni parametreler opsiyonel olduğundan mevcut `KapNewsItem(...)` çağrıları derlenmeli).

---

## Adım 2 — `kap_news_service.dart`: `disclosureIndex`/`disclosureType` doldur ve dedup anahtarını güçlendir

**Dosya:** `lib/services/kap_news_service.dart`  
**Bağımlılık:** Adım 1 tamamlanmış olmalı (yeni alanlar mevcut olmalı)

### Mevcut durum
- **GitHub JSON path** (~satır 185-194): `KapNewsItem(title:..., url:...)` — `disclosureIndex` ve `disclosureType` hiç doldurulmuyor.  
- **KAP REST API path** (~satır 215-225): `d['id']` URL'e gömülüyor ama modele kaydedilmiyor; `disclosureClass` sadece `summary`'e yazılıyor.  
- `_buildDeduplicationKey` (~satır 266-272): `COMPANY|TITLE|TIME` üçlüsü — başlık formatı değişirse aynı bildirim iki kez görünebilir; `disclosure_type` yok.

### Yapılacak değişiklikler

#### 2a. GitHub JSON path — `disclosureIndex` ve `disclosureType` doldur

```dart
// ~satır 185-194 — rawList.map içindeki KapNewsItem(...)
KapNewsItem(
  title:          d['title']?.toString() ?? 'KAP Bildirimi',
  summary:        d['summary']?.toString() ?? '',
  source:         d['source']?.toString() ?? 'KAP',
  time:           d['time']?.toString() ?? _fmtNow(),
  url:            d['url']?.toString() ?? '',
  isWithin72h:    d['within72h'] == true,
  disclosureIndex: d['disclosureIndex']?.toString() ?? d['id']?.toString(),  // YENİ
  disclosureType:  d['disclosureType']?.toString() ?? d['disclosureClass']?.toString(),  // YENİ
)
```

#### 2b. KAP REST API path — `disclosureIndex` ve `disclosureType` doldur

```dart
// ~satır 215-225 — items.add(KapNewsItem(...))
KapNewsItem(
  title:          d['title']?.toString() ?? d['subject']?.toString() ?? 'KAP Bildirimi',
  summary:        d['disclosureClass']?.toString() ?? d['subject']?.toString() ?? '',
  source:         d['companyCode']?.toString() ?? 'KAP',
  time:           dt != null ? _fmtDate(dt) : _fmtNow(),
  url:            d['id'] != null ? 'https://www.kap.org.tr/tr/Bildirim/${d['id']}' : '',
  isWithin72h:    dt != null && dt.isAfter(cutoff),
  disclosureIndex: d['id']?.toString(),                    // YENİ
  disclosureType:  d['disclosureClass']?.toString(),       // YENİ
)
```

#### 2c. `_buildDeduplicationKey` — öncelik sırası değiştir

Mevcut metodu tamamen şununla değiştir:

```dart
static String _buildDeduplicationKey(KapNewsItem item) {
  // 1. En güvenilir: KAP'ın kendi tekil ID'si
  if (item.disclosureIndex != null && item.disclosureIndex!.isNotEmpty) {
    return 'IDX:${item.disclosureIndex}';
  }
  // 2. İkinci güvenilir: bildirim URL'i
  if (item.url.isNotEmpty) {
    return 'URL:${item.url}';
  }
  // 3. Fallback: şirket + temizlenmiş başlık + bildirim türü + zaman
  final company = item.source.trim().toUpperCase();
  final title = item.cleanTitle
      .toUpperCase()
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  final type = (item.disclosureType ?? '').toUpperCase();
  final time = _normalizeTime(item.time);
  return '$company|$title|$type|$time';
}
```

### Doğrulama
```
flutter analyze lib/services/kap_news_service.dart
```
→ Sıfır hata.

---

## Adım 3 — `kap_disclosure_service.dart`: docId ile `disclosureIndex`, `disclosure_type` ile `disclosureType`, title önceliği düzelt

**Dosya:** `lib/services/kap_disclosure_service.dart`  
**Bağımlılık:** Adım 1 tamamlanmış olmalı

### Mevcut durum
- `fetchLatest` (~satır 52): `.map((doc) => _docToNewsItem(doc.data()))` — `doc.id` (= `disclosureIndex`) `_docToNewsItem`'a **aktarılmıyor**.  
- `fetchByStockCode` (~satır 76): aynı sorun.  
- `_docToNewsItem` (~satır 93): `title` için `company_title` öncelikli → şirket adını gösteriyor, `subject` (bildirimin konusu) ikinci sırada. `disclosureIndex` ve `disclosureType` **hiç doldurulmuyor**.

### Yapılacak değişiklikler

#### 3a. `fetchLatest` — map çağrısını güncelle

```dart
// ~satır 52 — eski:
.map((doc) => _docToNewsItem(doc.data()))
// yeni:
.map((doc) => _docToNewsItem(doc.data(), docId: doc.id))
```

#### 3b. `fetchByStockCode` — map çağrısını güncelle

```dart
// ~satır 76 — eski:
.map((doc) => _docToNewsItem(doc.data()))
// yeni:
.map((doc) => _docToNewsItem(doc.data(), docId: doc.id))
```

#### 3c. `_docToNewsItem` — imza + gövde güncelle

İmzayı değiştir:
```dart
// eski:
static KapNewsItem _docToNewsItem(Map<String, dynamic> d)
// yeni:
static KapNewsItem _docToNewsItem(Map<String, dynamic> d, {String? docId})
```

`return KapNewsItem(...)` bloğunu güncelle — üç değişiklik:

1. `title` önceliğini ters çevir: `subject` önce, `company_title` fallback:
   ```dart
   title: d['subject']?.toString() ?? d['company_title']?.toString() ?? 'KAP Bildirimi',
   ```
2. `disclosureIndex` doldur:
   ```dart
   disclosureIndex: docId,
   ```
3. `disclosureType` doldur:
   ```dart
   disclosureType: d['disclosure_type']?.toString(),
   ```

Tam güncellenmiş `return` bloğu:
```dart
return KapNewsItem(
  title:          d['subject']?.toString() ?? d['company_title']?.toString() ?? 'KAP Bildirimi',
  summary:        d['subject']?.toString() ?? d['summary']?.toString() ?? '',
  source:         d['stock_code']?.toString() ?? 'KAP',
  time:           timeDisplay,
  url:            d['detail_url']?.toString() ?? '',
  isWithin72h:    isWithin72h,
  disclosureIndex: docId,
  disclosureType:  d['disclosure_type']?.toString(),
);
```

### Doğrulama
```
flutter analyze lib/services/kap_disclosure_service.dart
```
→ Sıfır hata.

---

## Adım 4 — `news_screen.dart`: `_loadKap()` içinde `KapDisclosureService` öncelikli kullan

**Dosya:** `lib/screens/news_screen.dart`  
**Bağımlılık:** Adım 3 tamamlanmış olmalı

### Mevcut durum
`_loadKap()` (~satır 56-65) yalnızca `KapNewsService.fetch()` çağırıyor.  
Dosyanın başında `kap_disclosure_service.dart` importu **yok**.

### Yapılacak değişiklikler

#### 4a. Import ekle

Mevcut importlar bloğunda `kap_news_service.dart` satırının hemen altına:
```dart
import '../services/kap_disclosure_service.dart';
```

#### 4b. `_loadKap()` metodunu değiştir

**Sadece bu metodu** değiştir — başka hiçbir şeye dokunma:

```dart
Future<void> _loadKap() async {
  if (mounted) setState(() => _loadingKap = true);
  try {
    var items = await KapDisclosureService.fetchLatest();
    if (items.isEmpty) {
      items = await KapNewsService.fetch();
    }
    if (mounted) {
      setState(() {
        _kapNews = items;
        _loadingKap = false;
      });
    }
  } catch (_) {
    try {
      final items = await KapNewsService.fetch();
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

**Değiştirilmeyen şeyler:** `build()`, `_buildKapList()`, `_buildBorsaList()`, `_KapNewsCard`, `_BorsaNewsCard`, `initState`, `dispose`, `_loadAll`, `_loadBorsa` — bunlara ASLA dokunma.

### Doğrulama
```
flutter analyze lib/screens/news_screen.dart
```
→ Sıfır hata.

---

## Adım 5 — `borsa_news_service.dart`: URL kontrolü, zaman eşiği, Türkçe ek normalizasyonu, stop words genişletme

**Dosya:** `lib/services/borsa_news_service.dart`  
**Bağımlılık:** Diğer adımlardan bağımsız; ancak son adım olarak uygulanabilir

### Mevcut durum
- `_isDuplicate` (~satır 82): URL kontrolü yok — aynı URL farklı başlıkla gelirse tanınmıyor.  
- `_isCloseInTime` (~satır 118): eşik `<= 18` saat — günlük tekrarlayan başlıkları birleştiriyor.  
- `_canonicalText` (~satır 130): Türkçe kesme işareti eklerini (`'nın`, `'da`, `'yla` vb.) temizlemiyor — "Fransa'nın" ile "Fransa" ayrı token sayılıyor.  
- `_stopWords` (~satır 33): yaygın eylem fiilleri eksik — "imzaladı", "açıkladı" vb. token havuzunda kalıyor ve Jaccard skorunu düşürüyor.

### Yapılacak değişiklikler

#### 5a. `_isDuplicate` — başına URL kontrolü ekle

Mevcut `_isDuplicate` metodunun ilk satırı `final titleA = ...` öncesine şunu ekle:

```dart
// 1. Kesin URL eşleşmesi — en güvenilir kontrol
if (a.url.isNotEmpty && b.url.isNotEmpty && a.url == b.url) return true;
```

#### 5b. `_isCloseInTime` — eşiği 18'den 6'ya düşür

```dart
// eski:
return a.difference(b).inHours.abs() <= 18;
// yeni:
return a.difference(b).inHours.abs() <= 6;
```

#### 5c. `_canonicalText` — Türkçe kesme işareti eklerini temizle

`_canonicalText` metodunda `.replaceAll(RegExp(r'[^a-z0-9çğıöşü\s]'), ' ')` satırından **önce** şunu ekle:

```dart
.replaceAll(RegExp(r"'[a-zçğışöü]{1,4}(\s|$)"), ' ')
```

Tam güncellenmiş metod:

```dart
static String _canonicalText(String value) {
  return value
      .toLowerCase()
      .replaceAll('â', 'a')
      .replaceAll('î', 'i')
      .replaceAll('û', 'u')
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll(RegExp(r'https?://\S+'), ' ')
      .replaceAll(RegExp(r'&[a-z]+;'), ' ')
      .replaceAll(RegExp(r"'[a-zçğışöü]{1,4}(\s|$)"), ' ')  // YENİ — Türkçe ekler
      .replaceAll(RegExp(r'[^a-z0-9çğıöşü\s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
```

#### 5d. `_stopWords` — eksik eylem kelimelerini ekle

Mevcut `_stopWords` setine şu kelimeleri ekle (zaten varsa ekleme — `'açiklandi'` ve `'aciklandi'` zaten var, bunları tekrar ekleme):

```dart
'duyurdu',
'acikladi',
'açıkladı',
'imzaladi',
'imzaladı',
'onayladi',
'onayladı',
'yapti',
'yaptı',
'anlasti',
'anlaştı',
'tamamladi',
'tamamladı',
'baslatti',
'başlattı',
'sundu',
'bildirdi',
```

Dikkat: `'açiklandi'` ve `'aciklandi'` zaten `_stopWords`'te var → tekrar **ekleme**.

### Doğrulama
```
flutter analyze lib/services/borsa_news_service.dart
```
→ Sıfır hata.

---

## Tüm değişiklikler tamamlandıktan sonra

```
flutter analyze
```

→ Projenin **bu değişikliklerle ilgili** satırlarında sıfır yeni hata/warning olmalı.  
→ Önceden mevcut olan ve konu dışı eski uyarılar (başka dosyalardaki) bu task kapsamında **düzeltilmeyecek**.

---

## Değişiklik özeti tablosu

| # | Dosya | Değişiklik | Amaç |
|---|---|---|---|
| 1 | `lib/models/kap_news_item.dart` | `disclosureIndex?` ve `disclosureType?` nullable alanları + constructor parametreleri | Modeli ID taşıyabilir hale getir |
| 2 | `lib/services/kap_news_service.dart` | GitHub/REST path'lerinde yeni alanları doldur; `_buildDeduplicationKey`'i IDX→URL→fallback sırasıyla güçlendir | KAP ID'siyle kesin dedup |
| 3 | `lib/services/kap_disclosure_service.dart` | `fetchLatest`/`fetchByStockCode` map çağrılarına `docId: doc.id`; `_docToNewsItem` imzası + `disclosureIndex`/`disclosureType` doldur; title önceliği `subject` önce | Firestore'dan kesin ID'li veriler gelsin |
| 4 | `lib/screens/news_screen.dart` | Import + `_loadKap()` → Firestore önce, fallback KapNewsService | Dedup'ı bilen servis kullanılsın |
| 5 | `lib/services/borsa_news_service.dart` | URL kontrolü; 18h→6h; Türkçe ek stripping; stop words genişletme | Borsa haberlerinde dedup hassasiyetini artır |
