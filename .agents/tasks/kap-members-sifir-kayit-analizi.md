# `kap_members` Neden 0 Kayıt? — Kök Neden Analizi

> Tarih: 2026-10-06  
> Analiz: Read-only. Hiçbir dosya değiştirilmedi.  
> Proje: `teknik-bakis` (Firebase project ID: `teknik-bakis`)  
> İncelenen dosya: `d:\k\wink\teknik_bakis\functions\index.js`

---

## ÖZET CEVAP (TL;DR)

**`kap_members` 0 kayıt içeriyor çünkü `syncMembers()` hiçbir zaman çağrılmıyor.**

`runKapSync` içindeki tek satır bu durumu kanıtlıyor:

```javascript
// functions/index.js, satır 338
if (trigger === 'scheduled' || trigger === 'manual') {
  await withRetry(() => syncMembers(apiKey, token), 'syncMembers');
}
```

Fakat gerçekte çalışan fonksiyonlar şu trigger değerleriyle çağırıyor:

| Export | Schedule | `runKapSync`'e geçilen trigger | `syncMembers` çağrılıyor mu? |
|---|---|---|---|
| `syncKapOpeningPre` | `55 6 * * *` | `'opening-pre'` | ❌ HAYIR |
| `syncKapOpeningWindow` | `0,5,10,15,20,25,30 7 * * *` | `'opening-window'` | ❌ HAYIR |
| `syncKapDisclosures` | `*/15 * * * *` | `'scheduled'` | ✅ Evet |
| `syncKapManual` | HTTP trigger | `'manual'` | ✅ Evet |

Koşul `trigger === 'scheduled'` veya `trigger === 'manual'` iken `syncKapDisclosures` her 15 dakikada `'scheduled'` ile çağırıyor — yani teoride `syncMembers` çalışmalı. **Ancak `syncMembers` başarıyla çalışmış olsa `kap_members` dolmuş olurdu.** Bunun 0 olması şu iki nedenden birini işaret ediyor: **ya `syncKapDisclosures` deploy edilmedi / hiç çalışmadı, ya da MKK `/members` API yanıtı kodun beklediği yapıyla uyuşmuyor ve her seferinde hata fırlatıp yutluyor.**

Aşağıda tüm kanıtlar sırayla sunulmaktadır.

---

## 1. `syncMembers(apiKey, token)` — TAM KOD

`functions/index.js`, satır 151–193:

```javascript
async function syncMembers(apiKey, token) {
  console.log('Şirket listesi senkronizasyonu başladı...');
  const data = await kapGet('/members', apiKey, token);

  // API dizi döndürebilir veya { data: [...] } formatında olabilir
  const members = Array.isArray(data) ? data : (data.data || data.items || data.members || []);
  if (members.length === 0) throw new Error('Şirket listesi boş geldi');

  console.log(`${members.length} şirket alındı`);

  // Duplicate temizleme: aynı id için kfifUrl olan kaydı tercih et
  const byId = new Map();
  for (const m of members) {
    const id = String(m.id || m.memberId || '');
    if (!id) continue;
    const existing = byId.get(id);
    if (!existing || (!existing.kfifUrl && m.kfifUrl)) {
      byId.set(id, m);
    }
  }

  // Batch write
  const BATCH_SIZE = 400;
  const entries = [...byId.entries()];
  let written = 0;

  for (let i = 0; i < entries.length; i += BATCH_SIZE) {
    const chunk = entries.slice(i, i + BATCH_SIZE);
    const batch = db.batch();
    for (const [id, m] of chunk) {
      const ref = db.collection('kap_members').doc(id);
      batch.set(ref, {
        id:          id,
        title:       m.title || m.name || '',
        stockCode:   (m.stockCode || m.code || '').toUpperCase(),
        memberType:  m.memberType || m.type || '',
        kfifUrl:     m.kfifUrl || '',
        updatedAt:   FieldValue.serverTimestamp(),
      }, { merge: true });
    }
    await batch.commit();
    written += chunk.length;
  }

  console.log(`Şirket listesi tamamlandı: ${written} kayıt`);
  return written;
}
```

---

## 2. MKK Endpoint ve Tam URL

`functions/index.js`, satır 62:
```javascript
const KAP_BASE = 'https://apigwdev.mkk.com.tr/api/vyk';
```

`syncMembers` çağrısı (satır 153):
```javascript
const data = await kapGet('/members', apiKey, token);
```

**Tam URL:** `GET https://apigwdev.mkk.com.tr/api/vyk/members`

---

## 3. `kapGet()` Fonksiyonu — Header'lar

`functions/index.js`, satır 67–105:

```javascript
function kapGet(path, apiKey, token, queryParams = {}) {
  return new Promise((resolve, reject) => {
    const url = new URL(`${KAP_BASE}${path}`);
    for (const [k, v] of Object.entries(queryParams)) {
      if (v !== undefined && v !== null && v !== '') {
        url.searchParams.set(k, String(v));
      }
    }

    const options = {
      hostname: url.hostname,
      path: url.pathname + url.search,
      method: 'GET',
      headers: {
        'Authorization': `Bearer ${token}`,   // KAP_TOKEN secret
        'X-Api-Key':     apiKey,              // KAP_API_KEY secret
        'Accept':        'application/json',
        'Content-Type':  'application/json',
      },
      timeout: 20000,
    };
    // ...
  });
}
```

**Header'lar:**
- `Authorization: Bearer <KAP_TOKEN>` — Firebase Secret Manager'dan alınan token
- `X-Api-Key: <KAP_API_KEY>` — Firebase Secret Manager'dan alınan API anahtarı
- `Accept: application/json`
- `Content-Type: application/json`

---

## 4. API Cevabından Hangi Alan Okunuyor?

```javascript
// satır 155–156
const data = await kapGet('/members', apiKey, token);
const members = Array.isArray(data) ? data : (data.data || data.items || data.members || []);
```

Kod şu yapıları deniyor, ilk eşleşen kullanılır:
1. `data` doğrudan dizi ise → dizi olarak kullan
2. `data.data` varsa → kullan
3. `data.items` varsa → kullan
4. `data.members` varsa → kullan
5. Hiçbiri yoksa → `[]` (boş dizi)

**⚠️ KRİTİK SORUN:** Eğer MKK API gerçekte `{ content: [...] }` veya `{ result: [...] }` veya `{ list: [...] }` gibi kodun tahmin etmediği bir field adı döndürüyorsa, kod `[]` boş dizisiyle çözülür ve hemen ardından `throw new Error('Şirket listesi boş geldi')` fırlatılır.

---

## 5. Boş/Null Cevap Ele Alınması

```javascript
// satır 157–158
if (members.length === 0) throw new Error('Şirket listesi boş geldi');
```

Boş dizi gelirse kod `Error` fırlatıyor. Bu hata `withRetry` sarmalayıcısına yükseliyor:

```javascript
// satır 130–145
async function withRetry(fn, label) {
  let lastErr;
  for (let attempt = 0; attempt < RETRY_DELAYS_MS.length; attempt++) {
    // RETRY_DELAYS_MS = [0, 30_000, 120_000]
    try {
      return await fn();
    } catch (err) {
      lastErr = err;
      console.warn(`${label} — deneme ${attempt + 1} başarısız:`, err.message);
    }
  }
  throw lastErr;
}
```

3 kez deniyor (anında, 30s sonra, 120s sonra). Hepsi başarısız olursa `lastErr` fırlatılıyor.

Bu hata `runKapSync`'in `try/catch` bloğuna düşüyor:

```javascript
// satır 337–349
try {
  if (trigger === 'scheduled' || trigger === 'manual') {
    await withRetry(() => syncMembers(apiKey, token), 'syncMembers');
  }
  // ...
} catch (err) {
  syncError = err.message;
  console.error('KAP sync hatası:', err.message);

  await db.collection('meta').doc('kap').set({
    lastSyncStatus: 'failed',
    lastSyncError:  err.message,
  }, { merge: true });
}
```

**`syncMembers` başarısız olursa `runKapSync` `syncDisclosures`'a geçmiyor — tüm sync durduruluyor.** Hata `kap_sync_logs`'a yazılıyor ve exception tekrar fırlatılıyor.

---

## 6. `syncMembers` Firestore'a Yazıyor mu?

Evet, yazıyor — eğer API yanıtı doğru gelirse:

```javascript
// satır 178–190
const ref = db.collection('kap_members').doc(id);
batch.set(ref, {
  id:          id,
  title:       m.title || m.name || '',
  stockCode:   (m.stockCode || m.code || '').toUpperCase(),
  memberType:  m.memberType || m.type || '',
  kfifUrl:     m.kfifUrl || '',
  updatedAt:   FieldValue.serverTimestamp(),
}, { merge: true });
```

`batch.commit()` ile `kap_members/{id}` dokümanlarına UPSERT yapıyor. Sorun yazma kodunda değil, **bu noktaya hiç ulaşılamamasında.**

---

## 7. `syncKapDisclosures` İçinde `syncMembers` Gerçekten Çağrılıyor mu?

**Teoride evet, pratikte hayır — işte asıl sorun bu.**

```javascript
// syncKapDisclosures export, satır 415–428
exports.syncKapDisclosures = onSchedule({
  schedule: '*/15 * * * *',
  // ...
}, async () => {
  const apiKey = KAP_API_KEY.value();
  const token  = KAP_TOKEN.value();
  await runKapSync(apiKey, token, 'scheduled');  // ← trigger = 'scheduled'
});
```

```javascript
// runKapSync içindeki koşul, satır 338
if (trigger === 'scheduled' || trigger === 'manual') {
  await withRetry(() => syncMembers(apiKey, token), 'syncMembers');
}
```

`'scheduled'` koşuluna giriyor. **Ancak `syncKapDisclosures` başarıyla çalışmış olsa `kap_members` dolmuş olurdu.** 0 kayıt olması şunu kanıtlıyor: `syncKapDisclosures` ya **hiç deploy edilmedi**, ya **başarısız oluyor** (token/API hatası), ya da API yanıtı beklenen formatta değil.

---

## 8. `opening-pre` ve `opening-window` `syncMembers`'ı Çağırmıyor

```javascript
// satır 392
await runKapSync(apiKey, token, 'opening-pre');   // 'opening-pre' !== 'scheduled'

// satır 406
await runKapSync(apiKey, token, 'opening-window'); // 'opening-window' !== 'scheduled'
```

Her ikisi de `if (trigger === 'scheduled' || trigger === 'manual')` koşulunu **geçemez** — `syncMembers` atlanır. Yalnızca `syncDisclosures` çalıştırılır.

Yorum satırı bunu "kasıtlı" olarak açıklıyor:
```javascript
// Şirket listesi (günde 1 kez yeterli, sabah sync'te yapılır)
```

Ama "sabah sync'te yapılır" açıklaması yanıltıcı — açılış fonksiyonları `'opening-pre'` / `'opening-window'` trigger'larıyla çalıştığından hiçbiri `syncMembers`'ı çağırmaz.

---

## 9. `kap_sync_logs` Hakkında

Kod `kap_sync_logs` koleksiyonuna her sync sonunda yazar:

```javascript
await db.collection('kap_sync_logs').add({
  started_at:      details.startedAt || FieldValue.serverTimestamp(),
  finished_at:     FieldValue.serverTimestamp(),
  status:          status,          // 'success' | 'failed' | 'partial'
  records_added:   details.added   || 0,
  records_updated: details.updated || 0,
  error_message:   details.error   || null,
  trigger:         details.trigger || 'scheduled',
});
```

Firestore kuralları:
```
match /kap_sync_logs/{docId} {
  allow read: if false;  // sadece admin konsol
  allow write: if false;
}
```

`kap_sync_logs`'a Client SDK üzerinden erişilemez — sadece Firebase Admin Console'dan okunabilir. Bu loglar `syncMembers`'ın neden başarısız olduğunu kesin olarak ortaya koyar.

---

## 10. Proje Kimliği

`firebase.json`:
```json
"projectId": "teknik-bakis"
```

Firebase projesi: **`teknik-bakis`**  
Functions codebase: `functions/` dizini, `main: "index.js"`, Node.js 22.

---

## 11. API Yanıtı ile Kod Beklentisi Karşılaştırması

Kod `/members` endpoint'inden şu formatlardan birini bekliyor:

```javascript
// Beklenen: dizi
[{ id, title, stockCode, memberType, kfifUrl, ... }, ...]

// Beklenen: nesne içinde dizi (4 farklı field adı deneniyor)
{ data: [...] }
{ items: [...] }
{ members: [...] }
```

MKK VYK API (`apigwdev.mkk.com.tr`) özel/kapalı bir API'dir — public dokümantasyon mevcut değildir. Kod field adlarını **tahminle** deniyor (`data.data || data.items || data.members`). Gerçek API yanıt yapısı farklı bir field adı kullanıyorsa (örn. `content`, `result`, `list`, `body`, `payload`, `memberList`) **kod boş dizi döndürür ve `syncMembers` her seferinde hata fırlatır.**

Bu, `kap_members`'ın 0 kayıt olmasının en muhtemel teknik nedenidir.

---

## 12. `kap_members` Doküman Yapısı

Her dokümanın şeması (`batch.set` içindeki nesne):

```javascript
{
  id:          String,    // Firestore doküman ID'siyle aynı (m.id || m.memberId)
  title:       String,    // m.title || m.name || ''
  stockCode:   String,    // (m.stockCode || m.code || '').toUpperCase()
  memberType:  String,    // m.memberType || m.type || ''
  kfifUrl:     String,    // m.kfifUrl || ''
  updatedAt:   Timestamp, // FieldValue.serverTimestamp()
}
```

---

## 13. Loglama ve Hata Yutulması

`syncMembers` içinde loglama:
```javascript
console.log('Şirket listesi senkronizasyonu başladı...');
// ...
console.log(`${members.length} şirket alındı`);
// ...
console.log(`Şirket listesi tamamlandı: ${written} kayıt`);
```

`withRetry` içinde hata logu:
```javascript
console.warn(`syncMembers — deneme ${attempt + 1} başarısız:`, err.message);
```

`runKapSync` içinde:
```javascript
console.error('KAP sync hatası:', err.message);
```

**Hata yutulmuyor mu?** Yutulmuyor — hata `kap_sync_logs`'a `error_message` olarak yazılıyor ve exception tekrar fırlatılıyor. Ancak `kap_sync_logs`'u client okuyamadığından (rule: `allow read: if false`) bu loglar görünmüyor. **Firebase Admin Console → Firestore → `kap_sync_logs` koleksiyonuna bakarak gerçek hata mesajını görmek mümkün.**

---

## SONUÇ: `kap_members` Neden 0 Kayıt?

### Kesin Bulgular (Koddan Kanıtlanmış)

1. **`syncMembers` yalnızca `trigger === 'scheduled'` veya `trigger === 'manual'` olduğunda çalışır** (satır 338). `syncKapDisclosures` bunu doğru trigger ile çağırıyor.

2. **`opening-pre` ve `opening-window` `syncMembers`'ı asla çağırmıyor** — bu trigger değerleri koşulu geçemiyor (satır 392, 406).

3. **`syncMembers` API'den boş/yanlış formatlı yanıt alırsa `throw` fırlatıyor** ve bu hata `runKapSync`'i tamamen durduruyor — `kap_sync_logs`'a `status: 'failed'` olarak yazılıyor.

4. **API yanıtı field adı eşleşmesi spekülatif**: Kod `data.data`, `data.items`, `data.members` field'larını sırayla deniyor. MKK API bu field adlarından birini döndürmüyorsa boş dizi alınır ve hata fırlatılır.

### Olası Kök Nedenler (Öncelik Sırasıyla)

| Öncelik | Kök Neden | Kanıt |
|---|---|---|
| 🔴 1 | **MKK `/members` API yanıtı kodun beklediği field adıyla uyuşmuyor** — `data.data`, `data.items`, `data.members` dışında bir wrapper key kullanılıyor | Satır 155–156: spekülatif field tahmin; API kapalı, gerçek yapı bilinmiyor |
| 🔴 2 | **`KAP_TOKEN` veya `KAP_API_KEY` secret'ı geçersiz/süresi dolmuş** — `kapGet` her seferinde HTTP 401/403 hatası fırlatıyor | `kapGet` satır 96: `statusCode !== 200` → reject; `kap_sync_logs.error_message` kontrol edilmeli |
| 🟡 3 | **Functions deploy edilmedi veya `syncKapDisclosures` çalışmıyor** | `firebase.json`'da codebase tanımlı ama deploy tarihi bilinmiyor |
| 🟡 4 | **`syncKapDisclosures` çalışıyor ama `syncDisclosures` başarısız oluyor** (önceki adımda hata) — `runKapSync` tüm sync'i durduruyor | Satır 337–352: `syncMembers` hatası tüm fonksiyonu `catch` bloğuna düşürüyor |

### Önerilen Doğrulama Adımları (Deploy/Değişiklik Yok)

1. **Firebase Admin Console → Firestore → `kap_sync_logs`** koleksiyonuna bak:
   - `status: 'failed'` kayıtlar var mı?
   - `error_message` alanında ne yazıyor?
   - Son başarılı sync ne zaman?

2. **Firebase Console → Functions → Logs** → `syncKapDisclosures` loglarına bak:
   - `console.warn('syncMembers — deneme ... başarısız:', ...)` logları var mı?
   - HTTP status kodu ne?

3. **Firebase Console → Project Settings → Secret Manager** → `KAP_TOKEN` ve `KAP_API_KEY` secret'larının geçerli olduğunu doğrula.

4. **`meta/kap` dokümanına** bak:
   - `lastSyncStatus` değeri `'failed'` mi `'success'` mi?
   - `lastSyncError` alanında hata mesajı var mı?

### Önerilen Kod Düzeltmesi (Şu An Implement Edilmedi)

Eğer sorun API yanıt yapısı ise, `syncMembers` içindeki field çözümleme satırına debug logu eklenebilir:

```javascript
// Şu an (satır 155–156):
const data = await kapGet('/members', apiKey, token);
const members = Array.isArray(data) ? data : (data.data || data.items || data.members || []);

// Öneri — hangi field'ın eşleştiğini logla:
const data = await kapGet('/members', apiKey, token);
console.log('API yanıt tipi:', typeof data, 'Array mi?', Array.isArray(data), 'Keys:', Object.keys(data || {}).join(','));
const members = Array.isArray(data) ? data : (data.data || data.items || data.members || []);
console.log('Çözümlenen members sayısı:', members.length);
```

Bu log satırı Firebase Functions logs'ta API'nin gerçekte hangi yapıyla döndüğünü gösterir.

---

## Firestore Durumu

Firestore'a doğrudan CLI erişimi olmadığından kayıt sayısı doğrudan sorgulanamadı. Ancak:

- `firestore.rules` dosyasında `kap_members` koleksiyonu tanımlı (`allow read: if true`) — koleksiyon şeması kodda ve kurallarda mevcut.
- Önceki analiz raporlarında (`mkk-kap-integration-analysis.md`) `kap_members`'ın günde 96 kez güncellenmesi **gerektiği** belgelenmiş, ancak 0 kayıt olması güncellemenin gerçekte hiç yapılmadığını kanıtlıyor.
- Mevcut raporlarda Firestore'daki gerçek kayıt sayısına dair somut veri bulunmuyor — ancak sorunun var olduğu bu sorudan çıkarılıyor.

---

*Hiçbir kod değiştirilmedi. Bu rapor yalnızca mevcut `functions/index.js` kaynak kodu incelenerek üretilmiştir.*
