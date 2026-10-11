# Hisse Listesi Güncelleme Soruları — Araştırma Raporu

**Tarih:** 2026-10-11  
**Kapsam:** Read-only kod analizi  
**Kaynak dosyalar:** `lib/services/bist_stocks.dart`, `lib/services/bist100_service.dart`, `lib/services/ipo_service.dart`, `lib/models/ipo_item.dart`, `lib/main.dart`

---

## Özet Cevap (TL;DR)

### Soru 1 — Halka arz (IPO) hisseleri genel listeye otomatik ekleniyor mu?

**EVET — kısmen otomatik.** Borsada işlem görmeye başlayan (status: `trading`) halka arz hisseleri, uygulama her açıldığında veya her 45 dakikada bir Firestore/GitHub'dan veri çekildiğinde `kBistStocks` genel listesine otomatik olarak eklenir. Ancak bu listeye eklenmesi için hissenin IPO Feed'de (`ipo_items` Firestore collection veya GitHub JSON) kayıtlı ve durumunun `trading` olması gerekir. Hisseyi bu feed'e ekleyen backend (`syncIpoFeed` Cloud Function veya admin HTTP endpoint); hisse listesini `bist_stocks` Firestore collection'ına ekleyen bir sistem **ŞU AN ÇALIŞMIYOR** (bkz. Soru 2).

**Kapanan şirketler / isim değişikliği:** Otomatik silme/güncelleme mekanizması yoktur. `bist_stocks` Firestore collection'ında bir şirketin `active: false` yapılması gerekir; bu işlem manueldir.

### Soru 2 — BIST100 listesi otomatik güncelleniyor mu?

**HAYIR — otomatik güncelleme yoktur.** BIST100 listesini (`kBist100Symbols` / `bist_index_meta/bist100`) otomatik güncelleyen bir Cloud Function mevcut **değildir**. Flutter uygulaması Firestore'dan okuma altyapısı tamamen hazır olmakla birlikte, o Firestore dokümanını güncel tutan arka plan servisi henüz yazılmamıştır. Değişiklikler şu an manüel olarak yapılmaktadır.

---

## Detaylı Bulgular

### 1. Genel Hisse Listesi (`kBistStocks`) — Nasıl Çalışır?

**Dosya:** `lib/services/bist_stocks.dart`

#### 1a. Temel (Statik) Liste

`_baseBistStocks` adında yaklaşık 610 girişten oluşan sabit bir `const List` dart dosyasının içinde hard-coded tanımlıdır. Bu listeye yeni bir hisse eklemek için `bist_stocks.dart` dosyasını elle düzenleyip yeni bir uygulama sürümü release etmek gerekir.

```dart
// bist_stocks.dart
const List<Map<String, String>> _baseBistStocks = [
  {'symbol': 'A1CAP', 'name': 'A1 Capital'},
  {'symbol': 'A1YEN', 'name': 'A1 Yenilenebilir Enerji'},
  // ...~610 hisse
];

List<Map<String, String>> kBistStocks = List<Map<String, String>>.from(_baseBistStocks);
```

#### 1b. Firestore'dan Dinamik Güncelleme

`Bist100Service.init()` fonksiyonu uygulama açılışında (`main.dart`, satır 39) çağrılır ve arka planda Firestore `bist_stocks` collection'ını çeker:

```dart
// bist100_service.dart
final snapshot = await firestore
    .collection('bist_stocks')
    .where('active', isNotEqualTo: false)  // active:false olanlar dışlanır
    .get()
    .timeout(const Duration(seconds: 20));
```

Eğer `bist_stocks` Firestore collection'ı doluysa uygulamanın genel listesi (`kBistStocks`) bu verilerle güncellenir. Ancak `bist_stocks` collection'ını otomatik olarak dolduran bir servis henüz yazılmamıştır.

#### 1c. IPO Hisselerinin Otomatik Eklenmesi

`IpoService.loadCachedOrSeed()` ve `IpoService.refresh()` çağrıldığında, içlerinde `syncBistStocksWithIpoItems(items)` çağrısı yapılır:

```dart
// bist_stocks.dart — syncBistStocksWithIpoItems()
for (final item in ipoItems.where((item) =>
    item.status == IpoStatus.trading && item.symbol.isNotEmpty)) {
  // Sadece IpoStatus.trading olan hisseler eklenir
  final symbol = item.symbol.toUpperCase();
  if (seenSymbols.contains(symbol)) continue;  // çakışma önleme
  seenSymbols.add(symbol);
  merged.add({'symbol': symbol, 'name': item.companyName});
}
```

Bu mekanizma sayesinde IPO feed'inde `trading` statüsündeki bir hisse, `_baseBistStocks` veya Firestore `bist_stocks` collection'ına eklenmese bile `kBistStocks` listesine geçici olarak dahil olur.

**Bu otomatik çalışır mı?** Evet — ama belirli koşullara bağlıdır:
- IPO Feed'in Firestore `ipo_items` collection'ında veya GitHub JSON dosyasında o hisse kaydının olması gerekir.
- Hissenin `listingDate` (halka arz tarihi) geçmiş olmalıdır; bu tarih geçince durum otomatik olarak `trading`'e döner (`_deriveStatus()` metodu).
- Uygulama açık olmalı veya 45 dakikalık yenileme tetiklenmiş olmalıdır.

#### 1d. Kapanan Şirket / İsim Değişikliği

**Otomatik mekanizma yoktur.** Mevcut sistemde bir şirket BİST'ten çıkarsa:

1. `bist_stocks` Firestore collection'ında o hissenin `active: false` yapılması gerekir.
2. Bu işlem manuelde yapılmak zorundadır (admin HTTP endpoint veya Firebase Console).
3. `_baseBistStocks` sabit listesinden silinmesi için yeni bir uygulama sürümü gerekir.

İsim değişikliği için de aynı manual süreç geçerlidir: `bist_stocks/{symbol}.name` alanının Firestore'dan güncellenmesi gerekmektedir.

**Güvenlik katmanı:** `syncBistStocksFromFirestore()` fonksiyonu, Firestore'da bulunmayan ama `_baseBistStocks`'ta olan hisseleri **her zaman korur**:

```dart
// Firestore'da olmayan ama _baseBistStocks'ta olan hisseler korunur
for (final entry in _baseBistStocks) {
  final symbol = ...
  if (symbol.isEmpty || seenSymbols.contains(symbol)) continue;
  merged.add(Map<String, String>.from(entry));  // _baseBistStocks korunur
}
```

Bu bir güvenlik katmanıdır: Firestore kısmen güncellense bile liste bozulmaz. Ancak bu aynı zamanda şunu da anlatır: Bir hisseyi gerçekten kaldırmak için hem Firestore'da `active: false` yapılmalı **hem de** `_baseBistStocks` sabit listesinden çıkarılmalı ya da `_baseBistStocks`'taki varlığının da Firestore'dan filtrelenmesi için ek mantık eklenmeli.

---

### 2. BIST100 Listesi — Nasıl Çalışır?

**Dosya:** `lib/services/bist100_service.dart`, `lib/services/bist_stocks.dart`

#### 2a. Sabit Liste (Fallback)

`bist_stocks.dart` içinde `kBist100Symbols` adında 100 sembolden oluşan sabit bir `const List<String>` mevcuttur. Bu liste Eylül 2026 revizyonuyla güncellenmiştir (AGHOL, TABGD, TUREX, GENIL, MIATK çıkarıldı; ODINE, IEYHO, ESEN eklendi).

#### 2b. Firestore'dan Dinamik Güncelleme

`Bist100Service.init()` fonksiyonu şu Firestore dokümanını çeker:

```
Firestore: bist_index_meta/bist100
{
  symbols: ['AKBNK', 'GARAN', ...],  // ~100 eleman
  updatedAt: Timestamp,
  revision: "Eylül 2026",
  added: ['ODINE', 'IEYHO', 'ESEN'],
  removed: ['AGHOL', 'TABGD']
}
```

Eğer Firestore'daki liste en az 50 sembol içeriyorsa `kBist100SymbolsLive` değişkeni güncellenir.

#### 2c. Caching (Hive)

Her başarılı Firestore güncellemesi Hive'a kaydedilir. Sonraki uygulama açılışlarında önce Hive cache'den yüklenir, arka planda Firestore yenilemesi yapılır.

Güncelleme öncelik sırası:
1. Firestore `bist_index_meta/bist100` → en taze veri
2. Hive cache → offline erişim
3. `kBist100Symbols` const listesi → nihai fallback

#### 2d. BIST100 Güncellemesini Kim Yapıyor?

**Otomatik sistem yok.** `bist_index_meta/bist100` Firestore dokümanını güncelleyen bir Cloud Function **bulunmuyor**. `functions/index.js` dosyasında sekiz zamanlanmış fonksiyon vardır (KAP, Fundamentals, IPO için) ama BIST100 için hiçbiri yoktur.

Mevcut Cloud Function'lar:

| Fonksiyon | Tür | Kaynak |
|---|---|---|
| `syncKapOpeningPre` | Scheduled (09:55 TR) | MKK VYK API |
| `syncKapOpeningWindow` | Scheduled (10:00–10:30) | MKK VYK API |
| `syncKapDisclosures` | Scheduled (her 15 dk) | MKK VYK API |
| `syncKapManual` | HTTP | MKK VYK API |
| `updateFundamentals` | Scheduled (günde 3x) | bilancoveri.com |
| `updateFundamentalsManual` | HTTP | Manuel |
| `syncIpoFeed` | Scheduled (her 6 saat) | halkarz.com |
| `syncIpoManual` | HTTP | Manuel |
| **`syncBist100Index`** | **YOK** | — |

---

## Özet Tablo

| Soru | Cevap | Mekanizma |
|------|-------|-----------|
| Yeni halka arz BIST'e listelenince genel listeye otomatik ekleniyor mu? | ✅ Evet (koşullu) | IPO feed'de `trading` statüsüne geçince `syncBistStocksWithIpoItems()` tetiklenir |
| IPO feed'i otomatik güncelleniyor mu? | ✅ Evet | `syncIpoFeed` Cloud Function her 6 saatte bir `halkarz.com`'dan scraping yapar |
| Kapanan şirket listeden otomatik siliniyor mu? | ❌ Hayır | Manuel: Firestore'da `active: false` + yeni uygulama sürümü |
| İsim değişikliği otomatik yansıyor mu? | ❌ Hayır | Manuel: Firestore'da `name` alanı güncellenmeli |
| BIST100 listesi otomatik güncelleniyor mu? | ❌ Hayır | Manuel: Firestore'da `bist_index_meta/bist100.symbols` güncellenmeli |
| BIST100 için Cloud Function var mı? | ❌ Yok | Hiçbir scheduled veya HTTP fonksiyonu yok |
| Flutter tarafı Firestore'dan okumaya hazır mı? | ✅ Evet | `Bist100Service.init()` altyapısı tamamen hazır |

---

## Sonuçlar

### Halka Arz (IPO) Mekanizması — Çalışan Kısım

IPO hisseleri için sistem **yarı otomatik** çalışıyor:
- **Backend:** `syncIpoFeed` Cloud Function her 6 saatte bir `halkarz.com`'dan veri çekerek Firestore `ipo_items` collection'ını güncelliyor.
- **App:** Uygulama açılışında ve her 45 dakikada bir `IpoService.refresh()` Firestore'dan IPO verilerini çekiyor.
- **Geçiş:** `listingDate` geçince durum otomatik olarak `trading`'e döner; bu hisse `kBistStocks` listesine eklenir.

Yani teorik olarak `halkarz.com`'da kayıtlı ve `listingDate`'i doğru girilmiş bir IPO, kullanıcının herhangi bir şey yapmasına gerek kalmadan uygulamanın genel listesine eklenebilir.

### Kapanan Şirket / İsim Değişikliği — Eksik

`bist_stocks` Firestore collection'ını ve `_baseBistStocks` sabit listesini otomatik güncelleyen bir sistem yoktur. Bu işlemler manüeldir.

### BIST100 — Tamamen Manuel

BIST100 bileşen listesi (`kBist100Symbols`) her 6 ayda bir değişir (Mayıs ve Kasım başı). Şu an bu değişiklik:
1. `bist_stocks.dart` dosyasındaki `kBist100Symbols` listesi elle düzenleniyor.
2. Yeni uygulama sürümü Play Store / App Store'a gönderiliyor.
3. İsteğe bağlı olarak Firestore `bist_index_meta/bist100` dokümanı da güncelleniyor (ancak bu güncelleyen otomatik bir servis yok).

---

## Öneriler

### Kısa Vadeli (Manuel Süreç Kolaylaştırma)

1. **BIST100 için admin HTTP endpoint ekle:** `functions/index.js`'e `syncBist100Manual` adında bir HTTP endpoint ekle. Admin bu endpoint'i çağırarak `bist_index_meta/bist100` dokümanını günceller. Flutter kodu zaten hazır, sadece backend yazılmalı.

2. **Kapanan/İsim değişen hisseler için:** Firebase Console üzerinden `bist_stocks/{symbol}` dokümanının `active: false` veya `name` alanı güncellenmeli. Tek seferlik değişiklikler için yeni sürüm gerekmez.

### Orta Vadeli (Yarı Otomatik)

3. **`syncBist100Index` Cloud Function:** `functions/index.js`'e ayda 1 kez çalışan bir scheduled function ekle. BIST100 değişiklikleri yılda sadece 2 kez gerçekleştiği için ayda 1 çalışma yeterli. Kaynak: `fintables.com` veya `bigpara.com` API'leri (resmi değil ama yaygın kullanımlı). Flutter kodu hiç değişmez.

4. **`bist_stocks` collection tam doldurmak:** Tüm `_baseBistStocks` listesi bir kez Firestore'a yazılırsa gelecekteki yeni hisseler uygulama sürümü çıkarmadan güncellenebilir. Bu bir defalık admin scripti ile yapılabilir.

### Mevcut Sistemin Gücü

Mevcut kod mimarisi bu geliştirmelere tamamen hazırdır. `Bist100Service.init()`, Hive cache, fallback zinciri, `active` filtresi — hepsi çalışır durumda. Eksik olan yalnızca Firestore'u güncel tutan backend taraf.

---

## Referans Dosyalar

| Dosya | İlgili Bölüm |
|---|---|
| `lib/services/bist_stocks.dart` | `_baseBistStocks` (~610 hisse), `kBist100Symbols`, `syncBistStocksFromFirestore()`, `syncBistStocksWithIpoItems()` |
| `lib/services/bist100_service.dart` | `init()`, `_refreshFromFirestore()`, Hive cache mantığı |
| `lib/services/ipo_service.dart` | `refresh()`, `_refreshFromFirestore()`, `syncBistStocksWithIpoItems()` çağrıları |
| `lib/models/ipo_item.dart` | `_deriveStatus()` — tarih bazlı durum türetme |
| `lib/main.dart` | `Bist100Service.init()` çağrısı (satır 39) |
| `.agents/tasks/bist100-auto-update-investigation.md` | Cloud Function mimari analizi |
| `.agents/tasks/halka-arz-borsa-investigation.md` | IPO statü mekanizması detayları |
