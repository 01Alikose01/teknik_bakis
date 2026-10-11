# Otomatik Güncelleme — Uygulama Planı

**Tarih:** 2026-10-10  
**Kapsam:** `functions/index.js` dosyasına iki yeni Cloud Function grubu eklenir. Mevcut fonksiyonlara ve Flutter/Dart dosyalarına dokunulmaz.

---

## Mevcut Veri Kaynakları Envanteri

| Kaynak | URL / Mekanizma | Mevcut Kullanım |
|---|---|---|
| HalkArz.com | `https://halkarz.com/` HTML scraping | `syncIpoFeed` (her 6 saatte) — IPO listesi |
| MKK VYK API | `https://apigwdev.mkk.com.tr/api/vyk/members` | `syncMembers()` — `kap_members` koleksiyonu (günde birkaç kez) |
| Borsa İstanbul duyuruları | `https://www.borsaistanbul.com/en/announcement` HTML | `syncBist100Index` (haftalık) — BIST100 delta |
| bilancoveri.com | `https://bilancoveri.com/api/v1/sirketler.json` | `updateFundamentals` (temel göstergeler) |
| Firestore `kap_members` | İç koleksiyon — `title` ve `stockCode` alanları | `syncBist100Index` içinde ad araması |
| Firestore `bist_stocks` | İç koleksiyon — ~100 BIST100 sembolü (eksik dolu) | `loadBistSymbols()` — IPO trading kararı |
| Firestore `bist_index_meta/bist100` | İç doküman — 100 sembol listesi + meta | `Bist100Service` (Flutter okuma) |

**Kritik mimari not:**  
`bist_stocks` koleksiyonu tasarım olarak tüm BIST hisselerini hedefliyor ama yalnızca BIST100 bootstrap'ından ~100 sembol içeriyor. `loadBistSymbols()` bu koleksiyondan okuyor; dolayısıyla IPO trading kararı fiilen sadece BIST100 sembolleriyle sınırlı.

---

## Görev 1 — Kapanan / İsim Değişen Şirketler

### Problem analizi

HalkArz.com scraper her çalıştığında tüm IPO kayıtlarını çekip `ipo_items` koleksiyonuna yazıyor. Kapanan bir şirket HalkArz listesinden düşerse Firestore'da `status: 'trading'` olarak kalıyor. İsim değişikliği ise HalkArz'da görünmüyor çünkü scraper halka arz sürecindeki şirketlere bakıyor.

**Gerçek sorun:** `bist_stocks` koleksiyonundaki şirket kayıtlarında:
- Kapanan/delisteden şirketler `active: true` olarak kalmaya devam ediyor.
- Sembol/unvan değişikliği olan şirketlerin `name` alanı güncellenmemektedir.

**Çözüm kaynağı:** `kap_members` koleksiyonu zaten `syncMembers()` ile güncelleniyor. `kap_members.title` = güncel unvan, `kap_members.stockCode` = güncel sembol. Bu iki alan karşılaştırılarak değişiklikler tespit edilebilir.

**Delisting tespiti:** `bist_stocks` koleksiyonunda bir sembol varken `kap_members`'da artık o `stockCode`'a sahip kayıt yoksa ya sembol değişmiştir ya da şirket KAP üyeliğini kaybetmiştir. Kesin delisting tespiti için Yahoo Finance `${symbol}.IS` isteği kullanılabilir: 404 veya `regularMarketPrice: null` dönerse şirket aktif olarak işlem görmüyor demektir.

**Tasarım kararı:** Yeni bir bağımsız function yerine `syncIpoFeed` scheduler ile aynı ritimde (veya biraz daha seyrek) çalışacak `syncBistStocksMeta` adında ayrı bir function. Bu function:
1. `kap_members` koleksiyonunu okuyarak tüm `stockCode → title` eşlemesini yükler.
2. `bist_stocks` koleksiyonundaki aktif kayıtlarla karşılaştırır.
3. `kap_members`'da artık bulunmayan semboller için Yahoo Finance doğrulaması yapar; işlem göremiyorsa `active: false` yazar.
4. `kap_members.title` ile `bist_stocks.name` farklıysa `name` alanını günceller.
5. `kap_members`'da yeni `stockCode != ''` kayıtları varsa ve `bist_stocks`'ta yoksa ekler (`active: true`).

---

## Görev 2 — BIST100 Listesi Otomatik Güncelleme

### Durum analizi

`syncBist100Index` (haftalık, Her Pazartesi 05:00 UTC) ve `syncBist100Manual` (HTTP endpoint) `functions/index.js` içinde zaten **implement edilmiş durumda** (satır 2379–2507). Bu fonksiyonlar:
- `borsaistanbul.com/en/announcement` sayfasını tarar
- `bist-stock-indices-periodic-review` veya `announces-constituent-changes-bist-stock-indices` slug'lı en yeni duyuruyu bulur
- HTML parse ederek `added` / `removed` semboller çıkarır
- `bist_index_meta/bist100` dokümanına yazar
- `bist_stocks` koleksiyonundaki `bist100Member` alanını günceller

**Görev 2 için yapılacak tek şey:** Bu fonksiyonlar deploy edilmiş ama `bist_stocks` koleksiyonu yalnızca bootstrap ile yazılmış ~100 sembol içeriyor. `syncBistStocksMeta` (Görev 1) tüm listeyi doldurduğunda BIST100 sistemi de tam çalışacak.

Bununla birlikte, `bist_stocks` koleksiyonuna tüm KAP üyelerini ilk kez yükleyen bir **tek seferlik bootstrap** fonksiyonu da gerekiyor.

---

## Uygulama Adımları

---

- [ ] 1. **`syncBistStocksMeta` için yardımcı fonksiyon: `fetchYahooStatus(symbol)`**

  Yahoo Finance `v8/finance/chart` endpoint'ini kullanarak bir sembolün aktif işlem görüp görmediğini kontrol eder. `${symbol}.IS` formatıyla istek atar. HTTP 200 + geçerli `regularMarketPrice` döndürürse `true`, 404 veya hata alırsa `false` döndürür. Timeout: 10 saniye. Fırlatma yapmaz — hata durumunda `null` döner (belirsiz → dokunma).

  ```js
  async function fetchYahooStatus(symbol) {
    // returns true (aktif), false (pasif/delisted), null (hata/belirsiz)
  }
  ```

  Dosya: `functions/index.js` (sonuna ekle)  
  Doğrulama: `node --check functions/index.js` — çıktı hata içermemeli.

---

- [ ] 2. **`syncBistStocksMeta` için yardımcı fonksiyon: `buildKapSymbolMap()`**

  Firestore `kap_members` koleksiyonunun tamamını tek bir `get()` ile çeker. `stockCode != ''` olan kayıtlar için `{ stockCode → title }` haritası döndürür. Hem yeni ekleme tespiti hem de unvan değişikliği tespiti için kullanılır.

  ```js
  async function buildKapSymbolMap() {
    // returns Map<string, string>: stockCode.toUpperCase() → title
  }
  ```

  Dosya: `functions/index.js` (sonuna ekle)  
  Doğrulama: `node --check functions/index.js` — çıktı hata içermemeli.

---

- [ ] 3. **`runBistStocksMetaSync(options)` core logic fonksiyonu**

  Tüm `bist_stocks` metasını senkronize eden ana fonksiyon. `dryRun` parametresi destekler.

  **A. `kap_members` → sembol haritası yükle** (`buildKapSymbolMap()`)

  **B. `bist_stocks` tümünü oku** (`db.collection('bist_stocks').get()`) — `active` durumundan bağımsız tümünü al (pasif olanları da kontrol etmek için).

  **C. Üç kontrol:**

  **C-1. Yeni sembol tespiti (ekle):**  
  `kap_members`'da olan ama `bist_stocks`'ta olmayan `stockCode` değerleri. Bunlar için `{ symbol, name: kap_members.title, active: true }` yazılır. Batch boyutu 400'ü aşarsa yeni batch açılır.

  **C-2. Unvan değişikliği tespiti (güncelle):**  
  `bist_stocks`'ta olan ve `active: true` olan bir sembolün `name` alanı, `kap_members.title`'dan farklıysa `name` alanı güncellenir. `active` alanına ASLA dokunulmaz.

  **C-3. Delisting tespiti (pasifleştir):**  
  `bist_stocks`'ta `active: true` olan ama `kap_members`'da artık `stockCode`'u bulunmayan semboller için Yahoo Finance doğrulaması çalıştır (`fetchYahooStatus(symbol)`):
  - `false` dönerse → `active: false` + `delistedAt: Timestamp` + `delistReason: 'kap_not_found'`
  - `true` dönerse → dokunma (KAP'ta sembol değişmiş olabilir; veri tutarsızlığı)
  - `null` dönerse → dokunma (belirsiz durum)

  **D. Log ve dön:**
  ```
  BIST_STOCKS_SYNC: added=N, nameUpdated=N, delisted=N
  ```

  Return: `{ status: 'completed', added, nameUpdated, delisted }`

  Dosya: `functions/index.js` (sonuna ekle)  
  Doğrulama: `node --check functions/index.js` — çıktı hata içermemeli.

---

- [ ] 4. **`exports.syncBistStocksMeta` ve `exports.syncBistStocksManual` export ekle**

  **syncBistStocksMeta** — Haftalık scheduler:
  ```js
  exports.syncBistStocksMeta = onSchedule({
    schedule:       '0 3 * * 3',   // Her Çarşamba 03:00 UTC (06:00 TR)
    timeZone:       'UTC',
    region:         'europe-west1',
    memory:         '512MiB',
    timeoutSeconds: 300,
  }, async () => {
    await runBistStocksMetaSync({ dryRun: false });
  });
  ```
  Zamanlamanın `syncBist100Index` (Pazartesi 05:00) ile çakışmaması için Çarşamba seçildi. `bist_stocks` koleksiyonu BIST100 sync'inden iki gün sonra güncellenir — bu sıralama kasıtlı.

  **syncBistStocksManual** — Admin korumalı HTTP endpoint:
  ```js
  exports.syncBistStocksManual = onRequest({
    region:         'europe-west1',
    memory:         '512MiB',
    timeoutSeconds: 300,
    secrets:        [ADMIN_SECRET],
  }, async (req, res) => {
    // ADMIN_SECRET doğrulama (mevcut pattern)
    // ?dryRun=true destekli
    // ?bootstrap=true: kap_members'daki tüm stockCode != '' kayıtlarını
    //   bist_stocks'a yazar (active: true). Sadece Firestore boşken çalışır.
  });
  ```

  Bootstrap modu detayı: `bist_stocks` koleksiyonunda `≥ 500` doküman varsa 409 döner. Aksi halde `kap_members`'daki tüm `stockCode != ''` kayıtlar için `{ symbol, name, active: true }` yazar. Her batch 400 limit. Mevcut `syncBist100Manual?bootstrap=true` patternine birebir uyar.

  Dosya: `functions/index.js` (sonuna ekle)  
  Doğrulama: `node --check functions/index.js` — çıktı hata içermemeli.  
  Deploy: `firebase deploy --only functions:syncBistStocksMeta,functions:syncBistStocksManual`

---

- [ ] 5. **Bootstrap: `kap_members`'dan tüm BIST hisselerini `bist_stocks`'a yükle**

  Deploy sonrası tek seferlik bootstrap çalıştırılır:
  ```bash
  curl "https://europe-west1-<PROJECT_ID>.cloudfunctions.net/syncBistStocksManual?bootstrap=true&dryRun=true&secret=<ADMIN_SECRET>"
  # Dry run çıktısını kontrol et (sembol sayısı ~600+ olmalı)
  
  curl "https://europe-west1-<PROJECT_ID>.cloudfunctions.net/syncBistStocksManual?bootstrap=true&secret=<ADMIN_SECRET>"
  # Gerçek yazma
  ```

  Bu adım `bist_stocks` koleksiyonunu ~600 sembolle doldurur. Bunun ardından:
  - `loadBistSymbols()` artık tüm BIST sembollerini döndürür
  - `syncIpoFeed`'deki `computeIpoStatus()` BIST100 dışı IPO'ları da `trading` olarak işaretleyebilir (SOHOE, ORZAX gibi)
  - `syncBist100Index` BIST100 üyeliğini `bist_index_meta/bist100` koleksiyonunda güncellemeye devam eder

  Bu uygulama adımı; deploy adımının tamamlanmış olmasına bağımlıdır (Adım 4).  
  Doğrulama: Firebase Console → `bist_stocks` koleksiyonunda doküman sayısı ≥ 500 olmalı.

---

## Mevcut Fonksiyonlara Dokunulmayan Noktalar

| Fonksiyon | Satır | Durum |
|---|---|---|
| `syncKapOpeningPre` | 396 | Dokunulmaz |
| `syncKapOpeningWindow` | 410 | Dokunulmaz |
| `syncKapDisclosures` | 431 | Dokunulmaz |
| `syncKapManual` | 448 | Dokunulmaz |
| `updateFundamentals` | 519 | Dokunulmaz |
| `updateFundamentalsManual` | 538 | Dokunulmaz |
| `syncIpoFeed` | 1145 | Dokunulmaz — bootstrap sonrası daha doğru çalışacak |
| `syncIpoManual` | 1171 | Dokunulmaz |
| `getTeknikAnaliz` | 1510 | Dokunulmaz |
| `cleanAiCache` | 1582 | Dokunulmaz |
| `verifySubscription` | 1787 | Dokunulmaz |
| `onPurchaseWritten` | 1824 | Dokunulmaz |
| `syncBist100Index` | 2379 | Dokunulmaz — zaten implement edilmiş, çalışıyor |
| `syncBist100Manual` | 2399 | Dokunulmaz — zaten implement edilmiş, çalışıyor |

---

## Her Fonksiyon için Tam Özet

### `syncBistStocksMeta`
- **Dosya:** `functions/index.js`
- **Fonksiyon adı:** `exports.syncBistStocksMeta`
- **Schedule (cron):** `0 3 * * 3` — Her Çarşamba 03:00 UTC
- **Region:** `europe-west1`, Memory: `512MiB`, Timeout: `300s`
- **Firestore yazma mantığı:**
  - `bist_stocks/{YENİ_SEMBOL}` → `{ symbol, name, active: true }` (merge: false, yeni belge)
  - `bist_stocks/{MEVCUT}` → `{ name: <yeni_ad> }` (merge: true, sadece name)
  - `bist_stocks/{DELISTED}` → `{ active: false, delistedAt, delistReason }` (merge: true)
  - `active` alanına hiçbir koşulda dokunulmaz (ekleme hariç)
- **Hata yönetimi:**
  - `buildKapSymbolMap()` başarısız olursa → throw (retry mekanizması scheduler tarafından)
  - Tek bir sembol için Yahoo Finance hatası → `null` döner, o sembol atlanır
  - Batch hataları → log + throw

### `syncBistStocksManual`
- **Dosya:** `functions/index.js`
- **Fonksiyon adı:** `exports.syncBistStocksManual`
- **Tip:** HTTP GET/POST (`onRequest`)
- **Auth:** `x-admin-secret` header veya `?secret=` query param
- **Modlar:** `?dryRun=true`, `?bootstrap=true`
- **Schedule:** Yok — elle tetiklenir

---

## Firestore Etki Analizi

```
bist_stocks/{SEMBOL}
  Yeni alan:    delistedAt: Timestamp   (sadece active: false yapılanlarda)
  Yeni alan:    delistReason: string    ('kap_not_found')
  Güncellenen:  name: string            (unvan değişikliğinde)
  Güncellenen:  active: false           (delisted tespitinde)
  Yeni belge:   symbol, name, active    (yeni listelenen semboller)
```

Flutter `bist100_service.dart` `.where('active', isNotEqualTo: false)` filtresiyle okuyor. `delistedAt` ve `delistReason` alanları Flutter tarafından okunmuyor — backend audit için ekstra alan olarak güvenli.

---

## Deploy ve Test Sırası

```
1. node --check functions/index.js          ← syntax doğrulama
2. firebase deploy --only functions:syncBistStocksMeta,functions:syncBistStocksManual
3. syncBistStocksManual?bootstrap=true&dryRun=true   ← dry run, sembol sayısını kontrol
4. syncBistStocksManual?bootstrap=true               ← gerçek bootstrap (~600 sembol)
5. syncBistStocksManual?dryRun=true                  ← haftalık sync'i test et
6. Firebase Console → bist_stocks sayımı ≥ 500 olmalı
```

---

## Log Referansı

| Log | Anlamı |
|---|---|
| `BIST_STOCKS_SYNC_STARTED` | Fonksiyon başladı |
| `BIST_STOCKS_KAP_MAP: N sembol` | kap_members haritası yüklendi |
| `BIST_STOCKS_NEW: SEMBOL` | Yeni sembol ekleniyor |
| `BIST_STOCKS_NAME_UPDATED: SEMBOL` | Unvan güncelleniyor |
| `BIST_STOCKS_YAHOO_CHECK: SEMBOL false` | Yahoo delisting doğruladı |
| `BIST_STOCKS_DELISTED: SEMBOL` | Sembol aktif: false yapıldı |
| `BIST_STOCKS_SYNC: added=N, nameUpdated=N, delisted=N` | Tamamlandı |
| `BIST_STOCKS_BOOTSTRAP_COMPLETE: N symbols` | Bootstrap tamamlandı |
