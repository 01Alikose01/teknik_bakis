# syncKapManual — /members Senkronizasyon Test Planı

**Tarih:** 2025  
**Kapsam:** `syncKapManual` fonksiyonunu manuel olarak çalıştırarak sadece `/members` sync'ini test etmek.  
**Mod:** Salt okunur araştırma — hiçbir dosya değiştirilmedi.

---

## ÖZET CEVAP (Önce Sonuç)

`syncKapManual` bir Firebase Cloud Functions HTTP endpoint'idir.  
**Tam URL:** `https://europe-west1-teknik-bakis.cloudfunctions.net/syncKapManual`  
**Auth:** `x-admin-secret` header'ı veya `?secret=` query param ile.  
**Secret yeri:** Firebase Secret Manager — `ADMIN_SECRET` adlı secret.

Aşağıdaki tek curl komutu ile `/members` sync'ini tetikleyip tüm istenen çıktıları alırsınız:

```powershell
# PowerShell
$adminSecret = (firebase functions:secrets:access ADMIN_SECRET 2>&1).Trim()

curl.exe -X GET `
  -H "x-admin-secret: $adminSecret" `
  "https://europe-west1-teknik-bakis.cloudfunctions.net/syncKapManual" `
  -v 2>&1
```

veya tek satır olarak (`$adminSecret` değerini manuel girerek):

```powershell
curl.exe -X GET -H "x-admin-secret: BURAYA_ADMIN_SECRET" "https://europe-west1-teknik-bakis.cloudfunctions.net/syncKapManual"
```

`syncKapManual` her zaman `trigger='manual'` ile `runKapSync` → `syncMembers` → `/members` çağrısını yapar; `/members` bölümünü seçici olarak çalıştıracak ayrı bir parametre yoktur. Ancak `syncMembers` hata fırlatırsa `syncDisclosures`'a geçilmez — bu nedenle `/members` başarısız olduğunda response `{ "error": "..." }` içerir ve Firestore'a hiçbir şey yazılmaz.

---

## 1. Fonksiyon Tanımı

**Dosya:** `functions/index.js`, satır 434–454

```javascript
exports.syncKapManual = onRequest({
  region:  'europe-west1',
  memory:  '512MiB',
  timeoutSeconds: 300,
  secrets: [KAP_API_KEY, KAP_TOKEN, ADMIN_SECRET],
}, async (req, res) => {
  // Admin doğrulama — secret değerini trim et (echo'dan gelen \n)
  const adminSecret = ADMIN_SECRET.value().trim();
  const provided    = (req.headers['x-admin-secret'] || req.query.secret || '').trim();
  if (!adminSecret || provided !== adminSecret) {
    res.status(403).json({ error: 'Unauthorized' });
    return;
  }

  try {
    const apiKey = KAP_API_KEY.value().trim();   // ← .trim() UYGULANMIŞ
    const token  = KAP_TOKEN.value().trim();     // ← .trim() UYGULANMIŞ
    const result = await runKapSync(apiKey, token, 'manual');
    res.json({ success: true, ...result });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});
```

**Not:** Önceki araştırma raporunda (`kap-token-auth-investigation.md`) `KAP_TOKEN.value()` üzerinde `.trim()` olmadığı belgelenmişti. **Mevcut kodda bu fix zaten uygulanmış** — hem `KAP_API_KEY.value().trim()` hem `KAP_TOKEN.value().trim()` kullanılıyor.

---

## 2. KAP_API_KEY ve KAP_TOKEN Secret'larının Konumu

Üç secret de **Firebase Secret Manager**'da tanımlı. Kodda sabit değer yok, `.env` veya `.secret.local` dosyası bulunmuyor.

**Tanım** (`functions/index.js`, satır 51–53):
```javascript
const KAP_API_KEY  = defineSecret('KAP_API_KEY');
const KAP_TOKEN    = defineSecret('KAP_TOKEN');
const ADMIN_SECRET = defineSecret('ADMIN_SECRET');
```

Secret değerlerine şu komutla erişilebilir (Firebase CLI giriş yapılmış olmalı):
```bash
firebase functions:secrets:access KAP_API_KEY
firebase functions:secrets:access KAP_TOKEN
firebase functions:secrets:access ADMIN_SECRET
```

Değerlerin kendisi bu raporda gösterilmez.

---

## 3. MKK /members HTTP Çağrısının Tam Detayı

### URL

```
GET https://apigwdev.mkk.com.tr/api/vyk/members
```

`KAP_BASE` sabiti (`functions/index.js`, satır 62):
```javascript
const KAP_BASE = 'https://apigwdev.mkk.com.tr/api/vyk';
```

`syncMembers` çağrısı (`functions/index.js`, satır 153):
```javascript
const data = await kapGet('/members', apiKey, token);
```

### Headers

`kapGet()` fonksiyonu (`functions/index.js`, satır 67–85):

```javascript
{
  'Authorization': `Bearer ${token}`,   // KAP_TOKEN secret'ı
  'X-Api-Key':     apiKey,              // KAP_API_KEY secret'ı
  'Accept':        'application/json',
  'Content-Type':  'application/json',
}
```

Timeout: 20 saniye (`timeout: 20000`).

### Request Body

Yok — GET isteği, body yok.

### Hata Yönetimi

HTTP 200 dışı her status kod için `kapGet` şu hatayla reject eder:
```
HTTP <statusCode> — /members — <body ilk 200 karakter>
```

Bu mesaj `withRetry` → `runKapSync catch` → `res.status(500).json({ error: '...' })` zinciriyle caller'a döner.

---

## 4. Çağrı Zinciri: syncKapManual → /members

```
syncKapManual (HTTP trigger, trigger='manual')
  └─► runKapSync(apiKey, token, 'manual')            [index.js:329]
        └─► withRetry(() => syncMembers(...))         [index.js:338–340]
              └─► syncMembers(apiKey, token)          [index.js:151]
                    └─► kapGet('/members', apiKey, token)  [index.js:153]
                          └─► GET https://apigwdev.mkk.com.tr/api/vyk/members
```

**Önemli:** `runKapSync` içinde `syncMembers` (trigger='manual' koşulunu geçer) hata fırlatırsa `syncDisclosures`'a geçilmez. Tüm sync durur, `kap_sync_logs`'a `status: 'failed'` yazılır.

---

## 5. Mevcut Test Script / Invoke Yöntemi

Projede hazır bir test script veya CLI helper bulunmuyor (`functions/` dizininde yalnızca `index.js`, `package.json`, `package-lock.json` var). `package.json` scripts'i:

```json
{
  "serve": "firebase emulators:start --only functions",
  "deploy": "firebase deploy --only functions"
}
```

Invoke için Firebase Emulator veya curl kullanılmalı.

---

## 6. Test Komutu (Adım Adım)

### Ön Koşul
- `firebase-tools` kurulu ve `teknik-bakis` projesine giriş yapılmış (`firebase login`)
- PowerShell veya Windows Terminal (WSL de kullanılabilir)

### Adım 1 — ADMIN_SECRET değerini al

```powershell
firebase functions:secrets:access ADMIN_SECRET
```

Çıktıyı bir değişkene ata (terminal loglarına yazdırmaktan kaçınmak için):

```powershell
$adminSecret = (firebase functions:secrets:access ADMIN_SECRET 2>&1).Trim()
```

### Adım 2 — syncKapManual çağrısı

```powershell
curl.exe -X GET `
  -H "x-admin-secret: $adminSecret" `
  "https://europe-west1-teknik-bakis.cloudfunctions.net/syncKapManual" `
  --max-time 310
```

`--max-time 310` eklenebilir (fonksiyon timeoutSeconds: 300; curl default çok daha kısa olabilir).

### Adım 3 — Verbose mode (HTTP status + headers görmek için)

```powershell
curl.exe -X GET `
  -H "x-admin-secret: $adminSecret" `
  "https://europe-west1-teknik-bakis.cloudfunctions.net/syncKapManual" `
  -v `
  --max-time 310 `
  2>&1
```

---

## 7. Beklenen Çıktılar

### Başarı Durumu (HTTP 200)

```json
{
  "success": true,
  "added": 42,
  "updated": 0
}
```

| Alan | Kaynak |
|---|---|
| `added` | `syncDisclosures` sonucu (yeni bildirim sayısı) |
| `updated` | `syncDisclosures` sonucu (güncellenen bildirim sayısı) |
| `success` | `true` |

**Not:** `syncMembers` sonucu (Firestore'a yazılan `kap_members` sayısı) response'ta **görünmüyor** — `runKapSync` sadece `syncDisclosures` sonucunu döndürüyor. `syncMembers` yazma sayısını görmek için Firebase Functions loglarına bakılmalı:

```
Console log: "Şirket listesi tamamlandı: N kayıt"
```

### /members API Hatası (HTTP 500)

```json
{
  "error": "HTTP 401 — /members — <API yanıt body>"
}
```
veya
```json
{
  "error": "Şirket listesi boş geldi"
}
```

Bu durumda Firestore'a hiç `kap_members` yazılmaz.

### Authorization Hatası (HTTP 403)

```json
{
  "error": "Unauthorized"
}
```

ADMIN_SECRET yanlış girildi demektir.

### MKK faultCode / response message

`kapGet` HTTP 200 dışı yanıtlarda body'nin ilk 200 karakterini error mesajına ekler:

```
HTTP 401 — /members — {"faultCode":"401","message":"Unauthorized: ..."}
```

`faultCode` ve `message` bu şekilde `error` alanının içinde görünür. MKK API 200 döndürüp body'de `faultCode` içeriyorsa kod bunu ayrıştırmaz — `members.length === 0` durumuna düşer.

---

## 8. totalKapMembers Doğrulama

Response'ta `totalKapMembers` alanı **yok**. Bunu görmek için:

**Seçenek A — Firebase Functions Logları:**
```
Firebase Console → Functions → syncKapManual → Logs
→ "Şirket listesi tamamlandı: N kayıt"
```

**Seçenek B — Firebase Admin Console:**
```
Firebase Console → Firestore → kap_members koleksiyonu
→ Doküman sayısını say
```

**Seçenek C — kap_sync_logs:**
```
Firebase Console → Firestore → kap_sync_logs koleksiyonu
→ En son belge → records_added / records_updated
```
(Not: `kap_sync_logs` client SDK ile okunamaz — `allow read: if false` kuralı var. Sadece Firebase Admin Console'dan erişilebilir.)

---

## 9. Hata Varsa Bakılacak Yerler

1. **curl response body** — `error` alanı
2. **Firebase Console → Functions → Logs → syncKapManual** — tüm `console.log`, `console.warn`, `console.error` çıktıları
3. **Firestore → meta/kap dokümanı** — `lastSyncStatus`, `lastSyncError`
4. **Firestore → kap_sync_logs** — `status`, `error_message` alanları

---

## 10. Proje Kimliği Referansı

| Alan | Değer |
|---|---|
| Firebase Project ID | `teknik-bakis` |
| `.firebaserc` | `{ "projects": { "default": "teknik-bakis" } }` |
| Functions Region | `europe-west1` |
| Base URL | `https://europe-west1-teknik-bakis.cloudfunctions.net/` |
| MKK API Base | `https://apigwdev.mkk.com.tr/api/vyk` |
| `/members` Endpoint | `GET https://apigwdev.mkk.com.tr/api/vyk/members` |

---

## 11. Mevcut Kod Durumu (Güncel)

Önceki araştırma raporları (`kap-token-auth-investigation.md`) `.trim()` eksikliğini belgelemişti. **Mevcut `functions/index.js`'te bu durum düzeltilmiş:**

```javascript
// index.js satır 448–449 (mevcut):
const apiKey = KAP_API_KEY.value().trim();   // ✅
const token  = KAP_TOKEN.value().trim();     // ✅
```

Herhangi bir ek kod değişikliği yapmadan `syncKapManual`'ı olduğu gibi test edebilirsiniz.

---

## SONUÇ VE ÖNERİLER

### Tek Komut Özeti

```powershell
# 1. Secret'ı al
$adminSecret = (firebase functions:secrets:access ADMIN_SECRET 2>&1).Trim()

# 2. Test et
curl.exe -X GET -H "x-admin-secret: $adminSecret" `
  "https://europe-west1-teknik-bakis.cloudfunctions.net/syncKapManual" `
  -v --max-time 310 2>&1
```

### Beklenen İstenen Bilgiler

| İstenen | Nerede Görünür |
|---|---|
| HTTP status | curl `-v` çıktısında `< HTTP/2 200` şeklinde |
| MKK faultCode | `error` alanında: `"HTTP 4xx — /members — {faultCode: ...}"` |
| MKK response message | `error` alanında: `"HTTP 4xx — /members — {message: ...}"` |
| totalKapMembers | Functions log'unda `"Şirket listesi tamamlandı: N kayıt"` |
| Firestore kap_members yazılan sayısı | Functions log'unda + Firestore Console kap_members koleksiyonu |

### Potansiyel Sorunlar

1. **KAP_TOKEN / KAP_API_KEY geçersizse** → HTTP 401/403 döner, response `error` alanında tam body ilk 200 karakter görünür.
2. **API yanıtı beklenmedik field adı kullanıyorsa** (örn. `content`, `result`, `list`) → `"Şirket listesi boş geldi"` hatası alınır; gerçek API yapısını Functions loglarına debug logu ekleyerek görmek gerekir.
3. **Functions deploy edilmemiş** → HTTP 404 veya connection error alınır.

*Bu rapor yalnızca mevcut kaynak kodu okunarak üretilmiştir. Hiçbir dosya değiştirilmedi.*
