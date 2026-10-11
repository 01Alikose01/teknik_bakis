# MKK/KAP Entegrasyon Analizi — `functions/index.js`

> Tarih: Analiz otomatik olarak index.js okunarak üretilmiştir.  
> Hiçbir dosya değiştirilmemiştir.

---

## Özet Cevaplar

| # | Soru | Cevap |
|---|------|-------|
| 1 | MKK VYK API hangi function? | `syncMembers` ve `syncDisclosures` (dahili helper'lar); bunları çağıran export'lar: `syncKapOpeningPre`, `syncKapOpeningWindow`, `syncKapDisclosures`, `syncKapManual` |
| 2 | Tam endpoint URL | `https://apigwdev.mkk.com.tr/api/vyk` + path |
| 3 | Authentication | `Authorization: Bearer <token>` + `X-Api-Key: <apiKey>` |
| 4 | `kap_members` oluşturan/güncelleyen function | `syncMembers(apiKey, token)` — her sync çalışmasında çağrılır |
| 5 | `kap_members` alan adları | Aşağıda tam şema |
| 6 | `stockCode != ''` filtresi var mı? | **Evet**, satır 2303–2307'de `where('stockCode', '==', symbol)` kullanılıyor |
| 7 | Maksimum kayıt / limit parametresi | Kodda limit parametresi yok; API'nin döndürdüğü tüm kayıtlar alınıyor |
| 8 | Pagination | Yoktur — tek istek, tüm liste |
| 9 | Rate limit / delay | syncMembers/syncDisclosures'da yok; IPO scraper'ında 400ms delay var (ilgisiz) |
| 10 | `kap_members` güncelleme sıklığı | Her `syncKapDisclosures` çalışmasında (15 dk'da bir, günde 96x) + açılış penceresi (5 dk'da bir); `syncMembers` `trigger === 'scheduled' || 'manual'` olduğunda çağrılır |

---

## Detaylı Bulgular

### 1. MKK VYK API'yi Kullanan Function'lar

MKK VYK API doğrudan iki dahili helper tarafından kullanılır:

- **`syncMembers(apiKey, token)`** (satır ~151–193): `/members` endpoint'ini çağırır.
- **`syncDisclosures(apiKey, token)`** (satır ~206–300): `/lastDisclosureIndex` ve `/disclosures` endpoint'lerini çağırır.

Bu iki helper, **`runKapSync(apiKey, token, trigger)`** (satır ~311–360) tarafından orchestrate edilir.

`runKapSync`'i çağıran export'lar:
```
exports.syncKapOpeningPre      — cron: '55 6 * * *'
exports.syncKapOpeningWindow   — cron: '0,5,10,15,20,25,30 7 * * *'
exports.syncKapDisclosures     — cron: '*/15 * * * *'
exports.syncKapManual          — onRequest (X-Admin-Secret korumalı)
```

---

### 2. Tam Endpoint URL'leri

Base URL (satır 62):
```
const KAP_BASE = 'https://apigwdev.mkk.com.tr/api/vyk';
```

Kullanılan path'ler:
- `/members` → `GET https://apigwdev.mkk.com.tr/api/vyk/members`
- `/lastDisclosureIndex` → `GET https://apigwdev.mkk.com.tr/api/vyk/lastDisclosureIndex`
- `/disclosures` → `GET https://apigwdev.mkk.com.tr/api/vyk/disclosures?disclosureIndex=<N>`

---

### 3. Authentication / Header Yapısı

`kapGet(path, apiKey, token, queryParams)` fonksiyonu (satır ~67–105):

```javascript
headers: {
  'Authorization': `Bearer ${token}`,   // KAP_TOKEN secret
  'X-Api-Key':     apiKey,              // KAP_API_KEY secret
  'Accept':        'application/json',
  'Content-Type':  'application/json',
}
```

Secret tanımları (satır ~57–60):
```javascript
const KAP_API_KEY  = defineSecret('KAP_API_KEY');   // Firebase Secret Manager
const KAP_TOKEN    = defineSecret('KAP_TOKEN');      // Firebase Secret Manager
```

---

### 4. `kap_members` Koleksiyonunu Oluşturan/Güncelleyen Function

**`syncMembers(apiKey, token)`** (satır ~151–193).

Firestore'a yazdığı nokta (satır ~179–189):
```javascript
const ref = db.collection('kap_members').doc(id);
batch.set(ref, { ... }, { merge: true });  // UPSERT
```

`runKapSync` içinde çağrılma koşulu (satır ~325):
```javascript
if (trigger === 'scheduled' || trigger === 'manual') {
  await withRetry(() => syncMembers(apiKey, token), 'syncMembers');
}
```

`opening-pre` ve `opening-window` trigger'ları `syncMembers`'ı da çağırır (ikisi de `runKapSync` üzerinden geçer).  
`syncKapDisclosures` ise `trigger = 'scheduled'` ile çağırdığından o da `syncMembers`'ı tetikler.  
Sonuç: **kap_members her 15 dakikada bir güncellenir** (günde 96 kez).

---

### 5. `kap_members` Doküman Şeması (Tam Alan Adları)

Satır 181–188, `batch.set` içindeki nesne:

```javascript
{
  id:          id,                                          // String  — Firestore doküman ID'siyle aynı
  title:       m.title || m.name || '',                    // String  — Şirket adı
  stockCode:   (m.stockCode || m.code || '').toUpperCase(),// String  — BIST sembolü (büyük harf)
  memberType:  m.memberType || m.type || '',               // String  — Üye tipi
  kfifUrl:     m.kfifUrl || '',                            // String  — KFIF URL
  updatedAt:   FieldValue.serverTimestamp(),               // Timestamp
}
```

**Kritik alan adları:**
- `stockCode` → MKK API'deki `m.stockCode` veya `m.code` değerinden `.toUpperCase()` ile yazılır
- `title` → MKK API'deki `m.title` veya `m.name`
- `symbol` alanı **yoktur** — sembol için `stockCode` kullanılır

> ⚠️ `symbol` isimli bir alan `kap_members`'da **hiç bulunmamaktadır**. Firestore'da sembol için alan adı `stockCode`'dur.

---

### 6. `stockCode != ''` Filtresi

`kap_members`'da `stockCode != ''` şeklinde bir Firestore where clause **yoktur**.

Ancak aynı koleksiyona **farklı bir yerde** `where` sorgusu yapılmaktadır (satır 2303–2307, `runBist100Sync` içindeki `syncBist100Stocks` bölümü):

```javascript
const kapSnap = await db.collection('kap_members')
  .where('stockCode', '==', symbol)
  .limit(1)
  .get();
```

Bu sorgu `stockCode != ''` değil, `stockCode == <belirli sembol>` şeklindedir. Boş stockCode filtresi mevcut kodda yer almaz.

`syncMembers` içinde ise client-side basit bir boş `id` kontrolü vardır:
```javascript
const id = String(m.id || m.memberId || '');
if (!id) continue;  // ID yoksa atla
```
`stockCode` için boşluk kontrolü yapılmamaktadır.

---

### 7. Maksimum Kayıt / Limit Parametresi

`/members` çağrısı (satır ~153):
```javascript
const data = await kapGet('/members', apiKey, token);
```
Hiçbir `limit`, `size`, `pageSize` parametresi gönderilmemektedir. API'nin döndürdüğü **tüm kayıtlar tek seferde** alınır.

---

### 8. Pagination

`/members` endpoint'i için pagination **yoktur**.

`/disclosures` için kısmi bir mekanizma vardır: `disclosureIndex` query parametresi ile son bilinen index'ten sonrasını ister (satır ~252–255):
```javascript
const queryParams = {
  disclosureIndex: lastIndex > 0 ? lastIndex : undefined,
};
const data = await kapGet('/disclosures', apiKey, token, queryParams);
```

Bu cursor tabanlıdır (offset/page değil), sadece `disclosures` için geçerlidir, `members` için yoktur.

---

### 9. Rate Limit / Throttle / Delay

**KAP/MKK API istekleri için hiçbir delay veya throttle kodu yoktur.**

- `syncMembers`: doğrudan tek istek, bekleme yok
- `syncDisclosures`: doğrudan iki istek (`lastDisclosureIndex` + `disclosures`), bekleme yok
- Retry mekanizması (satır ~130–145): 3 deneme, aralarında 0s / 30s / 120s — bu throttle değil, hata recovery

Not: IPO (HalkArz) scraper'ında `await new Promise(r => setTimeout(r, 400))` vardır (satır ~935), ancak bu MKK API ile ilgisizdir.

---

### 10. `kap_members` Güncelleme Sıklığı

Cron schedule'lara göre:

| Export | Schedule | TR Saati | Sıklık |
|--------|----------|----------|--------|
| `syncKapOpeningPre` | `55 6 * * *` | 09:55 | Günde 1x |
| `syncKapOpeningWindow` | `0,5,10,15,20,25,30 7 * * *` | 10:00–10:30 | Günde 7x |
| `syncKapDisclosures` | `*/15 * * * *` | Sürekli | Günde 96x |
| `syncKapManual` | Manuel tetikleme | — | Değişken |

`syncMembers` her `scheduled` ve `manual` trigger'da çağrıldığından **günde en az 104 kez** çalışır (96 + 7 + 1). Pratikte `syncKapDisclosures` baskın: **her 15 dakikada bir**.

---

## Yeni `syncBistStocksFull` İçin Kullanılabilecek Helper'lar ve Pattern'lar

### Doğrudan Yeniden Kullanılabilir

| Helper / Pattern | Nerede | Açıklama |
|-----------------|--------|----------|
| `kapGet(path, apiKey, token, queryParams)` | satır 67–105 | MKK API'ye kimlik doğrulamalı GET. Sadece path ve params değiştirilerek başka endpoint'ler için kullanılabilir. |
| `withRetry(fn, label)` | satır 130–145 | 3-deneme, exponential-like delay (0 / 30s / 120s). Her async fonksiyon için sarmalayıcı olarak çalışır. |
| Batch write pattern | satır ~172–192 | `BATCH_SIZE = 400`, `db.batch()`, `batch.set(..., { merge: true })`, `batch.commit()` — UPSERT pattern'ı. Aynen kopyalanabilir. |
| Secret okuma pattern | satır ~57–60, 416–417 | `defineSecret(...)`, `.value()` çağrısı, function tanımında `secrets: [...]` |
| `writeSyncLog(status, details)` | satır ~307–320 | `kap_sync_logs` koleksiyonuna standart log yazar. `syncBistStocksFull` da aynı log koleksiyonuna yazabilir. |
| Error handling pattern | satır ~325–358 | try/catch içinde `syncError`, meta dokümanına `lastSyncStatus` yazma, hata olunca `throw` |

### Uyarlanabilir Pattern'lar

| Pattern | Nerede | Uyarlama notu |
|---------|--------|---------------|
| `syncMembers` genel yapısı | satır 151–193 | `/members` yerine `/stocks` veya tam liste endpoint'i çağrılabilir. Duplicate temizleme (`byId Map`) ve batch write mantığı aynı kalabilir. |
| `runKapSync` orchestration | satır 311–360 | `runBistStocksSync` olarak klonlanabilir; `syncMembers` yerine `syncBistStocksFull` helper'ı çağırır. |
| Güncelleme sıklığı meta | satır ~337–344 | `meta/kap` dokümanına `lastSuccessfulSync`, `lastSyncStatus` yazmak. `meta/bist_stocks` olarak yeni bir meta doküman oluşturulabilir. |
| `onSchedule` export | satır ~375–430 | `region`, `memory`, `timeoutSeconds`, `secrets` konfigürasyonu template olarak kullanılabilir. |

### `kapGet` Kullanım Örneği (Yeni Endpoint için)

```javascript
// Tam hisse listesi için varsayımsal kullanım
const data = await kapGet('/stocks', apiKey, token, { market: 'BIST' });
// veya
const data = await kapGet('/members', apiKey, token, { type: 'stock', includeDelisted: false });
```

API'nin hangi endpoint'i döndürdüğüne bağlı olarak field mapping değişir; mevcut `stockCode || m.code` fallback pattern'ı burada da geçerlidir.

---

## Öneriler (Implement Edilmedi)

1. **`symbol` vs `stockCode` tutarsızlığı**: `kap_members`'da alan adı `stockCode`; ancak `kap_disclosures`'da benzer alan `stock_code` (alt çizgili) olarak saklanıyor. `syncBistStocksFull` yazılırken hangi koleksiyonla eşleşme yapılacaksa field adı buna göre seçilmeli.

2. **Boş stockCode filtresi eksik**: `syncMembers` şu anda boş `stockCode` değeri olan kayıtları Firestore'a yazıyor (sadece `id` boşluğu kontrol ediliyor). `syncBistStocksFull` sadece gerçek hisseleri hedefliyorsa `if (!stockCode) continue;` eklenmeli.

3. **`/members` tek istek**: Üye sayısı artarsa (şu an bilinmiyor) tek istekte limit aşılabilir. `syncBistStocksFull` cursor/pagination destekleyecekse `kapGet`'e `page` parametresi eklenmeli veya API dokümantasyonu kontrol edilmeli.

4. **Rate limit yok**: MKK API'nin rate limit politikası dokümantasyonda belirtilmemiş; `syncBistStocksFull` paralel istek yapacaksa dikkatli olunmalı.
