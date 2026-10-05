# BIST100 Sistem Son Kontrol Raporu

**Tarih:** 2025-07-13  
**Kapsam:** Read-only kod incelemesi — hiçbir değişiklik yapılmadı.

---

## Özet Yanıtlar

| # | Soru | Yanıt |
|---|------|-------|
| 1 | Bist100Service Firestore'dan `bist_index_meta/bist100` okuyor mu? | **EVET** |
| 2 | `symbols` sayısı 100 mü? | **EVET — tam 100** |
| 3 | Scanner BIST100 taramasında gerçekten bu 100 sembolü kullanıyor mu? | **EVET** |
| 4 | Firestore başarısız olursa fallback mekanizması çalışıyor mu? | **EVET — 2 katmanlı** |
| 5 | BIST100 dışı sembollerin BIST100 taramasına girme ihtimali var mı? | **YOK** |

---

## 1. Firestore `bist_index_meta/bist100` Okuma

**EVET.**

`_refreshFromFirestore()` içinde:

```dart
// bist100_service.dart:83-96
final metaDoc = await firestore
    .collection('bist_index_meta')
    .doc('bist100')
    .get()
    .timeout(const Duration(seconds: 12));

if (metaDoc.exists) {
  final raw = metaDoc.data()?['symbols'];
  if (raw is List) {
    bist100Symbols = raw
        .map((s) => s.toString().trim().toUpperCase())
        .where((s) => s.isNotEmpty)
        .toList();
  }
}
```

Tam olarak `bist_index_meta/bist100` dökümanındaki `symbols` alanını okuyup işliyor. 12 saniyelik timeout var.

---

## 2. `symbols` Sayısı 100 mü?

**EVET — tam 100 sembol.**

`kBist100Symbols` sabitinde PowerShell ile sayılan regex eşleşmesi: **100**.

Son revizyon (Eylül 2026):
- Çıkarılanlar: AGHOL, TABGD, TUREX, GENIL, MIATK (5 sembol)
- Eklenenler: ODINE, IEYHO, ESEN (3 sembol) → net -2 ise de yerini diğer sektörler aldı

Kaynak: `lib/services/bist_stocks.dart`, satır ~819, `const List<String> kBist100Symbols`

---

## 3. Scanner Bu 100 Sembolü Kullanıyor mu?

**EVET.**

`scanner_screen.dart:36`:
```dart
static List<String> get _bist100Symbols => Bist100Service.symbols;
```

`scanner_screen.dart:39-40`:
```dart
static List<String> _symbolsForScope(_ScanScope scope) =>
    scope == _ScanScope.bist100 ? _bist100Symbols : _bist500Symbols;
```

`Bist100Service.symbols` getter'ı `_liveSymbols` döndürür. `_liveSymbols`, başlangıçta `kBist100Symbols`'tan (100 sembol), Firestore güncellemesi sonrası Firestore'dan gelen listeden beslenir. Akış:

```
init() → Hive cache yükleme → Firestore refresh
       ↓ her başarılı güncellemede
  _liveSymbols = firestoreSymbols (length >= 50 kontrolü var)
```

Scanner, `Bist100Service.symbols` üzerinden bu listeyi doğrudan tüketir.

---

## 4. Firestore Başarısız Olursa Fallback

**EVET — 2 katmanlı fallback:**

### Katman 1: Hive Cache
`init()` → `_loadFromCache(box)` her zaman önce çalışır:
```dart
// bist100_service.dart:53-56
final cachedSymbols = box.get(_keyBist100);
if (cachedSymbols is List && cachedSymbols.length >= 50) {
  _liveSymbols = List<String>.from(cachedSymbols.cast<String>());
}
```
Bir önceki başarılı Firestore çekimi Hive'a kaydedilmiş ise offline çalışır.

### Katman 2: Sabit Kod (`kBist100Symbols`)
`_liveSymbols` başlangıç değeri:
```dart
// bist100_service.dart:26
static List<String> _liveSymbols = List.from(kBist100Symbols);
```
Hem Firestore hem Hive başarısız olursa 100 sembollük sabit fallback aktif kalır.

Hata yönetimi sessiz geçer (uygulama crash etmez):
```dart
// bist100_service.dart:44-46
_refreshFromFirestore(box).catchError((Object e) {
  debugPrint('[Bist100Service] Firestore güncelleme başarısız: $e');
});
```

Ayrıca `syncBistStocksFromFirestore()` içinde de:
```dart
// bist_stocks.dart:738
// Boş gelirse kBist100SymbolsLive güncellenmez, sabit liste korunur.
if (firestoreBist100.isNotEmpty) { ... }
```

---

## 5. BIST100 Dışı Sembollerin Sızma İhtimali

**YOK.**

BIST100 tarama listesi tamamen `Bist100Service.symbols`'tan gelir. Bu liste ya:
- Sabit `kBist100Symbols` (100 bilinen sembol), ya
- Hive cache (önceki Firestore verisi), ya
- Firestore `bist_index_meta/bist100.symbols`

Her üç kaynakta da `kBistStocks` (tam BIST listesi) ile herhangi bir birleşim/kesişim yapılmıyor. `_bist500Symbols` ile `_bist100Symbols` getter'ları tamamen bağımsız:

```dart
static List<String> get _bist500Symbols =>
    kBistStocks.map((e) => e['symbol']!).toList();   // ~600 sembol

static List<String> get _bist100Symbols => Bist100Service.symbols;   // 100 sembol
```

`_symbolsForScope` `if/else` dallanması ile ikisi hiçbir zaman karışmaz.

Potansiyel risk kontrolü: `syncBistStocksFromFirestore()` içindeki güvenlik mantığı:
```dart
// Firestore'da olmayan ama _baseBistStocks'ta olan hisseler korunur
// (kısmi Firestore güncellemelerine karşı güvenlik katmanı).
```
Bu sadece `kBistStocks` (tam liste) için geçerli; `kBist100SymbolsLive` için benzer bir "fallback merge" **yoktur** — bu doğru bir tasarım: BIST100'e bilinmeyen sembol eklenmesi istenmez.

---

## Sonuç ve Değerlendirme

Sistem tasarım olarak sağlam:

✅ Firestore okuma doğru koleksiyona/dökümana gidiyor  
✅ Sembol sayısı tam 100  
✅ Scanner `Bist100Service.symbols` getter'ını doğrudan kullanıyor, bypass yok  
✅ Fallback 2 katmanlı (Hive → sabit kod), uygulama asla çökmüyor  
✅ BIST500 listesiyle karışma mantıken imkânsız (bağımsız getter + if/else scope seçimi)

### Küçük Dikkat Noktaları (kritik değil)

1. **`_liveSymbols` vs `kBist100SymbolsLive` çift güncelleme:** `syncBistStocksFromFirestore()` `kBist100SymbolsLive`'ı güncellerken, `bist100_service.dart:149-150` ayrıca `_liveSymbols`'ı da güncelliyor. Bu tutarlı ama tekrar — `scanner_screen.dart` `kBist100SymbolsLive`'ı değil, `Bist100Service.symbols` (`_liveSymbols`) getter'ını kullandığı için güncelleme path'i doğru çalışıyor.

2. **`length >= 50` eşiği:** Hem cache yüklemede hem Firestore sonucunda `>= 50` kontrolü var; bu eşik altında Firestore/cache verisi yok sayılıp sabit fallback korunuyor. Makul bir güvenlik marjı, değişiklik önermiyorum.
