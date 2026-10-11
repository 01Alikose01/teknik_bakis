# syncBist100Manual — Endpoint Analiz Raporu

**Tarih:** 2026  
**Kapsam:** Read-only araştırma — hiçbir dosya değiştirilmedi, deploy yapılmadı.  
**Kaynak dosya:** `functions/index.js` (satır 2385–2505)

---

## ÖZET — Hemen Çalıştırılacak Komut

### Seçenek A: Normal senkronizasyon (bist_stocks boş değilse)

```powershell
curl.exe -X GET `
  "https://europe-west1-teknik-bakis.cloudfunctions.net/syncBist100Manual?secret=BURAYA_ADMIN_SECRET_DEGERI&dryRun=true"
```

> `dryRun=true` → Firestore'a **yazmaz**, sadece ne yapacağını raporlar. İlk testte her zaman bununla başlayın.
> Gerçek yazma için `dryRun` parametresini kaldırın ya da `dryRun=false` yapın.

---

### Seçenek B: Bootstrap modu — `bist_stocks` koleksiyonunu İLK KEZ doldurmak için

Kullanıcı mesajında istenen durum budur. Endpoint'in **bootstrap modu** tam olarak bunu yapar:
`bist_index_meta/bist100` dokümanına **100 sembollük sabit liste** yazar VE `bist_stocks/{SYMBOL}` dokümanlarında `bist100Member: true` alanını günceller.

```powershell
curl.exe -X GET `
  "https://europe-west1-teknik-bakis.cloudfunctions.net/syncBist100Manual?secret=BURAYA_ADMIN_SECRET_DEGERI&bootstrap=true&dryRun=true"
```

> Bootstrap + dryRun kombinasyonu: Ne yazılacağını gösterir, gerçek yazma yapmaz.  
> Gerçek bootstrap için:

```powershell
curl.exe -X GET `
  "https://europe-west1-teknik-bakis.cloudfunctions.net/syncBist100Manual?secret=BURAYA_ADMIN_SECRET_DEGERI&bootstrap=true"
```

---

## ADMIN_SECRET Değeri Nereden Alınır?

Secret, Firebase Secret Manager'da `ADMIN_SECRET` adıyla saklı. Değeri şu komutla alınabilir:

```powershell
# (kendi terminalinizde, gcloud auth login sonrası)
gcloud secrets versions access latest --secret="ADMIN_SECRET" --project="teknik-bakis"
```

Veya Firebase Console → Project Settings → Secret Manager → `ADMIN_SECRET` → Ver.

---

## Detaylı Bulgular

### 1. Endpoint Tanımı

**Dosya:** `functions/index.js`, satır 2385  
**Export adı:** `exports.syncBist100Manual`  
**Tip:** Firebase Functions v2 `onRequest` (HTTP tetikleyici)

```javascript
exports.syncBist100Manual = onRequest({
  region:         'europe-west1',
  memory:         '512MiB',
  timeoutSeconds: 300,
  secrets:        [ADMIN_SECRET],
}, async (req, res) => { ... });
```

---

### 2. Tam URL

Firebase Functions v2 HTTP endpoint'leri şu URL deseni ile yayınlanır:

```
https://{REGION}-{PROJECT_ID}.cloudfunctions.net/{FUNCTION_NAME}
```

Değerler:
- **Region:** `europe-west1` (index.js satır 2387)
- **Project ID:** `teknik-bakis` (`.firebaserc` dosyası, `projects.default`)
- **Function name:** `syncBist100Manual`

**Tam URL:**
```
https://europe-west1-teknik-bakis.cloudfunctions.net/syncBist100Manual
```

---

### 3. HTTP Method

Endpoint `onRequest` ile tanımlı — hem GET hem POST kabul eder. Parametreler **query string** üzerinden geçildiğinden **GET** kullanımı daha pratiktir. Kod içindeki yorum da bunu teyit eder:

```javascript
// Kullanım: GET/POST ?secret=<ADMIN_SECRET>[&dryRun=true]
// (index.js satır 2382)
```

---

### 4. Gerekli Header

**Zorunlu header YOK.** Kimlik doğrulama query string üzerinden yapılıyor:

```javascript
const provided = (
  (req.headers['x-admin-secret'] || '') ||
  (req.query.secret || '')
).trim();
// (index.js satır 2394–2397)
```

İki yol kabul ediliyor — ikisi de yeterli, ikisi birden gerekmez:

| Yöntem | Parametre Adı | Örnek |
|---|---|---|
| Query string | `?secret=...` | `?secret=abc123` |
| HTTP Header | `x-admin-secret: ...` | `-H "x-admin-secret: abc123"` |

**Öneri:** curl ile query string daha basit. Header kullanmak istiyorsanız:

```powershell
curl.exe -X GET `
  -H "x-admin-secret: BURAYA_ADMIN_SECRET_DEGERI" `
  "https://europe-west1-teknik-bakis.cloudfunctions.net/syncBist100Manual?dryRun=true"
```

---

### 5. Query Parametreleri

| Parametre | Zorunlu | Değerler | Açıklama |
|---|---|---|---|
| `secret` | **EVET** (header yoksa) | `<ADMIN_SECRET değeri>` | Admin kimlik doğrulama |
| `dryRun` | Hayır | `true` / `1` | Firestore'a yazmadan simüle eder |
| `bootstrap` | Hayır | `true` / `1` | **bist_stocks'u ilk kez doldurmak için** bu kullanılır |

---

### 6. ADMIN_SECRET Kullanımı

**Zorunludur.** Doğru secret verilmezse endpoint `403 Unauthorized` döner.

```javascript
const adminSecret = ADMIN_SECRET.value().trim();
const provided    = (
  (req.headers['x-admin-secret'] || '') ||
  (req.query.secret || '')
).trim();

if (!adminSecret || provided !== adminSecret) {
  res.status(403).json({ error: 'Unauthorized' });
  return;
}
// (index.js satır 2391–2400)
```

- Secret, Firebase Secret Manager'dan `defineSecret('ADMIN_SECRET')` ile yükleniyor (satır 53).
- Runtime'da `ADMIN_SECRET.value()` ile alınıyor.
- `x-admin-secret` header'ı **önce** kontrol ediliyor; yoksa `query.secret` kullanılıyor.

---

### 7. Body Payload

**Gerekmez.** Tüm parametreler query string veya header üzerinden alınıyor. Content-Type header'ı da gerekmez.

---

### 8. Bootstrap Modu — bist_stocks Nasıl Doldurulur?

`?bootstrap=true` query parametresi ile çalıştırıldığında endpoint şunları yapar:

1. **Güvenlik kontrolü:** `bist_index_meta/bist100` dokümanı zaten 50+ sembol içeriyorsa **409 Conflict** döner (kazara üzerine yazılmasını engeller).
2. **Hardcoded liste kullanır:** Borsa İstanbul duyurusu 15598'den türetilmiş 100 sembolik sabit liste (`BIST100_OCT2026`) kullanır — Ekim–Aralık 2026 periyodu.
3. `bist_index_meta/bist100` dokümanına tam listeyi yazar (100 sembol, meta bilgiler).
4. **`bist_stocks` koleksiyonuna yazmaz** bootstrap modunda — sadece `bist_index_meta` güncellenir.

> **ÖNEMLİ NOT:** Bootstrap modu `bist_stocks` koleksiyonuna **doğrudan yazmaz**. Sadece `bist_index_meta/bist100` dokümanını doldurur. `bist_stocks/{SYMBOL}` dokümanları, sonraki normal bir `syncBist100Manual` çalıştırmasında (veya scheduled `syncBist100Index`'te) `bist100Member: true` alanı ile güncellenir.

Normal mod (`bootstrap` parametresi olmadan) ise `runBist100Sync()` fonksiyonunu çağırır; bu fonksiyon hem `bist_index_meta/bist100` hem `bist_stocks/{SYMBOL}` dokümanlarını günceller — ancak `currentSymbols` boşsa validation başarısız olur.

---

### 9. Firebase Proje Bilgileri

| Alan | Değer | Kaynak |
|---|---|---|
| Project ID | `teknik-bakis` | `.firebaserc` |
| Region | `europe-west1` | `functions/index.js` satır 2387 |
| Function adı | `syncBist100Manual` | `functions/index.js` satır 2385 |
| Secret adı | `ADMIN_SECRET` | `functions/index.js` satır 53 |

---

## Önerilen Çalıştırma Sırası

### Adım 1: Dry-run test (bootstrap)
```powershell
curl.exe -X GET "https://europe-west1-teknik-bakis.cloudfunctions.net/syncBist100Manual?secret=BURAYA_ADMIN_SECRET&bootstrap=true&dryRun=true"
```
Beklenen yanıt: `{"success":true,"mode":"bootstrap","dryRun":true,"symbolCount":100,...}`

### Adım 2: Gerçek bootstrap (onaylandıktan sonra)
```powershell
curl.exe -X GET "https://europe-west1-teknik-bakis.cloudfunctions.net/syncBist100Manual?secret=BURAYA_ADMIN_SECRET&bootstrap=true"
```
Beklenen yanıt: `{"success":true,"mode":"bootstrap","dryRun":false,"symbolCount":100,...}`

### Adım 3: Normal sync (bist_stocks'taki bist100Member alanlarını günceller)
```powershell
curl.exe -X GET "https://europe-west1-teknik-bakis.cloudfunctions.net/syncBist100Manual?secret=BURAYA_ADMIN_SECRET"
```

---

## Sonuç ve Dikkat Edilecekler

1. **bist_stocks koleksiyonunu ilk kez doldurmak için tek endpoint:** `syncBist100Manual?bootstrap=true&secret=...`
2. **Firestore'da veri zaten varsa bootstrap çalışmaz** (409 döner) — bu kasıtlı bir güvenlik önlemi.
3. **dryRun=true her zaman güvenli** — Firestore'a hiçbir şey yazmaz, sadece ne yapacağını raporlar.
4. Bootstrap sonrası `bist_stocks` dokümanlarındaki `bist100Member` alanını güncellemek için ek bir normal `syncBist100Manual` çalıştırması gerekebilir (bootstrap sadece meta'yı yazar).
5. `ADMIN_SECRET` değeri Firebase Secret Manager'da — gcloud veya Firebase Console'dan alınabilir.
