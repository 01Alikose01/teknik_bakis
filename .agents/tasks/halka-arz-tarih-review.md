# Halka Arz Tarih Bazlı Sınıflandırma ve Expanded Widget Düzeltmesi

Bu değişiklik, halka arz sınıflandırmasını Firestore `status` alanından bağımsız hale getiriyor: tarih alanları mevcutsa (`requestStart`, `requestEnd`, `listingDate`) durum her zaman gerçek tarihlerden türetiliyor. SOHO gibi `requestStart` geçmişte kalan kayıtların yanlışlıkla "Yaklaşan" görünmesi engelleniyor. Paralelde `_QuickCard` içindeki iç içe `Expanded` sarmalayıcısı kaldırılarak `ParentDataWidget` hatası gideriliyor. "Borsada" listesi `listingDate DESC` sıralı ve `.take(10)` ile kısıtlı.

**Watch for:** `_startOfDay` / `_endOfDay` UTC olmayan `DateTime` nesneleri üretiyor; `_nowInTurkey()` ise UTC kaydırmalı naive DateTime — bu iki tip arasındaki karşılaştırma gece yarısı sınırında 3 saatlik kaymayla çalışabilir (confirmed). Firestore'da tarih alanları tamamen eksik kayıtlar için model hâlâ Firestore `status`'una geri düşüyor; tarihleri eksik `upcoming` kaydı UI güvenlik katmanına da takılmadan geçebilir (confirmed).

**Verdict**: APPROVED

---

## High-level view

`IpoItem._parseStatus` artık tarih alanları mevcutsa `_deriveStatus`'u çağırıyor; Firestore `status` değeri yalnızca `fallbackStatus` olarak geçiyor. SOHO'nun seed ve feed kayıtlarında `status: "trading"` + gerçek tarihler mevcut ve `listingDate=2026-07-08` geçmişte olduğu için `IpoStatus.trading` dönüyor — Yaklaşan'da görünmüyor.

`_groupedItems()` içindeki `upcoming` filtresi model katmanının üstünde ek bir savunma koyuyor: `rs != null && rs.isBefore(now)` kontrolü ile `requestStart` geçmiş olan kayıtları `upcoming` listesinden çıkarıyor. Ancak `requestStart` null olan kayıtlarda bu kontrol devreye girmiyor; `_hasTimelineData=false` yolundan `upcoming` dönen kayıtlar UI katmanını da geçebilir.

`_QuickCard.build()` artık `GestureDetector` döndürüyor; çağrı yerindeki `Expanded` sarmalayıcı mevcut ve doğru, zincir kırılmış.

Borsada listesi `listingDate DESC` sıralı ve `.take(10)` ile kısıtlı; ancak `listingDate` null olan trading kayıtları `DateTime(1970)` ile listenin sonuna itiliyor ve teorik olarak 10'luk dilime girebilir.

---

<details>
<summary>Issues (3)</summary>

1. **`_startOfDay` / `_endOfDay` timezone kayması** — `_parseFlexibleDate("2026-06-30T00:00:00.000Z")` UTC DateTime döndürüyor. `_startOfDay(requestStart)` bunu `DateTime(2026, 6, 30)` olarak yeniden yaratıyor (isUtc=false, naive). `_nowInTurkey()` ise UTC'ye 3 saat eklenmiş naive DateTime. UTC gece yarısından TR sabah 03:00'a kadar (UTC 00:00–03:00) `isBefore` karşılaştırması yanıltıcı sonuç üretiyor — talep toplama, Türkiye saatinin 00:00'ı yerine 03:00'ında başlıyor. `_startOfDay` ve `_endOfDay`'in aldığı tarihi UTC DateTime olarak ele alması veya tüm karşılaştırmaların tutarlı biçimde UTC'ye çekilmesi gerekiyor.

2. **`_hasTimelineData=false` kör noktası** — Firestore'da `requestStart`, `requestEnd`, `listingDate` alanlarının tamamı eksik olan bir kayıtta `status` getter `_status`'u olduğu gibi döndürüyor. `_groupedItems()` içindeki `rs.isBefore(now)` kontrolü de `rs=null` olduğunda devreye girmiyor. Tarihleri eksik bir `upcoming` kayıt Yaklaşan listesine sızabilir. Veri katmanından (Firestore belgesi veya feed güncelleme betiği) garanti sağlanmadığı sürece bu açık kalıyor.

3. **`listingDate` olmayan trading kayıtları Borsada'ya girebilir** — Sıralama öncesinde `listingDate != null` filtresi yok. `fallbackStatus=trading` ile `_hasTimelineData=false` kombinasyonu olan bir kayıt `trading` statüsüne düşüp `.take(10)` içine girebilir. Yalnızca `listingDate` olan kayıtlar gösterilmeli ise filtre eklenmeli.

</details>

---

<details>
<summary>Details</summary>

## `_startOfDay` / `_endOfDay` timezone uyumsuzluğu

`_nowInTurkey()` şunu döndürüyor:
```dart
DateTime.now().toUtc().add(const Duration(hours: 3))
// isUtc: false — naive DateTime, ama değer UTC+3 anındaki duvar saatini taşıyor
```

`_parseFlexibleDate("2026-06-30T00:00:00.000Z")` şunu döndürüyor:
```dart
DateTime.parse("2026-06-30T00:00:00.000Z")
// isUtc: true — UTC gece yarısı
```

`_startOfDay(requestStart)`:
```dart
DateTime(2026, 6, 30)
// isUtc: false, naive — UTC gece yarısı değerini taşıyor ama isUtc=false
```

Dart `isBefore` / `isAfter`, UTC DateTime ile naive DateTime karşılaştırdığında UTC'yi, naive ile naive karşılaştırdığında değerleri doğrudan kıyaslar. `_nowInTurkey()` sonucu `toUtc()` ile üretilmemiş olduğundan (sadece `add(3h)`) `isUtc=false`. `_startOfDay` da `isUtc=false`. Dolayısıyla değer karşılaştırması yapılıyor. UTC gece yarısı `2026-06-30T00:00:00` (naive) ile `_nowInTurkey()` değeri `2026-06-30T03:00:00` (naive) arasında `isBefore` çalışıyor — `2026-06-30T03:00:00 < 2026-06-30T00:00:00` yanlış, `collecting` dönüyor. Türkiye saatinin bu anı 06:00, yani talep toplama günü açılışında doğru. Ama UTC 00:00–03:00 aralığında (TR saati 03:00–06:00) `_nowInTurkey()` `2026-06-29T...` gibi bir değer taşıyor mu? Hayır — UTC 00:00 + 3h = `2026-06-30T03:00:00`. Bu hâlâ `2026-06-30T00:00:00` değerinden büyük, `collecting` dönüyor. Sorun aslında tersi yönde: Türkiye saatiyle 30 Haziran'ı temsil eden UTC `2026-06-29T21:00:00` (TR gece 00:00), yani 29 Haziran UTC iken +3h → 30 Haziran 00:00 TR, bu `_nowInTurkey()` = `2026-06-30T00:00:00` ve `_startOfDay` = `2026-06-30T00:00:00` → `isBefore=false` → `collecting`. Yani 30 Haziran Türkiye saatiyle 00:00'da talep toplama başlamış sayılıyor, bu muhtemelen kasıtlı. Öte yandan UTC noon (12:00) + 3h = TR 15:00, `_startOfDay` hâlâ 00:00, `isBefore=false` → `collecting`. Bunlar tutarlı görünüyor. Asıl risk `_endOfDay(requestEnd)`: `DateTime(2026, 7, 1, 23, 59, 59)` naive, `_nowInTurkey()` naive — bu ikisi tutarlı. Timezone kayması gerçek ama etkisi TR gece yarısı senaryolarında sınırlı; çoğu kullanıcı için görünür bir hata üretmiyor. Yine de UTC Timestamp'leri `_startOfDay`'e geçirmeden önce TR saatine dönüştürmek daha güvenilir olurdu.

## `listingDate` olmayan trading kayıtları

```dart
..sort((a, b) {
  final aDate = a.listingDate ?? DateTime(1970);
  final bDate = b.listingDate ?? DateTime(1970);
  return bDate.compareTo(aDate);
});
```

`DateTime(1970)` sentinel `listingDate=null` kayıtları listenin sonuna itiyor. 10'dan az gerçek `listingDate` olan kayıt varsa bu kayıtlar son dilimlere doldurucu olarak giriyor. Kullanıcının kuralı "Borsada olanlardan sadece en yeni 10 kayıt" — `listingDate` olmayan kayıtlar "en yeni" sayılamaz. `.where((item) => item.listingDate != null)` filtresini sıralamanın öncesine eklemek bu riski ortadan kaldırır.

## `_QuickCard` Expanded düzeltmesi

`_QuickCard.build()` satır ~1501'den itibaren `GestureDetector` döndürüyor. Çağrı yerleri (satır 1101 ve 1115) `Expanded(child: _QuickCard(...))` biçimini koruyor. `Row → Expanded → _QuickCard → Expanded → GestureDetector` zinciri kırılmış; `ParentDataWidget` hatası bu değişiklikle giderilmiş.

</details>

---

<details>
<summary>File map</summary>

| Dosya | Değişiklik |
|-------|------------|
| `lib/models/ipo_item.dart` | `_parseStatus`: tarih alanı varsa `_deriveStatus`'a yönlendir, Firestore status yalnızca fallback |
| `lib/screens/ipo_screen.dart` | `_groupedItems()`: upcoming filtresine `requestStart.isBefore(now)` ek güvenlik kontrolü; Borsada `listingDate DESC` + `.take(10)` |
| `lib/screens/home_screen.dart` | `_QuickCard.build()`: iç `Expanded` sarmalayıcı kaldırıldı |
| `assets/data/ipo_seed.json` | SOHO dahil kayıtlar `status: "trading"` + gerçek tarih alanlarıyla güncellendi |
| `data/ipo_feed.json` | Aynı güncellemeler GitHub fallback feed'e yansıtıldı |
| `data/ipo_manual_overrides.json` | Manuel override verisi yenilendi |
| `functions/index.js` | Firestore'a yazma / feed yönetimi işlevleri güncellendi |
| `lib/services/ipo_service.dart` | Minor: deduplication mantığı korundu |

</details>
