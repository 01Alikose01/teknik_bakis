# Implementation Plan — Halka Arz Durum & Listeleme Düzeltmesi

## Keşif Bulguları

### Gerçek Tarih Alanları (`IpoItem`)
| Alan | Tip | Açıklama |
|------|-----|----------|
| `requestStart` | `DateTime?` | Talep toplama başlangıç tarihi |
| `requestEnd` | `DateTime?` | Talep toplama bitiş tarihi |
| `listingDate` | `DateTime?` | Borsada ilk işlem/listelenme tarihi |
| `publishedAt` | `DateTime?` | KAP'ta yayın tarihi (yedek sıralama) |

`sortDate` getter: `listingDate ?? requestEnd ?? requestStart ?? publishedAt`

### Durum Hesaplama Mantığı (Mevcut)
`IpoItem.status` getter → `_hasTimelineData` true ise `_deriveStatus()` çağrılır.
`_deriveStatus()` her erişimde yeniden hesaplar; 5 dakikalık `_statusTimer` UI'ı tazeler.
`_parseStatus()` önce JSON'daki `status` string'ini okur; tanınırsa o değeri kullanır.
**Kritik:** JSON'da `"status": "trading"` varsa `fallbackStatus = IpoStatus.trading` olur → `listingDate` bilinmiyorsa trading döndürebilir.

### Tespit Edilen Hatalar

#### Hata 1 — Test dosyasında yanlış beklenti (satır 61)
`test/ipo_logic_test.dart` satır 61: `expect(waitingListing.status, IpoStatus.collecting)`
`requestEnd` 4 gün geçmiş + `listingDate` 3 gün gelecekte → doğru cevap `IpoStatus.pendingListing`.
Mevcut test bu nedenle **başarısız**.

#### Hata 2 — Talep Topluyor sıralama yönü yanlış
`ipo_screen.dart` `_groupedItems()` satır 588: `return aDate.compareTo(bDate);` → ascending (eskiden yeniye).
Spec: talep başlangıç tarihine göre **en yeniden eskiye** (descending) → `bDate.compareTo(aDate)`.

#### Hata 3 — Borsada chip sayacı 10 değil, tüm trading sayısını gösteriyor
`ipo_screen.dart` satır 240: `value: grouped.trading.length.toString()`
Listede `latestTrading` (max 10) gösterilirken sayaç tüm trading'i sayıyor.
Spec: "Sayaç da gösterilen 10 kayıtla uyumlu olsun".

#### Hata 4 — Türkiye saat dilimi (UTC+3) açık kullanılmıyor
`_deriveStatus()` ve `_groupedItems()` içinde `DateTime.now()` cihazın yerel saatini alır.
Spec UTC+3 kullanımı zorunlu tutuyor. Hesaplama `DateTime.now().toUtc()` + 3 saat offset ile yapılmalı.

#### Hata 5 (Küçük) — Yaklaşan extra guard tutarsız
`_groupedItems()` upcoming filtresi: `item.requestStart!.isBefore(today)` → `requestStart` bugün olan hisseleri Yaklaşan'dan çıkarır. Ama bu kayıtlar aynı zamanda `_deriveStatus()` ile `collecting` sayılır. Çift filtre nedeniyle bu hisseler hiçbir sekmede görünmeyebilir.
Düzeltme: `IpoStatus.upcoming` döndüren kayıtları güvene al, ekstra `requestStart.isBefore(today)` guard'ını kaldır.

#### Durum (JS Scraper) — Zaten Düzeltilmiş
`tools/update_ipo_feed.mjs` `deriveStatus()` fonksiyonu mevcut kodda doğru:
`pending_listing` mantığı zaten uygulanmış. Bu dosyaya dokunmaya gerek yok.

---

## Uygulama Planı

### Adım 1 — Test beklentisini düzelt
**Dosya:** `test/ipo_logic_test.dart`

Satır 61'deki yanlış beklentiyi düzelt:
```dart
// Eski (yanlış):
expect(waitingListing.status, IpoStatus.collecting);
// Yeni (doğru):
expect(waitingListing.status, IpoStatus.pendingListing);
```

**Doğrulama:** `flutter test test/ipo_logic_test.dart` — tüm testler geçmeli.

---

### Adım 2 — Türkiye saat dilimini (UTC+3) tüm tarih hesaplamalarında kullan
**Dosya:** `lib/models/ipo_item.dart`

`_deriveStatus()` metoduna UTC+3 saatini hesaplayan özel bir `_nowInTurkey()` yardımcısı ekle ve `DateTime.now()` yerine bunu kullan:

```dart
static DateTime _nowInTurkey() {
  return DateTime.now().toUtc().add(const Duration(hours: 3));
}
```

`_deriveStatus()` içindeki `final now = DateTime.now();` satırını
`final now = _nowInTurkey();` ile değiştir.

`_startOfDay()` ve `_endOfDay()` metodları UTC+3 döndürülen `now` ile doğru çalışır çünkü tarih karşılaştırması yerel gün sınırlarına göre yapılır.

**Dosya:** `lib/screens/ipo_screen.dart`

`_groupedItems()` içindeki `final now = DateTime.now();` ve `final today = DateTime(now.year, now.month, now.day);` satırlarını UTC+3 kullanacak şekilde güncelle:

```dart
final now = DateTime.now().toUtc().add(const Duration(hours: 3));
final today = DateTime(now.year, now.month, now.day);
```

**Doğrulama:** `flutter analyze lib/models/ipo_item.dart lib/screens/ipo_screen.dart` — hata yok.

---

### Adım 3 — Sıralama yönlerini spec'e göre düzelt
**Dosya:** `lib/screens/ipo_screen.dart`, `_groupedItems()` metodu

**Talep Topluyor:** `aDate.compareTo(bDate)` → `bDate.compareTo(aDate)` (en yeni önce)

```dart
final collecting = all
    .where((item) => item.status == IpoStatus.collecting)
    .toList()
  ..sort((a, b) {
    final aDate = a.requestStart ?? a.sortDate ?? DateTime(2099);
    final bDate = b.requestStart ?? b.sortDate ?? DateTime(2099);
    return bDate.compareTo(aDate); // ← en yeniden eskiye
  });
```

**Yaklaşan, Listeleme Bekliyor, Borsada** sıralamaları mevcut kodda doğru:
- Yaklaşan: `aDate.compareTo(bDate)` = yakın tarih önce ✓
- Listeleme Bekliyor: `aDate.compareTo(bDate)` = en yakın tarih önce ✓
- Borsada: `all` listesi `bDate.compareTo(aDate)` (desc) pre-sort edilmiş, `trading.take(10)` doğru ✓

**Doğrulama:** `flutter analyze lib/screens/ipo_screen.dart` — hata yok.

---

### Adım 4 — Yaklaşan extra guard'ı kaldır, sadece status'a güven
**Dosya:** `lib/screens/ipo_screen.dart`, `_groupedItems()` upcoming filtresi

Mevcut:
```dart
final upcoming = all
    .where((item) {
      if (item.status != IpoStatus.upcoming) return false;
      final rd = item.requestDates.toLowerCase();
      if (rd.contains('ertelendi') || rd.contains('postponed')) return false;
      // Aşağıdaki guard KALDIRILACAK:
      if (item.requestStart != null &&
          item.requestStart!.isBefore(today)) return false;
      return true;
    })
    ...
```

`item.requestStart!.isBefore(today)` guard'ını kaldır. `_deriveStatus()` zaten:
- `requestStart <= now` → `collecting` döndürür (upcoming listesinde `status != upcoming` filtresi ile zaten elenecek)
- `requestStart > now` → `upcoming` döndürür ✓

`today` değişkeni artık yalnızca bu guard için kullanılıyordu; guard kaldırılınca `today` değişkenini de kaldır (eğer başka yerde kullanılmıyorsa).

**Doğrulama:** `flutter analyze lib/screens/ipo_screen.dart` — hata yok.

---

### Adım 5 — Borsada chip sayacını `latestTrading.length` ile güncelle
**Dosya:** `lib/screens/ipo_screen.dart`, `_buildHeader()` metodu

Mevcut:
```dart
_summaryChip(
  icon: Icons.candlestick_chart,
  label: 'Borsada',
  value: grouped.trading.length.toString(), // ← tüm trading
  color: const Color(0xFF34C759),
),
```

Düzeltme:
```dart
value: grouped.latestTrading.length.toString(), // ← gösterilen max 10
```

**Doğrulama:** `flutter analyze lib/screens/ipo_screen.dart` — hata yok.

---

### Adım 6 — Tüm 9 test senaryosunu kapsayan testler ekle
**Dosya:** `test/ipo_logic_test.dart`

Spec'in istediği 9 senaryoyu kapsayan yeni test grubunu ekle:

```dart
group('Halka Arz Durum Akışı', () {
  // 1. Talep tarihi gelecekte → Yaklaşan
  // 2. Talep başladı, bitmedi → Talep Topluyor
  // 3. Talep bitti, listeleme tarihi gelecekte → Listeleme Bekliyor
  // 4. Listeleme tarihi geçti → Borsada
  // 5-6. _IpoGroups.latestTrading max 10 kayıt, 11. gösterilmiyor (DB'den silinmiyor)
  // 7. Yeni hisse Borsada'ya geçince listeye en üstten giriyor
  // 8. Aynı hisse iki sekmede görünmüyor
  // 9. JSON'da "trading" yazsa da tarihler Borsada değilse doğru sınıflandırma
});
```

Test 5-6-7-8 için `_IpoGroups` sınıfını test etmek doğrudan mümkün değil (private). Bu testler `IpoItem` durum geçişlerini ve `IpoService._mapItems()` dedup mantığını test eder:
- 15 adet `trading` statüsündeki `IpoItem` oluştur (farklı `listingDate`'lerle)
- Bunları `_groupedItems` mantığıyla elle filtrele: `where status == trading` → sort by `listingDate` desc → `take(10)`
- 11. hissenin listede olmadığını, ama nesnenin hâlâ erişilebilir olduğunu doğrula

**Doğrulama:** `flutter test test/ipo_logic_test.dart` — tüm testler geçmeli.

---

### Adım 7 — Son doğrulama
`flutter analyze` çalıştır, sıfır hata/uyarı bekle.
`flutter test test/ipo_logic_test.dart` çalıştır, tüm testler geçmeli.

---

## Değişecek Dosyalar

| Dosya | Değişiklik |
|-------|-----------|
| `test/ipo_logic_test.dart` | Satır 61 beklenti düzeltmesi + 9 yeni test senaryosu |
| `lib/models/ipo_item.dart` | `_nowInTurkey()` yardımcısı + `_deriveStatus()` içinde kullanımı |
| `lib/screens/ipo_screen.dart` | UTC+3 now, collecting sort yönü, upcoming guard kaldır, Borsada sayaç |

## Dokunulmayacak Dosyalar
- `tools/update_ipo_feed.mjs` — `deriveStatus()` zaten doğru
- `lib/services/ipo_service.dart` — değişiklik gerekmez
- `lib/services/bist_stocks.dart` — dokunma
- KAP Haberleri, Borsa Haberleri, Trial, Premium, Billing, AI, UpdateService, back button
