# KAP_TOKEN → HTTP Authorization Header İzleme Raporu

**Tarih:** 2025  
**Dosya:** `functions/index.js`  
**Araştırma:** Salt okunur — kod değişikliği yapılmadı.

---

## Özet (Önce Sonuç)

`KAP_TOKEN` değeri Firebase Secret Manager'dan **hiçbir sanitizasyon uygulanmadan** `KAP_TOKEN.value()` ile okunuyor ve doğrudan `Bearer ${token}` şeklinde Authorization header'a yazılıyor. `ADMIN_SECRET` için `.trim()` kullanıldığı hâlde `KAP_TOKEN` için aynı uygulama **yapılmıyor**. Bu, secret'ın kayıt sırasında trailing `\n` ya da `\r\n` içermesi durumunda `Invalid character in header content ["Authorization"]` hatasına neden olur.

**En büyük risk:** Secret'ın `echo` veya benzeri bir araçla kaydedilmiş olması → değer içinde `\n` kalması.

**Önerilen çözüm: A + B birlikte** — Secret `printf` ile yeniden kaydedilmeli (A), ilave güvence olarak kodda da `.trim()` eklenmeli (B).

---

## 1. `KAP_TOKEN` Secret Tanımı

**Dosya:** `functions/index.js`, satır 51–52

```javascript
// ── KAP API Secrets (Firebase Secret Manager) ────────────────────────────────
const KAP_API_KEY  = defineSecret('KAP_API_KEY');
const KAP_TOKEN    = defineSecret('KAP_TOKEN');
```

`defineSecret` Firebase Functions v2'nin `firebase-functions/params` modülünden içe aktarılıyor:

```javascript
// satır 42
const { defineSecret } = require('firebase-functions/params');
```

Bu yöntem, secret değerini Google Cloud Secret Manager'dan çalışma zamanında okur; `.value()` çağrısıyla değere erişilir.

---

## 2. `syncKapManual` İçinde `KAP_TOKEN` Nasıl Okunuyor?

**Dosya:** `functions/index.js`, satır 438–453

```javascript
exports.syncKapManual = onRequest({
  region:  'europe-west1',
  memory:  '512MiB',
  timeoutSeconds: 300,
  secrets: [KAP_API_KEY, KAP_TOKEN, ADMIN_SECRET],
}, async (req, res) => {
  // Admin doğrulama — secret değerini trim et (echo'dan gelen \n)
  const adminSecret = ADMIN_SECRET.value().trim();   // ← trim() UYGULANMIŞ
  const provided    = (req.headers['x-admin-secret'] || req.query.secret || '').trim();
  if (!adminSecret || provided !== adminSecret) {
    res.status(403).json({ error: 'Unauthorized' });
    return;
  }

  try {
    const apiKey = KAP_API_KEY.value();              // ← trim() YOK
    const token  = KAP_TOKEN.value();               // ← trim() YOK
    const result = await runKapSync(apiKey, token, 'manual');
    res.json({ success: true, ...result });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});
```

**Bulgu:** `ADMIN_SECRET` için `// Admin doğrulama — secret değerini trim et (echo'dan gelen \n)` yorumuyla bilinçli olarak `.trim()` uygulanmış. Aynı gerekçe `KAP_TOKEN` için geçerli olmasına karşın token üzerinde `.trim()` **çağrılmıyor**.

---

## 3. `syncMembers(apiKey, token)` Fonksiyonuna Token Hangi Değişkenden Gönderiliyor?

**Çağrı zinciri:**

```
KAP_TOKEN.value()  →  token  →  runKapSync(apiKey, token, 'manual')  →  syncMembers(apiKey, token)
```

**`runKapSync` içi** (satır 329–341):

```javascript
async function runKapSync(apiKey, token, trigger = 'scheduled') {
  ...
  if (trigger === 'scheduled' || trigger === 'manual') {
    await withRetry(() => syncMembers(apiKey, token), 'syncMembers');
  }
  ...
}
```

**`syncMembers` imzası** (satır 149):

```javascript
async function syncMembers(apiKey, token) {
  const data = await kapGet('/members', apiKey, token);
  ...
}
```

Token, `KAP_TOKEN.value()` çıktısından `token` yerel değişkenine atandıktan sonra hiç değiştirilmeden `syncMembers` → `kapGet` zincirine iletiliyor.

---

## 4. `kapGet()` İçinde Authorization Header'ın Oluşturulduğu TAM Satır

**Dosya:** `functions/index.js`, satır 81

```javascript
'Authorization': `Bearer ${token}`,
```

Tam bağlam (satır 67–85):

```javascript
function kapGet(path, apiKey, token, queryParams = {}) {
  return new Promise((resolve, reject) => {
    const url = new URL(`${KAP_BASE}${path}`);
    ...
    const options = {
      hostname: url.hostname,
      path: url.pathname + url.search,
      method: 'GET',
      headers: {
        'Authorization': `Bearer ${token}`,    // ← TAM SATIR (satır 81)
        'X-Api-Key':     apiKey,
        'Accept':        'application/json',
        'Content-Type':  'application/json',
      },
      timeout: 20000,
    };
```

---

## 5. Token'a `.trim()`, `.replace()`, `String()` Uygulanıyor mu?

Tüm çağrı zinciri tarandı:

| Adım | Kod | `.trim()` / `.replace()` / `String()` |
|---|---|---|
| Secret okuma | `KAP_TOKEN.value()` | ❌ Yok |
| `syncKapManual` yerel değişken | `const token = KAP_TOKEN.value()` | ❌ Yok |
| `runKapSync` parametre aktarımı | `runKapSync(apiKey, token, 'manual')` | ❌ Yok |
| `syncMembers` parametre aktarımı | `syncMembers(apiKey, token)` | ❌ Yok |
| `kapGet` header yazımı | `` `Bearer ${token}` `` | ❌ Yok |

**Karşılaştırma:** `ADMIN_SECRET` için `ADMIN_SECRET.value().trim()` bilinçli olarak kullanılmış (kod yorumu bile var: `// echo'dan gelen \n`). Aynı koruma `KAP_TOKEN` ve `KAP_API_KEY` için **uygulanmamış**.

---

## 6. Authorization Header'a `KAP_TOKEN` Dışında Başka Bir Değer Ekleniyor mu?

Evet, template literal `Bearer ` sabit prefixi token'a ekleniyor:

```javascript
'Authorization': `Bearer ${token}`,
```

Başka birleştirme yok. `apiKey` ayrı bir header (`X-Api-Key`) olarak gönderiliyor, Authorization header'a karışmıyor.

---

## 7. `KAP_TOKEN` Secret Manager Version Binding'i Var mı?

**`firebase.json`** incelendi — secret version bağlaması **yok**:

```json
"functions": [
  {
    "source": "functions",
    "codebase": "default",
    "ignore": ["node_modules", ".git", ...]
  }
]
```

**`functions/index.js`** secret tanımı:

```javascript
const KAP_TOKEN = defineSecret('KAP_TOKEN');
```

`defineSecret` çağrısında version belirtilmemiş. Function deployment `secrets` dizisinde de versiyon pini yok:

```javascript
secrets: [KAP_API_KEY, KAP_TOKEN, ADMIN_SECRET],
```

**Sonuç:** Secret Manager'ın **en son (latest) versiyonu** her zaman kullanılır. Eğer secret daha önce `\n` içeren değerle kaydedildiyse ve üzerine yeni bir versiyon yazılmadan function yeniden deploy edildiyse, eski kirli değer hâlâ aktif olabilir.

---

## 8. `KAP_TOKEN` Değerinde `\r`, `\n`, `\r\n` Kalma İhtimali

### Yüksek Risk Faktörleri

**a) `echo` ile secret kaydetme (en yaygın neden):**

```bash
# Bu yöntem trailing \n ekler:
echo "token_değeri" | firebase functions:secrets:set KAP_TOKEN
```

`echo` komutu her platformda satır sonu ekler. Shell script veya terminal ile kaydedilmişse bu karakter değerin içinde kalır.

**b) `.env` dosyası yok** — projede `functions/.env` dosyası bulunamadı. Secret'lar doğrudan Firebase Secret Manager'dan okunuyor. Ancak secret'ın Secret Manager'a nasıl girildiği bilinmiyor.

**c) Windows ortamında kayıt:** Bu proje Windows üzerinde geliştiriliyor (sistem bilgisi: `win32`). Windows'ta terminalde kopyala-yapıştır veya `echo` ile set edilen değerlerde `\r\n` bulunabilir.

**d) Kod yorumu bir ipucu:**  
Satır 441'deki yorum `// Admin doğrulama — secret değerini trim et (echo'dan gelen \n)` geliştirici tarafından bu sorunun daha önce `ADMIN_SECRET` için karşılaşıldığını ve manuel olarak fixlendiğini gösteriyor. `KAP_TOKEN` için aynı fix yapılmamış.

### Hata Mesajıyla Doğrudan İlişki

`Invalid character in header content ["Authorization"]` hatası Node.js `http.request` tarafından header değerinde `\r`, `\n`, veya `\0` gibi kontrol karakterleri tespit edildiğinde fırlatılır. Bu hata HTTP 401/403 döndürmez — istek **hiç gönderilmez**.

---

## 9. `syncKapManual` ile `syncKapDisclosures` Aynı Okuma Yöntemini mi Kullanıyor?

**Evet, her ikisi de aynı `KAP_TOKEN.value()` (trim'siz) yöntemini kullanıyor.**

**`syncKapDisclosures`** (satır 417–429):

```javascript
exports.syncKapDisclosures = onSchedule({
  schedule:       '*/15 * * * *',
  timeZone:       'UTC',
  region:         'europe-west1',
  memory:         '512MiB',
  timeoutSeconds: 300,
  secrets:        [KAP_API_KEY, KAP_TOKEN],
}, async () => {
  const apiKey = KAP_API_KEY.value();
  const token  = KAP_TOKEN.value();      // ← trim() YOK
  await runKapSync(apiKey, token, 'scheduled');
});
```

**`syncKapManual`** (satır 434–453):

```javascript
exports.syncKapManual = onRequest({
  ...
  secrets: [KAP_API_KEY, KAP_TOKEN, ADMIN_SECRET],
}, async (req, res) => {
  ...
  const token  = KAP_TOKEN.value();      // ← trim() YOK
  ...
});
```

**Diğer scheduled fonksiyonlar (`syncKapOpeningPre`, `syncKapOpeningWindow`) da aynı:**

```javascript
const token  = KAP_TOKEN.value();   // satır 392, 406 — trim() yok
```

**Fark:** Tüm fonksiyonlar aynı sorunu paylaşıyor. Eğer secret kirli ise **tüm KAP sync fonksiyonları** aynı hatayı verir.

---

## 10. Değerlendirme ve Öneri

### Kanıt Özeti

| # | Bulgu | Risk |
|---|---|---|
| 1 | `KAP_TOKEN.value()` sonucuna `trim()` uygulanmıyor | 🔴 Yüksek |
| 2 | `ADMIN_SECRET` için `trim()` var, `KAP_TOKEN` için yok — tutarsızlık | 🔴 Yüksek |
| 3 | Kod yorumu `// echo'dan gelen \n` önceki bir sorunun farkındalığını gösteriyor | 🔴 Kanıt |
| 4 | `firebase.json`'da secret version pini yok — en son versiyon kullanılır | 🟡 Orta |
| 5 | Windows geliştirme ortamı — `\r\n` riski | 🟡 Orta |
| 6 | Tüm 4 KAP fonksiyonu aynı sorunu paylaşıyor | 🔴 Yüksek |

### Seçenek Değerlendirmesi

| Seçenek | Açıklama | Yeterli mi? |
|---|---|---|
| **A) Secret yeniden kaydedilmeli** | `printf` (echo değil) ile `\n`'siz kayıt | ✅ Tek başına yeterli |
| **B) Kodda `.trim()` uygulanmalı** | `KAP_TOKEN.value().trim()` | ✅ Tek başına yeterli, ama root cause'u çözmez |
| **C) Function secret binding sorunu** | `firebase.json`'da version pini yok ama bu yeterli çalışıyor | ❌ Asıl sorun değil |
| **D) Başka bir neden** | API anahtarı geçersizliği, IP bloğu vb. | ❓ Olası ama header hatası bunlarla oluşmaz |

### **Öneri: A + B (ikisi birden)**

**Adım 1 — Secret'ı temiz kaydet (A):**
```bash
# Windows PowerShell:
$token = Read-Host "Token" -AsSecureString
# Ardından Firebase Console UI üzerinden manuel girin (en güvenli)
```
veya Linux/WSL'de:
```bash
printf 'token_degeri_buraya' | firebase functions:secrets:set KAP_TOKEN
printf 'api_key_degeri_buraya' | firebase functions:secrets:set KAP_API_KEY
```

**Adım 2 — Kodda `.trim()` ekle (B) — Savunma katmanı:**

Değiştirilecek her satır aynı pattern:
```javascript
// ÖNCE:
const token  = KAP_TOKEN.value();

// SONRA:
const token  = KAP_TOKEN.value().trim();
```

Bu değişiklik `syncKapManual`, `syncKapDisclosures`, `syncKapOpeningPre`, `syncKapOpeningWindow` — toplam 4 konumda yapılmalı.

**Gerekçe:** `ADMIN_SECRET` için geliştirici bu sorunu zaten yaşadı ve `trim()` ile çözdü (yorum satırı bunu kanıtlıyor). `KAP_TOKEN` için aynı uygulama yapılmadı. Secret'ı yeniden kaydetmek root cause'u çözer; `.trim()` ise ileride aynı sorunun tekrarını önleyecek savunma katmanı sağlar.

---

## Dosya Referansı

- **Kaynak kod:** `functions/index.js`
- **Secret tanımı:** satır 51–52
- **`kapGet` Authorization satırı:** satır 81
- **`syncKapManual` token okuma:** satır 450–451
- **`syncKapDisclosures` token okuma:** satır 426–427
- **`syncKapOpeningPre` token okuma:** satır 391–392
- **`syncKapOpeningWindow` token okuma:** satır 405–406
- **`runKapSync` → `syncMembers` çağrısı:** satır 339
- **`syncMembers` imzası:** satır 149
- **Deployment konfigürasyonu:** `firebase.json`
