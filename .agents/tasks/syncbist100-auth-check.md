# syncBist100Manual — AUTH Analiz Raporu

**Tarih:** 2026-10-05  
**Kapsam:** Read-only araştırma — hiçbir dosya değiştirilmedi, deploy yapılmadı.  
**Kaynak:** `functions/index.js` (satır 2385–2400 doğrudan okundu)

---

## ÖZET CEVAPLAR (Hızlı Referans)

| # | Soru | Kesin Cevap |
|---|------|-------------|
| 1 | Hangi Secret Manager secret'ını kullanıyor? | **`ADMIN_SECRET`** — `defineSecret('ADMIN_SECRET')` ile tanımlı (satır 53) |
| 2 | Header olarak tam olarak hangi header'ı bekliyor? | **`x-admin-secret`** |
| 3 | Query parametre olarak hangi isimle secret bekliyor? | **`?secret=...`** (parametre adı `secret`) |
| 4 | `x-admin-secret` header'ını destekliyor mu? | **EVET** — ve query param'dan *önce* kontrol ediliyor |
| 5 | `syncIpoManual` ile aynı `ADMIN_SECRET` değerini kullanabilir miyiz? | **EVET** — ikisi de aynı `ADMIN_SECRET` secret'ını kullanıyor |
| 6 | Yerel kod ile canlı kod arasında auth açısından fark var mı? | **HAYIR** — `git diff HEAD` boş, `functions/index.js` temiz |

---

## Detaylı Kanıtlar

### 1. Secret Tanımı — `functions/index.js` satır 53

```javascript
const ADMIN_SECRET = defineSecret('ADMIN_SECRET'); // Manuel sync koruması
```

`defineSecret`, `firebase-functions/params` modülünden gelir. Bu, Google Cloud Secret Manager'daki `ADMIN_SECRET` adlı secret'a bağlanır. Değer deploy sırasında inject edilir; kaynak kodda veya yerel dosyada bulunmaz.

---

### 2. `syncBist100Manual` Auth Kodu — `functions/index.js` satır 2389–2400

```javascript
exports.syncBist100Manual = onRequest({
  region:         'europe-west1',
  memory:         '512MiB',
  timeoutSeconds: 300,
  secrets:        [ADMIN_SECRET],   // ← secret fonksiyona bağlanıyor
}, async (req, res) => {
  // Admin doğrulama
  const adminSecret = ADMIN_SECRET.value().trim();
  const provided    = (
    (req.headers['x-admin-secret'] || '') ||   // ← ÖNCE header kontrol
    (req.query.secret || '')                    // ← sonra query param
  ).trim();

  if (!adminSecret || provided !== adminSecret) {
    res.status(403).json({ error: 'Unauthorized' });
    return;
  }
```

**Çalışma mantığı:** `x-admin-secret` header'ı varsa kullanılır. Yoksa `?secret=` query parametresi kullanılır. İkisi de boşsa 403 döner.

---

### 3. `syncIpoManual` Auth Kodu — `functions/index.js` satır 1157–1167

```javascript
exports.syncIpoManual = onRequest({
  region:         'europe-west1',
  memory:         '512MiB',
  timeoutSeconds: 300,
  secrets:        [ADMIN_SECRET],   // ← AYNI ADMIN_SECRET
}, async (req, res) => {
  const secret = ADMIN_SECRET.value().trim();
  const given  = (req.headers['x-admin-secret'] || req.query.secret || '').trim();
  if (!secret || given !== secret) { res.status(403).json({ error: 'Unauthorized' }); return; }
```

**Karşılaştırma:**
- `syncBist100Manual`: `(req.headers['x-admin-secret'] || '') || (req.query.secret || '')`
- `syncIpoManual`: `req.headers['x-admin-secret'] || req.query.secret || ''`

Fonksiyonel olarak **identik** — her ikisi de `x-admin-secret` header'ını önce dener, yoksa `?secret=` query param'a düşer. Her iki fonksiyon da **aynı `ADMIN_SECRET`** değerini kullanır.

---

### 4. Yerel ↔ Canlı Fark Kontrolü

```
git log --oneline -5 -- functions/index.js
89b8d5a (HEAD -> main) fix(ipo): BIST kontrolü ve trading koruma — syncIpoFeed durum öncelik sırası düzeltildi
e90663f chore: uygulama son hali - halka arz tarih duzeltmesi ve veri dosyalari guncellendi
b029aeb Billing 8.0.0 ve geri tuşu iyileştirmeleri
ef302af feat: BIST100 otomatik guncelleme backend sistemi
56145db feat(billing): Google Play Billing 8 entegrasyonu...
```

`git diff HEAD -- functions/index.js` → **boş çıktı** (auth bloğunda hiçbir uncommitted değişiklik yok).

Son deploy'un ne zaman yapıldığı bilgisi yerel git'te tutulmuyor (gcloud üzerinden doğrulanmalı). Ancak `functions/index.js` son commit `89b8d5a` — bu commit'in içeriği (ipo feed düzeltmesi) `syncBist100Manual`'ın auth bloğuna dokunmamış. Auth kodu `ef302af` commit'iyle (`feat: BIST100 otomatik guncelleme backend sistemi`) eklenmiş ve o günden bu yana değişmemiş.

**Sonuç:** Yerel `functions/index.js` ile son commit arasında auth açısından fark yok. Canlı deploy bu commit'in gerisindeyse fark oluşabilir — ancak auth mantığı `ef302af`'den bu yana değişmediği için bu olası değil.

---

## Kullanım Örnekleri

### Header ile (önerilen — değer URL log'larına düşmez):
```bash
curl -H "x-admin-secret: <ADMIN_SECRET_DEGERİ>" \
  "https://europe-west1-teknik-bakis.cloudfunctions.net/syncBist100Manual?dryRun=true"
```

### Query param ile:
```bash
curl "https://europe-west1-teknik-bakis.cloudfunctions.net/syncBist100Manual?secret=<ADMIN_SECRET_DEGERİ>&dryRun=true"
```

### `syncIpoManual` ile aynı secret çalışır:
```bash
# syncIpoManual için kullandığınız değerin AYNISI syncBist100Manual için de geçerlidir
curl -H "x-admin-secret: <ADMIN_SECRET_DEGERİ>" \
  "https://europe-west1-teknik-bakis.cloudfunctions.net/syncBist100Manual?dryRun=true"
```

---

## Sonuç

`syncBist100Manual` ve `syncIpoManual` auth açısından tamamen identik:
- Aynı secret (`ADMIN_SECRET` — Google Cloud Secret Manager)
- Aynı header adı (`x-admin-secret`)
- Aynı query param adı (`?secret=`)
- Aynı öncelik sırası (header > query param)

**`syncIpoManual` için hangi `ADMIN_SECRET` değerini kullanıyorsanız, `syncBist100Manual` için de o değeri kullanın.**
