# BIST100 Kullanım Analizi — Teknik Bakış Projesi

## Özet

Proje, BIST100 verilerini üç katmanlı bir mimariyle yönetiyor: sabit kodlanmış fallback (`kBist100Symbols`), Firestore kaynaklı dinamik liste (`Bist100Service._liveSymbols`), ve paralel güncellenen bir global değişken (`kBist100SymbolsLive`). Scanner ekranı BIST100 taramasında `Bist100Service.symbols` getter'ını kullanıyor — bu getter Firestore'dan güncelleniyor. Ancak iki kritik sorun var: (1) `kBist100SymbolsLive` global değişkeni hiçbir ekran tarafından tüketilmiyor (ölü kod), (2) Scanner'ın BIST500 listesi (`_bist500Symbols`) `static final` olarak uygulama açılışında donuyor — Firestore güncellemesi kBistStocks'u değiştirse bile tarama eski listeyi kullanır.

---

## Soru 1 — `Bist100Service` Nerede Tanımlanıyor ve Kullanılıyor?

### Tanım
- `lib/services/bist100_service.dart` — Sınıf tanımı, tüm statik metotlar ve `_liveSymbols` state'i burada.

### Kullanım noktaları

| Dosya | Satır | Açıklama |
|---|---|---|
| `lib/main.dart` | 35 | `Bist100Service.init()` — uygulama açılışında await edilmeden çağrılır |
| `lib/screens/scanner_screen.dart` | 36 | `static List<String> get _bist100Symbols => Bist100Service.symbols;` — BIST100 tarama listesi buradan gelir |
| `lib/services/bist100_service.dart` | 26 | `static List<String> _liveSymbols = List.from(kBist100Symbols)` — başlangıç değeri sabit listeden |

### Import noktaları

| Dosya | Satır |
|---|---|
| `lib/main.dart` | 20 — `import 'services/bist100_service.dart'` |
| `lib/screens/scanner_screen.dart` | 6 — `import '../services/bist100_service.dart'` |

---

## Soru 2 — Scanner BIST100 Listesini Nereden Alıyor?

### Cevap: Firestore'dan alıyor — ama dolaylı, ve uygulama açılışının hızına bağlı bir race condition var.

Akış şu şekilde çalışır:

```
main.dart:35  → Bist100Service.init()  (await etmiyor!)
                    └─ Hive cache yükle → _liveSymbols güncelle
                    └─ Firestore'dan async çek → _liveSymbols güncelle

scanner_screen.dart:36 → _bist100Symbols getter → Bist100Service.symbols
                              └─ _liveSymbols döndürür
```

#### Öncelik sırası (bist100_service.dart yorum satırı, satır 8-13)
1. Firestore `bist_index_meta/bist100` dokümanı (`symbols` alanı)
2. Hive cache (son başarılı Firestore verisi)
3. `kBist100Symbols` sabit kodu (nihai fallback — `bist_stocks.dart:819`)

#### Kritik davranış
- `Bist100Service.init()` `await` edilmeden çağrıldığı için (`main.dart:35`), uygulama açılırken hemen Scanner'a gidilirse `Bist100Service.symbols` henüz `kBist100Symbols` sabit listesini döndürüyor olabilir.
- `_bist100Symbols` getter olduğu için (`static List<String> get`), her taramada taze değeri okur. Firestore init tamamlandıktan sonra açılan taramalar güncel listeyi kullanır.
- Hive cache varsa, Firestore bitmeden önce bile cache'den güncel liste yüklenir (`bist100_service.dart:46-56`).

---

## Soru 3 — `kBist100Symbols` ve Diğer Hardcoded Listeler

### `kBist100Symbols` sabiti
- **Tanım:** `lib/services/bist_stocks.dart:819` — 100 sembol, Eylül 2026 revizyonu
- **Kullanım 1:** `lib/services/bist100_service.dart:26` — `_liveSymbols`'ın başlangıç değeri olarak kopyalanır
- **Kullanım 2:** `lib/services/bist_stocks.dart:872` — `kBist100SymbolsLive` global değişkeninin başlangıç değeri
- Doğrudan ekran kodu tarafından **tüketilmiyor** — yalnızca fallback olarak kullanılıyor

### `kBist100SymbolsLive` global değişkeni
- **Tanım:** `lib/services/bist_stocks.dart:872`
- **Güncelleme:** `syncBistStocksFromFirestore()` (bist_stocks.dart:780) içinde Firestore verisi >= 50 sembol gelirse güncellenir
- **Kullanım:** **HİÇBİR EKRAN TARAFINDAN OKUNMUYOR.** `kBist100SymbolsLive`'ı değer olarak okuyan tek yer tanımının kendisi ve `syncBistStocksFromFirestore`'daki atama. Scanner `Bist100Service.symbols` kullanıyor, `kBist100SymbolsLive`'ı değil. Bu ölü koddur.

### `_baseBistStocks` hardcoded tam liste
- **Tanım:** `lib/services/bist_stocks.dart:7` — ~610+ hisse, BIST500+ kapsamı
- **Kullanım:** `kBistStocks` global değişkeninin başlangıç değeri; Firestore güncellemesinde fallback olarak da korunur (`bist_stocks.dart:757-768`)

### `kBistStocks` global değişkeni
- **Tanım:** `lib/services/bist_stocks.dart:729` — başlangıçta `_baseBistStocks`'tan, Firestore'dan güncellenir
- **Kullanım noktaları (hisse arama/listeleme):**
  - `lib/screens/home_screen.dart:76, 381, 391, 394, 546, 570, 573, 576`
  - `lib/screens/scanner_screen.dart:34` — `static final _bist500Symbols` (**kritik bug — aşağıya bak**)
  - `lib/screens/analiz_screen.dart:111, 116, 119, 2542, 2545, 2550, 2553`
  - `lib/screens/portfolio_screen.dart:818, 822, 823`
  - `lib/screens/watchlist_screen.dart:914, 923, 926`
  - `lib/screens/analiz_screenyedekk.dart:109, 114, 117, 2310, 2313, 2318, 2321`
  - `lib/screens/notifications_screen.dart:30`
  - `lib/services/stock_service.dart:304, 369`
  - `lib/services/kap_news_service.dart:203`
  - `lib/kap_ai/kap_ai_service.dart:116`

---

## Soru 4 — BIST100 Dışı Hisselerin Taranmasına Yol Açabilecek Yerler

### 🔴 BUG 1 — `_bist500Symbols` `static final` olarak donuyor (scanner_screen.dart:33-35)

```dart
// scanner_screen.dart satır 33-35
static final List<String> _bist500Symbols =
    kBistStocks.map((e) => e['symbol']!).toList();
```

`static final` Dart'ta sınıf ilk yüklendiğinde **bir kere** değerlendirilir. Bu, `_ScannerScreenState` sınıfı ilk kez oluşturulduğu anda `kBistStocks`'un o anki değerini kopyalar. Eğer `Bist100Service.init()` henüz Firestore'dan veri çekmemişse, tarama `_baseBistStocks`'taki eski hardcoded listeyi kullanır ve Firestore güncellemesi bu listeye **yansımaz**.

Karşılaştırın: BIST100 için getter kullanılıyor (`static List<String> get _bist100Symbols => Bist100Service.symbols`) — her çağrıda taze değer okunur. BIST500 için final kullanılıyor — değer donuk kalır.

### 🟡 SORUN 2 — `Bist100Service.init()` `await` edilmiyor (main.dart:35)

```dart
// main.dart satır 35
Bist100Service.init(); // arka planda başlat, await etme
```

Kasıtlı tasarım (yorum satırında belirtilmiş) ama şu anlama geliyor: Hive cache yoksa ve kullanıcı hemen Scanner'a girip BIST100 taraması başlatırsa, `kBist100Symbols` sabitindeki ~100 hisselik listeyle tarama yapılır. Bu kabul edilebilir bir fallback, ama son BIST100 listesini yansıtmayabilir.

### 🟡 SORUN 3 — `kBist100SymbolsLive` güncelleniyor ama okunmuyor (bist_stocks.dart:872)

`syncBistStocksFromFirestore()` hem `kBistStocks`'u hem `kBist100SymbolsLive`'ı güncelliyor. Ancak hiçbir kod `kBist100SymbolsLive`'ı okumuyor. Scanner `Bist100Service.symbols` kullanıyor. Bu ikili güncelleme gereksiz karmaşıklık yaratıyor ve senkronizasyon hatalarına zemin hazırlıyor (iki ayrı runtime BIST100 listesi birbirinden kopuk davranabilir).

### 🟢 İYİ TASARLANMIŞ — Firestore filtresi

`bist100_service.dart:109-115`: Firestore'daki `bist_stocks` collection'ı `where('active', isNotEqualTo: false)` filtresiyle çekiliyor. Bu, `active: false` işaretli (BİST'ten çıkarılmış) hisselerin listeye girmesini engeller.

### 🟢 İYİ TASARLANMIŞ — Minimum sembol sayısı kontrolü

`bist100_service.dart:149-150` ve `bist_stocks.dart:780`: Firestore'dan gelen BIST100 listesi yalnızca >= 50 sembol içeriyorsa kabul ediliyor. Bu, bozuk/eksik Firestore verisiyle tüm listenin silinmesini önler.

---

## Sonuç ve Öneriler

### Öneriler (öncelik sırasıyla)

1. **`_bist500Symbols`'ı `static final`'den getter'a çevir** (`scanner_screen.dart:33-35`)
   ```dart
   // ŞU AN (bug):
   static final List<String> _bist500Symbols =
       kBistStocks.map((e) => e['symbol']!).toList();

   // OLMASI GEREKEN:
   static List<String> get _bist500Symbols =>
       kBistStocks.map((e) => e['symbol']!).toList();
   ```
   Bu tek satır değişikliği, Firestore güncellemesinin BIST500 taramasına yansımasını sağlar.

2. **`kBist100SymbolsLive`'ı kaldır veya Scanner'a bağla** (`bist_stocks.dart:872`)
   Ya global değişkeni tamamen sil (Scanner zaten `Bist100Service.symbols` kullanıyor), ya da `Bist100Service._liveSymbols`'ı kaldırıp `kBist100SymbolsLive`'a yönlendir. İkisi ayrı ayrı güncellenmesi gereksiz karmaşıklık.

3. **`Bist100Service.init()` tamamlanana kadar Scanner'ı beklettirmeyi değerlendir**
   Şu anki tasarım kasıtlı (UX açısından makul — açılış hızı kritik), ama Scanner açılışında "BIST100 listesi güncelleniyor..." gibi bir gösterge eklenebilir.

### Risk Özeti

| Risk | Dosya | Satır | Şiddet |
|---|---|---|---|
| BIST500 tarama listesi Firestore güncellemesine kapalı | scanner_screen.dart | 33-34 | 🔴 Orta |
| `kBist100SymbolsLive` ölü kod — karmaşıklık riski | bist_stocks.dart | 872 | 🟡 Düşük |
| BIST100 taraması uygulama açılış hızına bağlı race condition | main.dart + bist100_service.dart | 35 / init | 🟡 Düşük |
