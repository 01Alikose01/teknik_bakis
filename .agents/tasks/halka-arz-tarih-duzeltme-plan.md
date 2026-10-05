# Implementation Plan: Halka Arz Tarih Düzeltme

## Analiz Bulguları

### İlgili Dosyalar

| Dosya | Rol |
|-------|-----|
| `lib/models/ipo_item.dart` | Model, `_deriveStatus`, `status` getter — sınıflandırma mantığı |
| `lib/screens/ipo_screen.dart` | UI, `_groupedItems()` — kategori filtreleme |
| `lib/services/ipo_service.dart` | Firestore/GitHub veri çekme, cache |
| `lib/screens/home_screen.dart` | `_QuickCard` widget — Expanded hatası |
| `assets/data/ipo_seed.json` | Yerel tohum veri (doğru formatta) |
| `data/ipo_feed.json` | GitHub fallback feed |
| `test/ipo_logic_test.dart` | Mevcut birim testler |

---

### Sorun 1: SOHO Yanlış Sınıflandırma — Kök Neden

#### Mevcut Kod (ipo_item.dart)

```dart
// IpoItem.status getter
IpoStatus get status {
  if (_status == IpoStatus.postponed) return IpoStatus.postponed;

  if (_hasTimelineData) {           // <-- SORUN BURASI
    return _deriveStatus(
      requestStart: requestStart,
      requestEnd: requestEnd,
      listingDate: listingDate,
      fallbackStatus: _status,
    );
  }
  return _status;                   // <-- Firestore status'unu doğrudan döndürüyor
}

bool get _hasTimelineData {
  return requestStart != null || requestEnd != null || listingDate != null;
}
```

```dart
static IpoStatus _parseStatus(String? raw, ...) {
  final value = raw?.trim().toLowerCase() ?? '';
  final explicit = _parseRawStatus(value);
  if (explicit != null) {
    return explicit;   // <-- Tarih kontrolü yapmadan erken dönüyor
  }
  // ...
}
```

```dart
static IpoStatus _deriveStatus({...}) {
  final now = _nowInTurkey();

  if (listingDate != null && !listingDate.isAfter(now)) {
    return IpoStatus.trading;
  }

  if (requestEnd != null && now.isAfter(_endOfDay(requestEnd))) {
    if (listingDate != null && !listingDate.isAfter(now)) return IpoStatus.trading;
    if (listingDate != null && listingDate.isAfter(now)) return IpoStatus.pendingListing;
    // listingDate null ve fallback upcoming → BUG: pendingListing dönmesi gerekirken
    if (fallbackStatus == IpoStatus.trading) return IpoStatus.trading;
    return IpoStatus.pendingListing;  // Bu satır çalışıyor
  }

  if (requestStart != null) {
    final start = _startOfDay(requestStart);
    return now.isBefore(start) ? IpoStatus.upcoming : IpoStatus.collecting;
  }

  if (listingDate != null) {
    return now.isBefore(_startOfDay(listingDate)) ? IpoStatus.upcoming : IpoStatus.trading;
  }

  return fallbackStatus;  // <-- Hiç tarih yoksa buraya düşüyor
}
```

#### SOHO Senaryosu — Firestore Kaydı

Firestore'daki SOHO kaydının iki olası problemi var:

**Durum A (Olası ana neden):** Firestore belgesinde `requestStart`/`requestEnd`/`listingDate` alanları **hiç yok** veya boş.  
→ `_hasTimelineData = false` → `status` getter `_status = IpoStatus.upcoming` döndürüyor  
→ SOHO "Yaklaşan"'da görünüyor.

**Durum B (Alternatif neden):** Tarih alanları var ama `listingDate` null, ve `_deriveStatus` `requestEnd`'in geçmiş olduğunu görüp `pendingListing` döndürüyor.  
→ Bu durumda SOHO "Listeleme Bekliyor"'a düşer, "Yaklaşan"'a değil.  
→ Ama kullanıcı "Yaklaşan"'da görünüyor diyor → Durum A daha olası.

**Durum C (Kenar senaryo):** `requestStart` null, `requestEnd` null, `listingDate` null, ama Firestore'da bu alanlar **string formatta** ("30.06.2026") ve `_parseFlexibleDate` başarısız oluyor.  
→ `_hasTimelineData = false` → yine Durum A ile aynı sonuç.

#### Mevcut `_deriveStatus` İkinci Sorunu

`requestEnd` geçmişte ve `listingDate` null olduğunda:
- Kod `pendingListing` döndürüyor ✓ (doğru)
- Ama `fallbackStatus == IpoStatus.upcoming` kontrolü yok — fallback'e göre karar vermiyor ✓

Bu yol zaten doğru. Gerçek sorun `_hasTimelineData = false` yolu.

---

### Sorun 2: `_QuickCard` Expanded Hatası

**Dosya:** `lib/screens/home_screen.dart`  
**Satır:** ~1502 (build metodu içi)

```dart
// _QuickCard.build() metodu — YANLIŞ
@override
Widget build(BuildContext context) {
  final isWhite = color == Colors.white;
  return Expanded(          // <-- BU EXPANDED FAZLA
    child: GestureDetector(
      // ...
    ),
  );
}
```

**Çağrı yeri (home_screen.dart ~1098-1120):**
```dart
Row(
  children: [
    Expanded(                   // <-- Dış Expanded
      child: _QuickCard(        // <-- _QuickCard kendi içinde de Expanded dönüyor
        label: 'Portföyüm',
        // ...
      ),
    ),
    const SizedBox(width: 10),
    Expanded(                   // <-- Dış Expanded
      child: _QuickCard(        // <-- _QuickCard kendi içinde de Expanded dönüyor
        label: 'Takip Listesi',
        // ...
      ),
    ),
  ],
),
```

**Hata zinciri:** `Row → Expanded → _QuickCard → Expanded → GestureDetector`  
Flutter, `Expanded`'ın doğrudan `Row`/`Column`/`Flex` altında olmasını zorunlu kılar. İç içe `Expanded` çalışmaz.

---

## Önerilen Değişiklikler

---

- [ ] 1. **`IpoItem._deriveStatus` — "hiç tarih yok" güvenlik ağı**

  `_hasTimelineData = false` olduğunda bile Firestore `status`'unu körü körüne kabul etme.  
  `requestStart`/`requestEnd`/`listingDate` tamamı null ise `upcoming` default olarak kalmaya devam edecek (tarih bilgisi yokken tahmin yapılamaz), ama Firestore `status = 'upcoming'` olup aslında geçmişte kalmış bir kayıt daha güçlü bir korumaya sahip olmalı.

  **Gerçek düzeltme:** `status` getter'ındaki `_hasTimelineData` şartını daha toleranslı hale getir:  
  Eğer `_status == IpoStatus.upcoming` ise ve herhangi bir tarih alanı mevcutsa, `_deriveStatus` çağrısı yapılmalı — mevcut kod bunu zaten yapıyor.  
  
  **Asıl sorun:** Firestore kaydında tarih alanları yok → `_hasTimelineData = false` → fallback `upcoming`. Bunu düzeltmenin iki yolu:

  **Yol 1 (Model katmanı — yeterli):** `status` getter'ına ek kural: `_status == IpoStatus.upcoming` ve `_hasTimelineData == false` ise bile, bu getter `upcoming` döndürmeden önce Firestore cache'indeki orijinal veriyi değiştiremez; ancak model olarak hiç zaman bilgisi yoksa `upcoming` kalması mantıklı. Bu yol, Firestore'da tarih bilgisi varsa doğru çalışır.

  **Yol 2 (Asıl fix — Firestore veri kaynağı):** `ipo_feed.json` ve `ipo_seed.json`'daki SOHO kaydı zaten doğru tarih alanlarına sahip. Sorun Firestore'daki ilgili belgede tarih alanlarının eksik olması. Bu model katmanından düzeltilemez.

  **→ Doğru çözüm: model katmanında hem `_status`'u hem de tarihleri birlikte değerlendiren güçlü bir kural ekle.**

  **Files:** `lib/models/ipo_item.dart`  
  **Verify:** `flutter test test/ipo_logic_test.dart` — tüm testler geçmeli

---

- [ ] 2. **`IpoItem.status` getter — `requestStart` geçmişse kesinlikle `upcoming` olmasın**

  Kullanıcının kuralı:
  > `requestStart` geçmişse kesinlikle Yaklaşan olamaz.

  Mevcut kod `_hasTimelineData = false` yolunda buna uymuyor. Ek olarak `_deriveStatus` içindeki `fallbackStatus` döndüren son satır da `requestStart` veya `requestEnd` olmaksızın `upcoming` dönebilir.

  Yeni kural, `_deriveStatus` içine eklenmeli:
  ```dart
  // Hiçbir tarih koşulu uymadıysa ve requestStart geçmişteyse,
  // kesinlikle upcoming olamaz → pendingListing döndür
  if (requestStart != null && now.isAfter(_endOfDay(requestStart))) {
    return IpoStatus.pendingListing;
  }
  return fallbackStatus;
  ```

  Ve `status` getter'ına güvenlik ağı:
  ```dart
  IpoStatus get status {
    if (_status == IpoStatus.postponed) return IpoStatus.postponed;
    
    // _hasTimelineData yoksa bile: requestStart'ı parse edemedik ama
    // Firestore'daki tarih verilerini kontrol etmek mümkün değil.
    // _hasTimelineData true ise kesin tarih bazlı türet.
    if (_hasTimelineData) {
      return _deriveStatus(
        requestStart: requestStart,
        requestEnd: requestEnd,
        listingDate: listingDate,
        fallbackStatus: _status,
      );
    }
    return _status;
  }
  ```

  Bu durumda Firestore'da tarih alanları eksikse model düzeltemez; o yüzden veri katmanında da düzeltme gerekiyor (Madde 3).

  **Files:** `lib/models/ipo_item.dart`  
  **Verify:** `flutter test test/ipo_logic_test.dart`

---

- [ ] 3. **`IpoService` — Firestore'dan çekilen belgelerde eksik tarih alanları için güvenli türetme**

  `_refreshFromFirestore()` içinde, Firestore belgesi `requestStart`/`requestEnd`/`listingDate` alanlarından hiçbirini içermiyorsa ve `requestDates` alanı text halinde varsa, şu an bu bilgi kullanılmıyor.

  **Yapılacak:** `_convertFirestoreDoc` çağrısından sonra, `_mapItems` öncesinde, her belgeyi incele:
  - `requestStart`, `requestEnd`, `listingDate` üçü de boş/null ise VE `status` alanı mevcut ise, bu kayıt için `_deriveStatus` yerine `_parseStatus` + `fallback` mantığı devreye giriyor — bu kabul edilebilir sadece tarih yoksa.
  - Firestore'da `requestDates` text alanı var ama structured date fields yok ise, structured fields populate edilemez (text parse zor/güvenilmez).
  - **Bu durumda çözüm: Firestore'daki SOHO ve benzeri kayıtlar için `status` değeri güncellenmeli.** Ama bu uygulama kodundan yapılamaz — backend/feed güncellemesi gerekir.

  **ANCAK:** Model düzeyinde şu kural eklenebilir: Eğer `_hasTimelineData == false` ve `_status == IpoStatus.upcoming` ise, bunu Firestore `requestDates` text alanından tarih çıkarmayı dene ve çıkaramazsan `upcoming` döndür.

  Daha pratik ve güvenilir çözüm: **`_IpoService._mapItems` içinde, tarih fields boş ama `requestDates` text dolu olan kayıtlar için, text'i parse ederek `requestStart`/`requestEnd` doldur.**

  `requestDates` formatları (seed'den görülen):
  - `"30 Haziran, 1 Temmuz 2026"` → requestStart = 30 Haziran, requestEnd = 1 Temmuz
  - `"29 Haziran - 1 Temmuz 2026"` → requestStart = 29 Haziran, requestEnd = 1 Temmuz
  - `"9-10-11 Eylül 2026"` → requestStart = 9 Eylül, requestEnd = 11 Eylül

  Bu opsiyonel / karmaşık. Daha güvenilir çözüm aşağıdaki Madde 4.

  **Files:** `lib/services/ipo_service.dart`  
  **Verify:** `flutter test test/ipo_logic_test.dart`

---

- [ ] 4. **`IpoItem.fromJson` — `requestStart` geçmiş + `listingDate` null = kesinlikle `upcoming` değil**

  `_parseStatus` erken dönen `explicit` path'ini değiştir: eğer explicit status `upcoming` ise ve date fields mevcut ise, explicit'i görmezden gelip `_deriveStatus` çağır.

  **Mevcut kod:**
  ```dart
  static IpoStatus _parseStatus(String? raw, {
    required DateTime? requestStart,
    required DateTime? requestEnd,
    required DateTime? listingDate,
  }) {
    final value = raw?.trim().toLowerCase() ?? '';
    final explicit = _parseRawStatus(value);
    if (explicit != null) {
      return explicit;   // Tarih fields varken bile explicit dönüyor — YANLIŞ
    }
    if (requestStart != null || requestEnd != null || listingDate != null) {
      return _deriveStatus(...);
    }
    return IpoStatus.upcoming;
  }
  ```

  **Düzeltilmiş `_parseStatus`:**
  ```dart
  static IpoStatus _parseStatus(String? raw, {
    required DateTime? requestStart,
    required DateTime? requestEnd,
    required DateTime? listingDate,
  }) {
    final hasTimeline = requestStart != null || requestEnd != null || listingDate != null;
    
    if (hasTimeline) {
      // Tarih alanları mevcut: her zaman gerçek tarihlerden türet
      return _deriveStatus(
        requestStart: requestStart,
        requestEnd: requestEnd,
        listingDate: listingDate,
        fallbackStatus: _parseRawStatus(raw?.trim().toLowerCase() ?? '') ?? IpoStatus.upcoming,
      );
    }
    
    // Tarih alanı hiç yoksa: Firestore status'unu döndür (tek kaynak kalan)
    final explicit = _parseRawStatus(raw?.trim().toLowerCase() ?? '');
    return explicit ?? IpoStatus.upcoming;
  }
  ```

  Bu düzeltme `fromJson` sırasında `_status` alanını doğru set eder. Böylece `status` getter her iki yolu da (timeline var / yok) doğru işler.

  **Ek olarak:** `status` getter'ındaki `_hasTimelineData` bloğu da korunmalı çünkü getter her `status` erişiminde anlık saatle yeniden hesaplar.

  **Files:** `lib/models/ipo_item.dart`  
  **Verify:** `flutter test test/ipo_logic_test.dart`

---

- [ ] 5. **`_QuickCard` — iç `Expanded` wrapper'ı kaldır**

  `_QuickCard.build()` şu an `Expanded` döndürüyor. Çağrı yeri zaten `Expanded` içinde. Bu Flutter'da `ParentDataWidget` hatasına yol açıyor.

  **Mevcut kod (home_screen.dart ~1502):**
  ```dart
  @override
  Widget build(BuildContext context) {
    final isWhite = color == Colors.white;
    return Expanded(           // <-- KALDIRILACAK
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 90,
          // ...
        ),
      ),
    );
  }
  ```

  **Düzeltilmiş:**
  ```dart
  @override
  Widget build(BuildContext context) {
    final isWhite = color == Colors.white;
    return GestureDetector(    // <-- Expanded kaldırıldı
      onTap: onTap,
      child: Container(
        height: 90,
        // ...
      ),
    );
  }
  ```

  Çağrı yeri değişmeyecek — `Expanded(child: _QuickCard(...))` doğru kalıyor.

  **Files:** `lib/screens/home_screen.dart`  
  **Verify:** `flutter run` çıktısında `Incorrect use of ParentDataWidget` hatası kaybolmalı. `flutter test` geçmeli.

---

- [ ] 6. **Yeni birim testler ekle — kural doğrulama**

  `test/ipo_logic_test.dart` dosyasına yeni test senaryoları ekle:

  ```
  Senaryo A: requestStart ve requestEnd geçmişte, listingDate null, status='upcoming'
             → Beklenen: IpoStatus.pendingListing (kesinlikle upcoming değil)

  Senaryo B: requestStart ve requestEnd geçmişte, listingDate geçmişte, status='upcoming'  
             → Beklenen: IpoStatus.trading

  Senaryo C: tüm tarih alanları null, status='upcoming'
             → Beklenen: IpoStatus.upcoming (tarih bilgisi yoksa tahmin yapılamaz)

  Senaryo D: requestStart gelecekte, status='trading' (yanlış Firestore değeri)
             → Beklenen: IpoStatus.upcoming

  Senaryo E: SOHO case — requestStart='2026-06-30', requestEnd='2026-07-01', listingDate='2026-07-08', status='upcoming'
             → Beklenen: IpoStatus.trading (listingDate geçmişte)

  Senaryo F: SOHO case no-listingDate — requestStart='2026-06-30', requestEnd='2026-07-01', listingDate=null, status='upcoming'
             → Beklenen: IpoStatus.pendingListing (requestEnd geçmişte, listingDate bilinmiyor)
  ```

  **Files:** `test/ipo_logic_test.dart`  
  **Verify:** `flutter test test/ipo_logic_test.dart` — tüm yeni + mevcut testler geçmeli

---

- [ ] 7. **`_groupedItems()` — savunmacı filtre ek kontrolü**

  `ipo_screen.dart` içindeki `_groupedItems()` metodunda `upcoming` listesi zaten `item.status != IpoStatus.upcoming` filtresi kullanıyor. Bu yeterli — model düzeltildiğinde filtre otomatik çalışacak.

  Ancak `_refreshTimer` ve `_statusTimer` açısından: mevcut kod 5 dakikada bir `setState()` çağırıyor, bu tarih geçişlerini UI'da yansıtıyor. Bu mekanizma doğru.

  **Ekstra savunmacı kural:** `upcoming` listesine ek filtre:
  ```dart
  .where((item) {
    if (item.status != IpoStatus.upcoming) return false;
    // Ek güvenlik: requestStart geçmişse kesinlikle upcoming değil
    final rs = item.requestStart;
    if (rs != null && rs.isBefore(DateTime.now().toUtc().add(const Duration(hours: 3)))) {
      return false;
    }
    final rd = item.requestDates.toLowerCase();
    if (rd.contains('ertelendi') || rd.contains('postponed')) return false;
    return true;
  })
  ```

  Bu, model düzeltmesinin yanında UI katmanında da bir emniyet kemeri sağlar.

  **Files:** `lib/screens/ipo_screen.dart`  
  **Verify:** SOHO ve benzeri geçmiş tarihli kayıtlar "Yaklaşan" sekmesinde görünmemeli

---

## Uygulama Sırası (Bağımlılık Sırası)

1. **Madde 4** → `IpoItem._parseStatus` düzelt (en kritik, kök neden)
2. **Madde 2** → `IpoItem._deriveStatus` içine `requestStart` geçmiş güvenlik kuralı ekle
3. **Madde 6** → Yeni testler yaz ve çalıştır
4. **Madde 5** → `_QuickCard` Expanded düzelt (bağımsız, ama ayrı commit)
5. **Madde 7** → `_groupedItems()` savunmacı filtre (opsiyonel ek katman)
6. **Madde 3** → `IpoService` Firestore belge zenginleştirme (opsiyonel/kompleks)

---

## Model Alanları ve Türleri

```dart
// lib/models/ipo_item.dart

final String companyName;       // String
final String requestDates;      // String (display label, "30 Haziran, 1 Temmuz 2026")
final String price;             // String
final String lot;               // String
final String distributionType;  // String
final String symbol;            // String (UPPER)
final IpoStatus _status;        // enum — fromJson'dan set edilen Firestore değeri
final DateTime? requestStart;   // Nullable DateTime — UTC (Firestore Timestamp→ISO)
final DateTime? requestEnd;     // Nullable DateTime — UTC
final DateTime? listingDate;    // Nullable DateTime — UTC
final String kapUrl;            // String
final String source;            // String
final DateTime? publishedAt;    // Nullable DateTime

// Türkiye saati (UTC+3) için:
static DateTime _nowInTurkey() =>
    DateTime.now().toUtc().add(const Duration(hours: 3));
```

**Önemli Not:** `requestStart`, `requestEnd`, `listingDate` alanları UTC ISO string veya Firestore Timestamp olarak saklanır, `_parseFlexibleDate` bunları `DateTime` nesnesine dönüştürür. Türkiye saati karşılaştırmaları için `_nowInTurkey()` kullanılır — günlük sınır (`_startOfDay`, `_endOfDay`) da Firestore tarihlerinin UTC gece yarısı değerleri göz önüne alınarak değerlendirilir.

---

## Test Komutu

```bash
flutter test test/ipo_logic_test.dart
flutter test test/widget_test.dart
flutter test
```

---

## Sınıflandırma Kuralları Özeti (Hedef Davranış)

| Koşul | Kategori |
|-------|----------|
| `requestStart > şimdi` | Yaklaşan |
| `requestStart <= şimdi` ve `requestEnd >= şimdi` | Talep Topluyor |
| `requestEnd < şimdi` ve `listingDate > şimdi` | Listeleme Bekliyor |
| `listingDate <= şimdi` | Borsada |
| `requestEnd < şimdi` ve `listingDate` null | Listeleme Bekliyor (tahmin edilemez, borsaya girmemiş sayılır) |
| Tüm tarihler null | Firestore `status` değeri kullanılır (son çare) |
| Borsada olanlar | Sadece en yeni 10'u göster (`listingDate DESC`) |

**Kesin kural:** `requestStart` geçmişse, sonuç ne olursa olsun `IpoStatus.upcoming` olamaz.
