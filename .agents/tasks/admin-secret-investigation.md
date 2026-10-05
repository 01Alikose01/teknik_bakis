# ADMIN_SECRET Araştırma Raporu

**Tarih:** 2025  
**Kapsam:** `syncBist100Manual` fonksiyonu için kullanılan `ADMIN_SECRET`'ın kaynağı ve kullanım biçimi

---

## Özet Cevap

| Soru | Cevap |
|------|-------|
| Firebase Secret Manager'da mı? | **EVET** — `defineSecret('ADMIN_SECRET')` ile tanımlı |
| Environment/config dosyasında mı? | **HAYIR** — `.env` veya `.secret.local` dosyası bulunamadı |
| Kodda sabit (hardcoded) mi? | **HAYIR** — değer kaynak kodda yok |
| Flutter tarafında kullanılıyor mu? | **HAYIR** — `lib/` içinde hiç referans yok |

---

## Kanıtlar

### 1. Firebase Secret Manager (`defineSecret`)

**Dosya:** `functions/index.js`, satır 42–53

```js
const { defineSecret } = require('firebase-functions/params');  // satır 42

// ── KAP API Secrets (Firebase Secret Manager) ────────────────────────────────
const KAP_API_KEY    = defineSecret('KAP_API_KEY');
const KAP_TOKEN      = defineSecret('KAP_TOKEN');
const ADMIN_SECRET   = defineSecret('ADMIN_SECRET');  // Manuel sync koruması
const NVIDIA_API_KEY = defineSecret('NVIDIA_API_KEY');
```

`defineSecret`, Firebase Functions v2'nin `firebase-functions/params` modülünden gelir.
Bu API, Google Cloud Secret Manager'da kayıtlı secret'lara çalışma zamanında erişir.
Secret'ın gerçek değeri ne kaynak kodda ne de yerel config dosyasında bulunur;
değer deploy sırasında Firebase'in ortamına inject edilir.

### 2. `syncBist100Manual` içindeki auth kodu

**Dosya:** `functions/index.js`, satır 1986–2004

```js
exports.syncBist100Manual = onRequest({
  region:         'europe-west1',
  memory:         '512MiB',
  timeoutSeconds: 300,
  secrets:        [ADMIN_SECRET],          // ← secret'ı fonksiyona bağlar
}, async (req, res) => {
  // Admin doğrulama
  const adminSecret = ADMIN_SECRET.value().trim();  // ← Cloud Secret Manager'dan okur
  const provided    = (
    (req.headers['x-admin-secret'] || '') ||         // ← önce header'a bakar
    (req.query.secret || '')                         // ← yoksa query param'a bakar
  ).trim();

  if (!adminSecret || provided !== adminSecret) {
    res.status(403).json({ error: 'Unauthorized' });
    return;
  }
  // ...
```

### 3. Yerel config dosyası kontrolü

Aşağıdaki dosyaların **hiçbiri** projede mevcut değil:

- `functions/.secret.local` → yok
- `functions/.env` → yok  
- `functions/.env.local` → yok
- Proje kökünde `.env` → yok

### 4. Flutter tarafı (`lib/`)

`lib/` klasöründe `ADMIN_SECRET`, `adminSecret`, `admin_secret` araması sıfır sonuç döndü.
Bu doğru: `syncBist100Manual` yalnızca bir admin CLI/curl aracından çağrılır,
Flutter uygulaması bu endpoint'i hiç kullanmaz.

---

## Dry-Run Çağrısı Nasıl Yapılır

Secret değeri `<ADMIN_SECRET>` olarak gösterilmiştir; gerçek değeri `firebase functions:secrets:access ADMIN_SECRET` ile alabilirsiniz.

### Header ile (önerilen — değer URL'de görünmez):

```bash
curl -H "x-admin-secret: <ADMIN_SECRET>" \
  "https://europe-west1-<PROJECT_ID>.cloudfunctions.net/syncBist100Manual?dryRun=true"
```

### Query param ile:

```bash
curl "https://europe-west1-<PROJECT_ID>.cloudfunctions.net/syncBist100Manual?dryRun=true&secret=<ADMIN_SECRET>"
```

### Bootstrap dry-run (Firestore boşken ilk yükleme testi):

```bash
curl -H "x-admin-secret: <ADMIN_SECRET>" \
  "https://europe-west1-<PROJECT_ID>.cloudfunctions.net/syncBist100Manual?bootstrap=true&dryRun=true"
```

`dryRun=true` ile çağrıldığında fonksiyon Firestore'a **hiçbir şey yazmaz**;
yalnızca parse sonucunu ve yapılacak değişiklikleri JSON olarak döndürür.

---

## Teknik Akış Özeti

```
Çağrı gelir
  │
  ├─ Header: x-admin-secret  ─┐
  └─ Query:  ?secret=...     ─┤
                               ▼
                    ADMIN_SECRET.value()  ← Google Cloud Secret Manager
                               │
                    trim → karşılaştır
                               │
                    ✓ eşleşirse → işlemi çalıştır
                    ✗ eşleşmezse → 403 Unauthorized
```

---

## Sonuç ve Öneriler

**Sonuç:** `ADMIN_SECRET` tamamen Firebase Secret Manager'da tutulmakta, kodda sabit değer yok,
yerel config dosyasına yazılmamış. Yapı güvenlik açısından doğru.

**Öneriler:**

1. **Header tercih et, query param'dan kaçın:** Query param'lar web sunucu loglarına düşer.
   Header (`x-admin-secret`) kullanmak daha güvenli.

2. **Secret rotasyonu:** `firebase functions:secrets:set ADMIN_SECRET` komutuyla periyodik rotasyon yapılabilir; deploy gerekmez, Cloud Functions yeni değeri otomatik alır.

3. **Secret erişim logu:** Google Cloud Console → Secret Manager → ADMIN_SECRET → "Versions" sekmesinde erişim logları izlenebilir (Cloud Audit Logging aktifse).

4. **`.gitignore` kontrolü:** Proje kökünde `.secret.local` veya `.env` dosyası oluşturulursa `.gitignore`'a eklenmeli. Şu an bu dosyalar yok, risk sıfır.
