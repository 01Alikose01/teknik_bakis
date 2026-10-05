# Halka Arz (IPO) Ekranı — Araştırma Raporu

## Özet

Mevcut kodda 4 kategori mantığı **büyük ölçüde doğru** ama **iki kritik hata** var:

1. **`_deriveStatus` içinde `collecting` branch'i yanlış:** Talep toplama aktifken (`requestStart <= now <= requestEnd`) `collecting` doğru döndürülüyor, ancak `requestEnd` geçmişte kaldığında **`listingDate` bilinmiyorsa doğrudan `pendingListing`'e düşmesi gerekiyor** — mevcut Dart kodu bunu doğru yapıyor. **Asıl sorun** `update_ipo_feed.mjs` scraper'ındaki `deriveStatus` fonksiyonu: `requestEnd` geçtiğinde `pendingListing` döndürmek yerine **her zaman `'trading'` döndürüyor**. Bu, talep toplama bitmiş ama borsada listelenme tarihi belirsiz olan hisseleri `trading` olarak etiketliyor.

2. **`_deriveStatus` içinde `collecting` son-gün sınır sorunu (küçük):** Dart tarafında `now.isAfter(_endOfDay(requestEnd))` kontrolü, talep bitiş gününü `23:59:59`'a kadar `collecting` sayıyor, bu doğru. Fakat `requestStart != null` dalında yalnızca `requestStart`'a bakılıyor; `requestEnd` kontrol edilmiyor. Yani `requestStart <= now` koşulu `requestEnd`'i geçmiş durumlarda da `collecting` döndürebilir. (Bu dal yalnızca `requestEnd == null` durumunda çalıştığı için pratikte nadir tetiklenir, ama dokümante edilmeli.)

3. **Test'te yanlış beklenti:** `ipo_logic_test.dart` satır 54-61'deki "Liste Bekleyen" test senaryosu **yanlış beklenti** içeriyor: `requestEnd` geçmiş, `listingDate` gelecekte olan bir kayda `IpoStatus.collecting` bekleniyor — ama doğru cevap `IpoStatus.pendingListing`'dir.

---

## Dosya/Sembol Haritası

| Katman | Dosya | Görev |
|--------|-------|-------|
| Model  | `lib/models/ipo_item.dart` | `IpoItem`, `IpoStatus` enum, `_deriveStatus()`, `_parseStatus()` |
| Servis | `lib/services/ipo_service.dart` | Firestore/GitHub veri çekme, cache, `_mapItems()`, dedup |
| Ekran  | `lib/screens/ipo_screen.dart` | `TabBarView` (4 sekme), `_groupedItems()` |
| BIST entegrasyon | `lib/services/bist_stocks.dart` | `syncBistStocksWithIpoItems()` — trading IPO'ları hisse listesine ekler |
| Scraper | `tools/update_ipo_feed.mjs` | `deriveStatus()` (JS) — JSON feed'deki `status` alanını üretir |
| Veri | `data/ipo_feed.json`, `assets/data/ipo_seed.json` | Ham IPO verileri |
| Test | `test/ipo_logic_test.dart` | Dart tarafı mantık testleri |

---

## Kategori Belirleme Mantığı — Detaylı Analiz

### Dart Tarafı (`lib/models/ipo_item.dart`)

Durum belirleme **çift katmanlı**:

1. **`fromJson` sırasında `_parseStatus()` çağrılır:**
   - JSON'daki `status` string'ini önce `_parseRawStatus()` ile ayrıştırır.
   - String tanınıyorsa (`upcoming`, `trading`, vb.) explicit değeri döndürür.
   - String tanınmıyorsa veya boşsa timeline verilerine (`requestStart`, `requestEnd`, `listingDate`) bakarak `_deriveStatus()` çağrılır.

2. **`IpoItem.status` getter çağrıldığında tekrar `_deriveStatus()` çalışabilir:**
   - `_hasTimelineData` true ise (herhangi bir tarih alanı varsa) her `status` erişiminde `_deriveStatus()` yeniden hesaplanır.
   - Bu sayede sabit JSON değeri (`"status": "upcoming"`) olsa bile tarihler bunu override eder.
   - 5 dakikada bir `setState` ile `_statusTimer` UI'ı yeniliyor; tarih geçişleri otomatik yansıyor.

#### `_deriveStatus()` Karar Ağacı (Dart)

```
1. listingDate != null && listingDate <= now  → trading
2. requestEnd != null && now > endOfDay(requestEnd):
     2a. listingDate != null && listingDate <= now → trading
     2b. listingDate != null && listingDate > now  → pendingListing  ✓
     2c. listingDate == null && fallback == trading → trading
     2d. listingDate == null && diğer             → pendingListing  ✓
3. requestStart != null:
     3a. now < startOfDay(requestStart) → upcoming  ✓
     3b. aksi hâlde                     → collecting ✓ (küçük sorun: requestEnd kontrolü yok burada)
4. listingDate != null:
     4a. now < startOfDay(listingDate) → upcoming
     4b. aksi hâlde                    → trading
5. fallbackStatus döndür
```

Dart mantığı **4 kategorinin tümünü doğru kaplıyor**, ancak `fallbackStatus == trading` özel durumu dikkatli kullanılmalı (bkz. Bug 1 alt kısım).

---

### JS Scraper Tarafı (`tools/update_ipo_feed.mjs`)

```js
function deriveStatus({ requestStart, requestEnd, listingDate }) {
  const now = new Date();
  if (listingDate && listingDate <= now) return 'trading';
  if (requestStart && requestEnd) {
    if (now < startOfDay(requestStart)) return 'upcoming';
    if (now <= endOfDay(requestEnd))    return 'collecting';
    return 'trading';   // ← BUG: pendingListing olmalı!
  }
  if (requestStart) {
    return now < startOfDay(requestStart) ? 'upcoming' : 'collecting';
  }
  return 'upcoming';
}
```

**Kritik hata:** Talep toplama bittiğinde (`requestEnd` geçmiş) ama `listingDate` henüz gelmemişse (ya da hiç yoksa) doğrudan `'trading'` döndürüyor. Dart tarafındaki `pendingListing` state'ini JS tarafı hiç üretmiyor.

---

## Mevcut Feed Verisi Analizi

`data/ipo_feed.json` ve `assets/data/ipo_seed.json`'daki **tüm 23 kayıt** `"status": "trading"` içeriyor. Bu durum iki nedene dayanabilir:

1. Gerçekten hepsi listelendi (veriler 2026 tarihleri taşıyor, bugünden geçmiş).
2. Scraper'ın `deriveStatus` hatası tüm "talep bitti ama listeleme bekliyor" kayıtları `trading` yazdı.

`lastUpdated: "2026-10-03T15:00:00.000Z"` tarihinde Dart uygulaması çalıştığında, bu kayıtların `listingDate`'leri geçmişte olduğundan Dart'ın `_deriveStatus()`'u da `trading` döndürür — bu sefer doğru. Ama gerçek zamanlı veriler geldiğinde sorun ortaya çıkacaktır.

---

## Hata Detayları

### Bug 1 (Kritik) — JS `deriveStatus` `pendingListing` üretmiyor

**Dosya:** `tools/update_ipo_feed.mjs`, satır ~428

**Sorun:** `requestEnd` geçtiğinde `'trading'` hardcoded dönüyor. `listingDate` yoksa veya gelecekteyse bu yanlış.

**Etki:** Yeni bir IPO talep toplama bitti ama BIST listesi bekliyorsa, scraper JSON'a `"status": "trading"` yazar. Dart tarafı JSON'daki explicit `"trading"` değerini gördüğünde fallback olarak kullanır ve `_hasTimelineData` check'ini geçse bile `listingDate` yoksa `pendingListing` döndürmesi gerekir — bu da çalışır ama JS tarafında gereksiz `"trading"` etiketi kalır, ileriki Firestore sorgularını/filtrelerini bozabilir.

**Düzeltme:**
```js
// Değiştir:
return 'trading';
// Şununla:
if (listingDate && listingDate > now) return 'pending_listing';
return listingDate ? 'trading' : 'pending_listing';
```

### Bug 2 (Orta) — Test dosyasında yanlış beklenti

**Dosya:** `test/ipo_logic_test.dart`, satır 54-61

**Sorun:**
```dart
final waitingListing = IpoItem.fromJson({
  'requestStart': isoDay(now.subtract(const Duration(days: 6))),
  'requestEnd':   isoDay(now.subtract(const Duration(days: 4))),  // geçmişte
  'listingDate':  isoDay(now.add(const Duration(days: 3))),        // gelecekte
  'status': 'trading',
});
expect(waitingListing.status, IpoStatus.collecting);  // ← YANLIŞ
```

`requestEnd` 4 gün önce geçti, `listingDate` 3 gün sonra gelecek → `_deriveStatus` doğru olarak `pendingListing` döndürür. Test `collecting` bekliyor, bu **yanlış beklenti**. Test bu yüzden mevcut durumda **başarısız** olur.

**Düzeltme:** `expect(waitingListing.status, IpoStatus.pendingListing);` olmalı.

### Bug 3 (Küçük) — `_deriveStatus` branch 3'te `requestEnd` kontrolü yok

**Dosya:** `lib/models/ipo_item.dart`, satır ~231

```dart
if (requestStart != null) {
  final start = _startOfDay(requestStart);
  return now.isBefore(start) ? IpoStatus.upcoming : IpoStatus.collecting;
  // requestEnd null olduğu için buraya geliyor, pratikte sorun yaratmıyor
  // ama requestEnd set edilip bu dala girilirse collecting hatalı olabilir
}
```

Bu dal yalnızca `requestEnd == null` durumunda çalışır (çünkü branch 2 `requestEnd != null`'ı kontrol ediyor). Tek tarihli IPO'larda (`requestStart == requestEnd`) `requestEnd` set edilmişse branch 2'ye girer, branch 3'e hiç girmez. Risk düşük ama belgelenmeli.

---

## UI / Ekran Tarafı

`lib/screens/ipo_screen.dart` — `_groupedItems()` metodu (satır ~351):

- `_items` listesini 4 gruba ayırıyor: `.upcoming`, `.collecting`, `.pendingListing`, `.trading`
- `latestTrading`: `trading` listesinin yalnızca ilk 10'unu gösteriyor (bilgi kartı var)
- Header'daki chip counter `grouped.trading.length` (tüm listeyi sayıyor) ama sekmedeki liste `latestTrading` (10 kayıt)
- Bu tutarsızlık kullanıcıyı şaşırtabilir ("Borsada: 15" gösteriyor ama 10 kayıt listeliyor)

Sıralama:
- Yaklaşan/Talep Topluyor: `requestStart` ascending (yakın tarih önce)
- Listeleme Bekliyor: `listingDate` → `requestEnd` ascending
- Trading: `sortDate` descending (en yeni önce), sonra ilk 10

---

## Önerilen Düzeltmeler (Önem Sırasına Göre)

1. **`test/ipo_logic_test.dart` satır 61:** `IpoStatus.collecting` → `IpoStatus.pendingListing`

2. **`tools/update_ipo_feed.mjs` `deriveStatus` fonksiyonu** (~satır 427-429): `return 'trading'` yerine `pendingListing` mantığı ekle:
   ```js
   // requestEnd geçti ama listingDate yok ya da gelecekte
   if (listingDate && listingDate > now) return 'pending_listing';
   return listingDate ? 'trading' : 'pending_listing';
   ```

3. **`_parseRawStatus` içinde `pending_listing` desteği ekle** (`lib/models/ipo_item.dart`): JS scraper `pending_listing` üretirse Dart tanımasın diye zaten `pendinglisting` ve `pending_listing` case'leri mevcut. ✓ (Zaten var, ekstra değişiklik gerekmez.)

4. **(İsteğe bağlı)** Header chip counter'ı `grouped.latestTrading.length` yerine `grouped.trading.length` gösteriyor — tutarlılık için `latestTrading.length` veya info metni değiştirilebilir.

---

## Sonuç

Dart tarafındaki 4-kategori mantığı (`IpoItem._deriveStatus`) **büyük ölçüde doğru çalışıyor**. Ana sorun **JS scraper** (`update_ipo_feed.mjs`) — talep toplama biten ama borsada listelenmemiş IPO'ları `trading` olarak etiketliyor. Dart, JSON'daki explicit `"trading"` değerini görünce `fallbackStatus == IpoStatus.trading` kabul ederek `pendingListing` yerine `trading` döndürebilir. **Test dosyasındaki yanlış beklenti** bu sorunun erken tespitini engellemiş.
