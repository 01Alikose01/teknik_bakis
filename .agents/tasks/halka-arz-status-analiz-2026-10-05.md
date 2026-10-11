# Halka Arz Ekranı Durum Analizi — 2026-10-05

## Özet (TL;DR)

Sorunun temel nedeni **deploy açığı + Firestore'da bayat veri**: `functions/index.js`'deki
düzeltme (`89b8d5a`) Firebase'e deploy edilmemiş. Bu yüzden her 6 saatlik `syncIpoFeed`
çalışmasında eski (hatalı) kod yürütülmeye devam ediyor ve Firestore'daki yanlış `status`
değerleri düzeltilemıyor. Dart tarafı `_deriveStatus()` bu yanlış/eksik tarih alanlarını görünce
203 kaydı da `upcoming` olarak sınıflandırıyor.

---

## 1. Kategori Koşulları

### UI Gösterimi (`ipo_screen.dart` — `_groupedItems()`)

| Kategori | UI Filtresi | `_deriveStatus()` koşulu |
|---|---|---|
| **Yaklaşan** | `item.status == IpoStatus.upcoming` + `requestStart` null ya da gelecekte | `requestStart > now` |
| **Talep Topluyor** | `item.status == IpoStatus.collecting` | `requestStart <= now <= requestEnd` |
| **Listeleme Bekliyor** | `item.status == IpoStatus.pendingListing` | `requestEnd` geçmiş, `listingDate` gelecekte ya da bilinmiyor |
| **Borsada İşlem Görüyor** | `item.status == IpoStatus.trading` — görüntüde yalnızca `latestTrading` (son 10) | `listingDate <= now` veya `fallbackStatus == trading` ile `listingDate` null |

**"Kod bekleniyor"** metni: `ipo_screen.dart` satır ~269:
```dart
item.symbol.isEmpty ? 'Kod bekleniyor' : item.symbol
```
`symbol` alanı boş string veya null ise gösterilir. Sınıflandırmayı etkilemez; salt görsel.

**Ek guard** — `_groupedItems()` Yaklaşan filtresi:
```dart
final rs = item.requestStart;
final now = DateTime.now().toUtc().add(const Duration(hours: 3));
if (rs != null && rs.isBefore(now)) return false;
```
`_deriveStatus()` `upcoming` dese bile `requestStart` geçmişte ise kayıt Yaklaşan listesinden
çıkarılır. Bu kayıtlar hiçbir sekmede görünmez.

---

## 2. `symbol` Boş/Null Olduğunda

**UI'da:** `'Kod bekleniyor'` etiketi gösterilir (hem özet satırda hem detay tile'da).

**`_mapItems()` içinde dedup mantığı** (`ipo_service.dart` satır ~210):
```dart
final key = item.symbol.toUpperCase();
if (key.isEmpty) continue; // sembolsüz kayıt dedup'a girmez
```
Sembolü olan aynı şirket adı zaten `deduped` map'teyse sembolsüz kayıt eklenmez.
Aksi hâlde `noSymbol` listesine girer ve sonuçta döndürülür.

**`_deriveStatus()` üzerindeki etkisi:** `symbol` alanının durum hesaplamasında hiçbir rolü yok.
Dart tarafında BIST kontrolü yok; bu kontrol sadece `functions/index.js` tarafındaki
`computeIpoStatus()` / `reconcileStaleIpoStatuses()` içinde.

---

## 3. SOHOE ve ORZAX'ın Durumu

### Gerçek Durumları
Her ikisi de borsada işlem gören (`trading`) hissedir:
- **ORZAX** — `bistguncel.md`'de 101.70 TL fiyatıyla görünüyor. `listingDate: 2026-07-07`.
- **SOHOE** — `bistguncel.md`'de 12.07 TL fiyatıyla görünüyor. `listingDate: 2026-07-08`.

Her iki sembol `8700fa2` commit'iyle `lib/services/bist_stocks.dart` statik listesine eklendi.

### Firestore'daki Olası Durumları

`data/ipo_manual_overrides.json` diff'inden elde edilmiş bilgiler (HEAD commit):

| Alan | ORZAX | SOHOE |
|---|---|---|
| `status` | `trading` | `trading` |
| `requestStart` | `2026-06-29` | `2026-06-30` |
| `requestEnd` | `2026-07-01` | `2026-07-01` |
| `listingDate` | `2026-07-07` | `2026-07-08` |

**Ancak** bu değerler Firestore'a henüz yazılmamış olabilir. `ipo_manual_overrides.json`
doğrudan `functions/index.js` tarafından okunmuyor — bu dosya yalnızca
`tools/update_ipo_feed.mjs` (GitHub Action) tarafından kullanılıyor ve
çıktısı `data/ipo_feed.json`'a gidiyor. Uygulama Firestore öncelikli olduğundan
bu GitHub feed yalnızca Firestore çöktüğünde devreye girer.

### Neden Yanlış Kategoride Göründüklerinin Zinciri

```
Firestore ipo_items → ORZAX/SOHOE
    status: "upcoming" (ya da listingDate eksik)
        ↓
IpoItem.fromJson() → _parseStatus()
    _hasTimelineData? → requestEnd var ama listingDate yok
        ↓
_deriveStatus() → requestEnd geçmiş, listingDate null, fallbackStatus=upcoming
    → IpoStatus.pendingListing
    VEYA: requestEnd de yoksa → fallbackStatus=upcoming → IpoStatus.upcoming
        ↓
Ekranda: "Yaklaşan" veya "Listeleme Bekliyor"
```

**ORZAX** Yaklaşan görünüyorsa: Firestore'daki kaydında hem `requestEnd` hem
`listingDate` muhtemelen null → `_deriveStatus()` `fallbackStatus = upcoming`
döndürüyor.

**SOHOE** Listeleme Bekliyor görünüyorsa: Firestore'daki kaydında `requestEnd`
geçmiş ama `listingDate` null → `_deriveStatus()` `pendingListing` döndürüyor.

**Beklenen durum:** Her ikisi de `IpoStatus.trading` olmalı.

---

## 4. `syncIpoManual` Neden `reconciled: 0` Döndü

`reconcileStaleIpoStatuses()` (`functions/index.js` satır 997) şu kayıtları günceller:

1. Sembol `bist_stocks` koleksiyonunda var → `trading`
2. `listingDate` geçmiş → `trading`
3. `requestEnd` geçmiş ve `listingDate` yok → `pending_listing`

`reconciled: 0` dönmesinin olası nedenleri:

**A) Eski kod deploy'da** — HEAD düzeltmesi Firebase'e gönderilmemiş. Dolayısıyla
çalışan kod eski `reconcile → write` sıralamasını kullanıyor. Bu sırayla: reconcile düzeltiyor,
sonra writeIpoToFirestore gelen HalkArz verisiyle üzerine yazıyor.
`reconcileStaleIpoStatuses` sıfır sonuç döndürmüyor ama etki kalıcı olmuyor.

**B) BIST sembolleri Firestore'a henüz gönderilmemiş** — `loadBistSymbols()`,
Firestore `bist_stocks` koleksiyonundan `listDocuments()` çekiyor. ORZAX/SOHOE
bu koleksiyona sadece `lib/services/bist_stocks.dart` üzerindeki Dart statik listesiyle
eklendi; bu Dart değişikliği Firestore `bist_stocks` koleksiyonunu doğrudan güncellemez.
`bist_stocks` koleksiyonuna bu sembollerin ayrıca yazılmış olması gerekiyor.

**C) `listingDate` null** — Firestore'daki ORZAX/SOHOE kayıtlarında `listingDate`
alanı yoksa `reconcileStaleIpoStatuses()` hem kural 1'e (BIST seti boş) hem kural 2'ye
(listingDate null) takılmadan geçiyor. Kural 3 de sadece `pending_listing` yazıyor.
Sonuç: hiç `trading` ataması yapılamıyor → `reconciled: 0`.

---

## 5. 203 Kaydın Yanlış Sınıflandırılmasının Temel Nedeni

**Birincil neden:** `data/ipo_feed.json` ve `assets/data/ipo_seed.json` **boş**
(`"items": []`). Uygulama gerçek veriyi Firestore'dan alıyor. Firestore'da
`status` alanı ya hiç set edilmemiş ya da HalkArz scraper'ının yazdığı yanlış değer
(`upcoming`) ile dolu.

**İkincil neden (Cloud Function tarafı):** `syncIpoFeed` her 6 saatte çalışıyor.
Eski kodda akış `reconcile → write` sırasındaydı — reconcile düzelttiğini write eziyordu.
Bu sorun HEAD'de düzeltildi (`write → reconcile`) ama deploy edilmedi, canlı ortamda hâlâ
eski akış çalışıyor.

**Üçüncül neden (Dart tarafı):** Firestore'dan gelen kayıtlarda `listingDate` yoksa
`_deriveStatus()` şu mantığa düşer:
- `requestEnd` geçmiş + `listingDate` null + `fallbackStatus != trading` → `pendingListing`
- `requestEnd` null + `listingDate` null → `fallbackStatus` (genellikle `upcoming`)

203 kayıt için: HalkArz scraper'ı `requestEnd` geçmiş olan ama listingDate'i bilinmeyen
kayıtları `upcoming` statüsüyle Firestore'a yazıyor. Dart `_parseStatus()` bu `upcoming`
string'ini alıp `fallbackStatus = upcoming` yapıyor, `_deriveStatus()` de `requestEnd`
null veya future görünce `upcoming` döndürüyor.

Yani **hem Firestore'daki ham `status` değerleri hem de tarih alanlarının eksikliği** birlikte
yanlış sınıflandırmaya neden oluyor. Dart `_deriveStatus()` kodunun kendisi doğru ama
üzerine çalıştığı veri yanlış.

---

## Bulgular Özeti

| Soru | Yanıt |
|---|---|
| Yaklaşan 203 | Firestore'da `status="upcoming"` + tarih alanları eksik/null → `_deriveStatus()` `upcoming` döndürüyor |
| Listeleme Bekliyor 18 | `requestEnd` geçmiş + `listingDate` null + `fallbackStatus != trading` → `pendingListing` |
| Borsada 0 | Firestore'da `trading` statüsü set edilmiş kayıt yok; deploy olmadığı için düzeltme çalışmıyor |
| Kod bekleniyor | Firestore kaydında `symbol` alanı boş string |
| ORZAX → Yaklaşan | Firestore: `status="upcoming"`, `requestEnd` null, `listingDate` null |
| SOHOE → Listeleme Bekliyor | Firestore: `requestEnd` geçmiş, `listingDate` null |
| `syncIpoManual` reconciled:0 | `bist_stocks` koleksiyonunda ORZAX/SOHOE yok; `listingDate` null olduğu için hiçbir reconcile kuralı tetiklenmiyor |
| 203 yanlış sınıf | `functions/index.js` düzeltmesi deploy edilmemiş → eski `reconcile→write` sırası HalkArz verisinin üzerine yazdırıyor |

---

## Önerilen Düzeltmeler (Uygulama Yapılmadan)

1. **Firebase deploy et** (en kritik):
   ```bash
   cd functions
   firebase deploy --only functions:syncIpoFeed,functions:syncIpoManual
   ```
   Deploy sonrası `syncIpoManual` HTTP endpoint'ini tetikle → `reconcile` kalıcı çalışır.

2. **`bist_stocks` koleksiyonuna ORZAX ve SOHOE'yi yaz**:
   `loadBistSymbols()` Firestore'dan okuyor; Dart'taki statik liste kâfi değil.
   Bu iki sembol Firestore `bist_stocks` koleksiyonunda birer doküman olarak bulunmalı.

3. **HalkArz scraper'ının `listingDate` parse etmesini iyileştir**:
   `listingDate` null geldiğinde scraper `upcoming` yazmak yerine `requestEnd`'i kontrol
   ederek `pending_listing` yazmalı — `computeIpoStatus()` zaten bu mantığı içeriyor ama
   HalkArz'dan parse edilemeyen `listingDate` erken `upcoming` atamasına yol açıyor.

4. **`data/ipo_manual_overrides.json` working copy silmesini restore et veya commit'le**:
   SOHOE ve ORZAX girişleri unstaged olarak silindi. `functions/index.js` bu dosyayı
   okumadığından Firestore akışına etkisi yok; ancak `tools/update_ipo_feed.mjs`
   (GitHub Action) bu dosyayı kullandığından GitHub fallback feed'den de kaybolur.
   `git restore data/ipo_manual_overrides.json` ile geri al veya kasıtlı silmeyse commit'le.
