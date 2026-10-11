# KAP Haber "1 Sonuç" Sorun Raporu

## Özet Cevap

**Ana neden:** GitHub JSON'daki 151 haberin tamamı aynı URL'e sahip (`https://www.getmidas.com/kap-haberleri/`). `KapNewsService.dedupe()` fonksiyonu URL'i en güvenilir dedup anahtarı olarak kullandığından, 151 haberin tümü `"URL:https://www.getmidas.com/kap-haberleri/"` anahtarını üretiyor. `seenKeys.add(key)` yalnızca ilk çağrıda `true` döndürüyor; **150 haber elenip yalnızca 1 tanesi ekranda kalıyor**.

Bu sorun `d1bd92e` commitinde uygulanan dedup key düzeltmesinin yan etkisidir. O commit başlık zaman-öneki (`"18 Saat Önce ..."`) sorununu çözmeye çalışırken URL'in birincil anahtar olarak kullanılmasını değiştirmedi; ancak GitHub JSON'daki URL alanının tüm kayıtlarda tek ve aynı değer olduğu gözden kaçtı.

---

## Veri Akışı (Güncel)

```
Flutter Uygulaması
    │
    ├─► KapDisclosureService.fetchLatest()    ← Firestore kap_disclosures (BİRİNCİL)
    │       Firestore koleksiyonu hâlâ boş → fallback ↓
    │
    └─► KapNewsService.fetch()                ← GitHub JSON (FALLBACK — aktif yol)
              │
              ├─► GET https://raw.githubusercontent.com/Alikose010/teknik-bakis-kap/main/data/kap_news.json
              │       ✅ 200 OK, 151 kayıt, lastUpdated: 2026-10-10T19:04:28 UTC
              │
              └─► dedupe(rawList)   ← 151 → 1 kayıt  ❌ BUG BURADA
```

---

## Bulgu 1: Dedup Algoritması URL'i Birincil Anahtar Olarak Kullanıyor

`lib/services/kap_news_service.dart` → `_buildDeduplicationKey()`:

```dart
// 1. En güvenilir: KAP'ın kendi tekil ID'si
if (item.disclosureIndex != null && item.disclosureIndex!.isNotEmpty) {
  return 'IDX:${item.disclosureIndex}';
}
// 2. İkinci güvenilir: bildirim URL'i
if (item.url.isNotEmpty) {
  return 'URL:${item.url}';   // ← SORUN BURASI
}
// 3. Fallback: şirket + normalleştirilmiş başlık + bildirim türü
```

Öncelik sırası: `disclosureIndex` → `url` → `source|title|type`.

---

## Bulgu 2: GitHub JSON'daki Tüm Kayıtlar Aynı URL'e Sahip

`https://raw.githubusercontent.com/Alikose010/teknik-bakis-kap/main/data/kap_news.json` incelemesi:

| Alan | Değer |
|------|-------|
| `count` | 151 |
| `lastUpdated` | `2026-10-10T19:04:28.278445+00:00` |
| Benzersiz URL sayısı | **1** |
| URL değeri | `https://www.getmidas.com/kap-haberleri/` |
| `disclosureIndex` alanı | **Hiçbir kayıtta yok** |
| `id` alanı | **Hiçbir kayıtta yok** |

JSON'daki her kayıt yapısı:
```json
{
  "title": "23 Saat Önce Marmaris Altınyunus...",
  "summary": "",
  "source": "TBC",
  "time": "10.10.2026 19:04",
  "url": "https://www.getmidas.com/kap-haberleri/",
  "within72h": true,
  "rawDate": "2026-10-10T19:04:28.275184+00:00"
}
```

`disclosureIndex` yok → adım 1 atlanıyor.  
`url` dolu (`getmidas.com/kap-haberleri/`) → adım 2 devreye giriyor.  
Tüm 151 kayıt için aynı anahtar üretiliyor: `URL:https://www.getmidas.com/kap-haberleri/`

---

## Bulgu 3: Dedup Mantığının Çıktısı

`dedupe()` fonksiyonu `lib/services/kap_news_service.dart`:

```dart
static List<KapNewsItem> dedupe(List<KapNewsItem> items) {
  final unique = <KapNewsItem>[];
  final seenKeys = <String>{};

  for (final item in items) {
    final key = _buildDeduplicationKey(item);
    if (seenKeys.add(key)) {   // ← ilk item için true, geri kalan 150 için false
      unique.add(item);
    }
  }
  return unique;
}
```

`seenKeys.add('URL:https://www.getmidas.com/kap-haberleri/')`:
- Çağrı 1 (1. kayıt): `true` → listeye eklendi ✅
- Çağrı 2–151 (kalan 150 kayıt): `false` → hepsi elenip atıldı ❌

**Sonuç: 151 kayıt → 1 kayıt**

---

## Bulgu 4: d1bd92e Commit'inin Etkisi

Commit `d1bd92e` ("fix: KAP bildirimleri - dedup key zaman öneki + token sanitizasyonu") aşağıdaki değişikliği yaptı:

**Önceki dedup key (adım 3):**
```dart
return '$company|$title|$type|$time';
```

**Yeni dedup key (adım 3):**
```dart
return '$company|$normalizedTitle|$type';  // zaman öneki + time kaldırıldı
```

Bu düzeltme `"X Saat Önce..."` başlık varyasyonu sorununu çözmek için doğru bir adımdı — ancak adım 2 (URL kontrolü) değiştirilmedi. GitHub JSON'daki tüm kayıtların aynı `url` alanına sahip olduğu test edilmedi.

**Etki:** Commit öncesinde adım 3'e düşen kayıtlar, başlık zaman-öneki nedeniyle 150 farklı key üretiyordu (az çok doğru sayı ekranda görünüyordu). Commit sonrasında adım 2 devreye girdi ve tek bir URL-tabanlı key tüm kayıtları silip attı.

---

## Bulgu 5: Firestore Kanalı Hâlâ Devre Dışı

`KapDisclosureService.fetchLatest()` → Firestore `kap_disclosures` koleksiyonunu sorguluyor.  
Önceki analizde (`kap-notifications-check.md`) belgelendiği üzere:

- `meta/kap.lastSyncStatus` = `"failed"`
- Hata: `Invalid character in header content ["Authorization"]`
- `kap_disclosures` koleksiyonu boş veya hiç oluşturulmamış

Bu nedenle Flutter uygulaması her zaman GitHub JSON fallback'ine düşüyor ve yukarıda açıklanan dedup hatasıyla karşılaşıyor.

---

## Kök Neden Özeti

| # | Sorun | Konum |
|---|-------|--------|
| 1 | GitHub JSON'daki tüm kayıtların `url` alanı aynı (`getmidas.com/kap-haberleri/`) | Harici veri kaynağı |
| 2 | `_buildDeduplicationKey()` URL'i birincil anahtar yapıyor; aynı URL → 150 kayıt siliniyor | `lib/services/kap_news_service.dart` |
| 3 | GitHub JSON'da `disclosureIndex`/`id` alanı yok | Harici veri kaynağı |
| 4 | Firestore sync çalışmadığı için birincil kaynak boş, GitHub fallback aktif | `functions/index.js` (KAP_TOKEN sorunu) |

---

## Önerilen Düzeltmeler (Öncelik Sırasıyla)

### 1. [Kritik] `_buildDeduplicationKey()` içinde URL adımını kaldır veya koşullandır

`lib/services/kap_news_service.dart` → `_buildDeduplicationKey()`:

```dart
// SORUNLU MEVCUT KOD:
if (item.url.isNotEmpty) {
  return 'URL:${item.url}';
}

// ÖNERİLEN DÜZELTME:
// URL'i yalnızca bireysel bildirime işaret ettiğinde (kap.org.tr/tr/Bildirim/ID) anahtar yap.
// Toplu liste URL'lerini (getmidas.com/kap-haberleri/ gibi) anahtar olarak kullanma.
if (item.url.isNotEmpty && !item.url.contains('/kap-haberleri') && 
    (item.url.contains('/Bildirim/') || item.url.contains('?id='))) {
  return 'URL:${item.url}';
}
```

Alternatif daha sağlam yaklaşım: URL'i dedup anahtarından tamamen çıkar, yalnızca `disclosureIndex` ve `source|title|type` kombinasyonunu kullan.

### 2. [Yüksek] Fallback Dedup Key'ini Daha İyi Oluştur

`disclosureIndex` yoksa ve URL elendiyse, adım 3'teki `source|normalizedTitle|type` anahtarı zaten çalışır durumdadır (commit `d1bd92e`'nin amacı buydu). URL adımı kaldırılınca bu fallback devreye girecek ve 151 kayıt doğru şekilde ayrıştırılacak.

### 3. [Yüksek] GitHub JSON'a `disclosureIndex` / `id` Alanı Ekle

GitHub repo `Alikose010/teknik-bakis-kap`'ta `data/kap_news.json` dosyasını üreten scriptte her kayda benzersiz bir ID eklenmelidir. `rawDate` alanı zaten var — bu değerden ya da `source+time` kombinasyonundan deterministik bir ID türetilebilir.

### 4. [Orta] Firestore Sync'i Onar (KAP_TOKEN)

Firebase Console → Secret Manager → `KAP_TOKEN` değerini güncelle. Token `\n`, `\r` veya `Bearer ` prefix'i içermemeli. Cloud Function `kapGet()` düzgün çalışmaya başlarsa `kap_disclosures` dolacak ve URL sorunu olan GitHub fallback'i hiç devreye girmeyecek.

---

## Doğrulama Simülasyonu

```
GitHub JSON: 151 kayıt
  ↓ KapNewsItem oluştur
  ↓ dedupe() çağır
    - item[0]: disclosureIndex=null → url='https://www.getmidas.com/kap-haberleri/'
               key = 'URL:https://www.getmidas.com/kap-haberleri/'
               seenKeys.add → true → unique'e eklendi (unique.length=1)
    - item[1]: key = 'URL:https://www.getmidas.com/kap-haberleri/'
               seenKeys.add → false → ATILDI
    - item[2..150]: aynı → hepsi ATILDI
  ↓
Sonuç: 1 kayıt → _kapNews.length = 1
UI: "Son 1 bildirimi gösteriliyor (72 saat)"
```

---

*Rapor: read-only inceleme. Hiçbir kod değiştirilmedi.*  
*İncelenen dosyalar: `lib/services/kap_news_service.dart`, `lib/services/kap_disclosure_service.dart`, `lib/screens/news_screen.dart`, `lib/models/kap_news_item.dart`, `functions/index.js`, `data/kap_news.json` (GitHub uzak kaynak)*  
*İlgili commit'ler: `d1bd92e`, `edc1227`, `17dec4d`*
