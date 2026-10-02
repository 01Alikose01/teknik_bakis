# Implementation Plan — BIST100 Backend Sync

Hedef: `functions/index.js` sonuna iki yeni Cloud Function ekle ve `firestore.rules` dosyasına iki yeni collection kuralı ekle.
Flutter/Dart dosyalarına dokunma. Mevcut exportlara dokunma.

---

## Codebase Gerçekleri (Keşif Bulguları)

- `functions/index.js` şu exportları içeriyor: `syncKapOpeningPre`, `syncKapOpeningWindow`,
  `syncKapDisclosures`, `syncKapManual`, `updateFundamentals`, `updateFundamentalsManual`,
  `syncIpoFeed`, `syncIpoManual`, `getTeknikAnaliz`, `cleanAiCache`, `verifySubscription`,
  `onPurchaseWritten`. Bunlara **dokunma**.
- Dosyada zaten `fetchJson()` iki kez tanımlanmış (yaklaşık satır 90 ve satır 500 civarı).
  Bu bir tekrar — bunu düzeltme; sadece yeni `fetchHtml()` ekle.
- `defineSecret`, `onSchedule`, `onRequest`, `initializeApp`, `db`, `FieldValue`, `https`,
  `withRetry` hepsi zaten tanımlı.
- Mevcut `ADMIN_SECRET` secret'ı zaten `defineSecret` ile tanımlı ve bazı fonksiyonlarda
  kullanılıyor.
- Flutter tarafı `bist_index_meta/bist100` dokümanındaki `symbols` alanını okuyor
  (`bist100_service.dart` satır 90-103).
- Flutter tarafı `bist_stocks` collection'ını `where('active', isNotEqualTo: false)` ile okuyor;
  `active` alanına dokunma.
- `bist_stocks` içinde beklenen alanlar: `symbol`, `name`, `active`, + `bist100Member` (bool).
- `kap_members` collection'ı mevcut ve `stockCode` alanını içeriyor — yeni sembol için ad araması
  buradan yapılacak.
- `firestore.rules` içinde `bist_stocks` ve `bist_index_meta` için hiç kural yok — eklenecek.
- Node.js engine: 22 (package.json). Region: `europe-west1`.
- Deploy komutu: `firebase deploy --only functions` (functions/ dizininde).

---

## Adımlar

- [ ] 1. **`functions/index.js` sonuna `fetchHtml()` yardımcı fonksiyonu ekle**

  Mevcut `fetchJson()` ile aynı yapı, fark: HTML string döndürür, JSON parse etmez,
  `Accept: text/html` header kullanır, timeout 25 saniye (Borsa İstanbul biraz yavaş olabilir).

  ```js
  function fetchHtml(url) {
    return new Promise((resolve, reject) => {
      const req = https.get(url, {
        headers: {
          'User-Agent': 'TeknikBakis-Backend/1.0',
          'Accept': 'text/html,application/xhtml+xml',
        },
        timeout: 25000,
      }, (res) => {
        let body = '';
        res.on('data', chunk => body += chunk);
        res.on('end', () => resolve(body));
      });
      req.on('error', reject);
      req.on('timeout', () => { req.destroy(); reject(new Error('fetchHtml Timeout: ' + url)); });
    });
  }
  ```

  Dosya: `functions/index.js`
  Doğrulama: Dosya syntax hatası içermemeli — `node --check functions/index.js` çalıştır ve
  çıktısı hata içermemeli.

---

- [ ] 2. **`functions/index.js` sonuna `findLatestBist100Announcement()` fonksiyonu ekle**

  Borsa İstanbul duyuru listesi sayfasını (`https://www.borsaistanbul.com/en/announcement`)
  çekip parse eden fonksiyon. İki kalıbı arar:
  - `bist-stock-indices-periodic-review`
  - `announces-constituent-changes-bist-stock-indices-`

  URL pattern: `/en/announcement/{id}/{slug}` — `id` nümerik.
  
  En yüksek id'li (yani en yeni) eşleşen duyuruyu döndürür:
  `{ announcementId, announcementUrl, announcementTitle, announcementDate }`.
  
  Duyuru bulunamazsa `null` döner (exception fırlatma, çünkü caller null'ı idempotent işler).

  Örnek HTML'de href pattern:
  ```
  href="/en/announcement/15598/bist-stock-indices-periodic-review"
  ```
  Regex: `/href="(\/en\/announcement\/(\d+)\/([^"]*(?:bist-stock-indices-periodic-review|announces-constituent-changes-bist-stock-indices-)[^"]*))"/gi`
  
  `announcementId` string olarak sakla (Firestore karşılaştırması için).

  Dosya: `functions/index.js`
  Doğrulama: `node --check functions/index.js` hata vermemeli.

---

- [ ] 3. **`functions/index.js` sonuna `parseBist100Announcement(html)` fonksiyonu ekle**

  Duyuru HTML'sini alır, BIST 100 bölümünü bulur ve şunları çıkarır:
  - `added`: BIST 100'e eklenen semboller listesi
  - `removed`: BIST 100'den çıkarılan semboller listesi
  - `alternates`: BIST 100 yedekleri listesi
  - `periodStart`: dönem başlangıcı string
  - `periodEnd`: dönem bitişi string
  - `revision`: dönem etiketi (örn. "2026-Q4")

  **Parse stratejisi** (doğrulanmış örnek duyuru üzerinde test edildi):

  Adım A — BIST 100 bölümünü bul:
  HTML içinde `BIST 100` başlığını içeren bölümü bul. Önce `<h2>`, `<h3>`, `<strong>`
  taglerinde `BIST 100` ara. Bulunan başlıktan sonraki HTML bloğunu al.

  Adım B — Tablo satırlarından sembol çıkar:
  `<td>` tagları içinde 2-6 büyük harf içeren kelimeleri sembol adayı say.
  Regex: `/\b([A-Z]{2,6})\b/g` — Türkçe özel karakter içermeyen, tümü büyük harf.
  
  **BIST100'e Alınanlar (added)** tablosunu bul: başlık olarak
  `Included|Added|Alınan|Eklenen` içeren bölüm.
  
  **BIST100'den Çıkarılanlar (removed)** tablosunu bul: başlık olarak
  `Excluded|Removed|Çıkarılan|Çıkan` içeren bölüm.
  
  **Yedekler (alternates)** tablosunu bul: başlık olarak
  `Alternate|Reserve|Yedek` içeren bölüm. Bulunamazsa `[]` dön — main akışı durdurma.

  Adım C — Dönem bilgisi çıkar:
  HTML içinde `01.0[1-9]` veya `30.` gibi tarih formatlarını ara.
  `Q1/Q2/Q3/Q4` ifadelerini veya Türkçe dönem adlarını ara.
  Bulunamazsa `""` döndür — main akışı durdurma.

  Fonksiyon imzası:
  ```js
  function parseBist100Announcement(html) {
    // returns { added, removed, alternates, periodStart, periodEnd, revision, bist100SectionFound }
  }
  ```
  `bist100SectionFound` boolean — validation adımında kullanılacak.

  Dosya: `functions/index.js`
  Doğrulama: `node --check functions/index.js` hata vermemeli.

---

- [ ] 4. **`functions/index.js` sonuna `validateBist100Update(params)` fonksiyonu ekle**

  Firestore'a yazmadan önce kritik kontrolleri yapan senkron fonksiyon.
  
  ```js
  function validateBist100Update({ bist100SectionFound, added, removed, currentSymbols, newSymbols }) {
    // returns { valid: boolean, reason: string }
  }
  ```

  Kontroller sırayla:
  1. `bist100SectionFound` false → `{ valid: false, reason: 'BIST100_SECTION_NOT_FOUND' }`
  2. `!Array.isArray(added)` → `{ valid: false, reason: 'ADDED_PARSE_FAILED' }`
  3. `!Array.isArray(removed)` → `{ valid: false, reason: 'REMOVED_PARSE_FAILED' }`
  4. `newSymbols.length === 0` → `{ valid: false, reason: 'SYMBOLS_EMPTY' }`
  5. `newSymbols.length !== 100` → `{ valid: false, reason: 'SYMBOL_COUNT_NOT_100:' + newSymbols.length }`
  6. Her sembol `/^[A-Z]{2,6}$/.test(sym)` kontrolü — başarısız olursa
     `{ valid: false, reason: 'INVALID_SYMBOL_FORMAT:' + badSym }`
  7. `added` ve `removed` kesişimi varsa
     `{ valid: false, reason: 'ADDED_REMOVED_OVERLAP:' + overlap.join(',') }`
  8. `Math.abs(added.length - removed.length) > 20` veya toplam değişim > 20 →
     `{ valid: false, reason: 'UNEXPECTED_LARGE_DIFF:' + added.length + '+' + removed.length }`
  9. `currentSymbols.length > 0 && currentSymbols.length !== 100` →
     warning log at (mevcut liste bozuk olabilir); bu durumda validation devam etsin —
     sadece `newSymbols.length !== 100` önemli.
  
  Tüm kontroller geçerse `{ valid: true, reason: '' }` döner.

  Dosya: `functions/index.js`
  Doğrulama: `node --check functions/index.js` hata vermemeli.

---

- [ ] 5. **`functions/index.js` sonuna `runBist100Sync(options)` core logic fonksiyonu ekle**

  Tüm adımları orkestre eden ana fonksiyon. `dryRun` parametresini destekler.

  ```js
  async function runBist100Sync({ dryRun = false } = {}) {
    // returns result object
  }
  ```

  Sırasıyla:

  **A. Log başlangıç**
  ```
  console.log('BIST100_SYNC_STARTED', new Date().toISOString());
  ```

  **B. Son duyuruyu bul**
  `findLatestBist100Announcement()` çağır.
  Hata → log `BIST100_FETCH_ERROR` + throw.
  `null` → log `BIST100_FETCH_ERROR: no_announcement_found` + throw.

  **C. Mevcut Firestore durumunu oku**
  `bist_index_meta/bist100` dokümanını `get()` ile çek.
  `currentAnnouncementId` = `doc.data()?.announcementId || null`
  `currentSymbols` = `doc.data()?.symbols || []` (normalize et: trim+uppercase)

  **D. Aynı duyuru kontrolü**
  ```js
  if (currentAnnouncementId && String(currentAnnouncementId) === String(announcementId)) {
    console.log(`BIST100_NO_CHANGE: announcement ${announcementId} already processed`);
    return { status: 'no_change', announcementId };
  }
  ```

  **E. Duyuru HTML'sini indir ve parse et**
  `fetchHtml(announcementUrl)` → `parseBist100Announcement(html)`
  Log: `BIST100_PARSE_SUCCESS: added=N, removed=N`
  Alternates parse başarısız → log ama devam et.

  **F. Yeni liste hesapla**
  ```js
  const currentSet = new Set(currentSymbols.map(s => s.trim().toUpperCase()).filter(Boolean));
  for (const sym of removed) currentSet.delete(sym.trim().toUpperCase());
  for (const sym of added)   currentSet.add(sym.trim().toUpperCase());
  const newSymbols = [...currentSet].sort();
  ```
  ÖNEMLİ: Eğer `currentSymbols` boş (ilk çalıştırma) VE `added` boş VE `removed` boş ise
  `newSymbols` de boş kalacak — bu validation'da yakalanacak.
  
  Eğer `currentSymbols` boş (Firestore hiç yazılmamış) ama `added` liste içeriyorsa:
  `newSymbols = added` (ilk kurulum senaryosu). Hala 100 sembol kontrolü geçmeli.

  **G. Validation**
  `validateBist100Update(...)` çağır.
  Başarısız → log `BIST100_VALIDATION_FAILED: {reason}` + throw (Firestore'a yazma).

  **H. dryRun kontrolü**
  `dryRun === true` ise Firestore yazma adımlarını atla, sadece `{ status: 'dry_run', ... }` dön.

  **I. Firestore'a yaz — `bist_index_meta/bist100`**
  ```js
  await db.collection('bist_index_meta').doc('bist100').set({
    symbols:           newSymbols,
    updatedAt:         FieldValue.serverTimestamp(),
    periodStart:       periodStart || '',
    periodEnd:         periodEnd   || '',
    source:            'Borsa Istanbul',
    announcementId:    String(announcementId),
    announcementUrl:   announcementUrl,
    announcementTitle: announcementTitle,
    added:             added,
    removed:           removed,
    alternates:        alternates,
    revision:          revision || '',
  });
  ```

  **J. `bist_stocks` güncelle**
  `added` listesindeki semboller için:
  - `bist_stocks/{symbol}` dokümanı var mı? → `merge: true` ile `{ bist100Member: true }` yaz.
  - Yok mu? → `kap_members` collection'ında `stockCode` eşleştir:
    ```js
    const kapSnap = await db.collection('kap_members')
      .where('stockCode', '==', symbol).limit(1).get();
    const name = kapSnap.empty ? symbol : (kapSnap.docs[0].data().title || symbol);
    ```
    `{ symbol, name, active: true, bist100Member: true }` yaz (yeni doküman).
  
  `removed` listesindeki semboller için:
  - `bist_stocks/{symbol}` dokümanı varsa → `{ bist100Member: false }` yaz (merge: true).
  - **`active` alanına HİÇBİR KOŞULDA dokunma.**
  - Yoksa → log et, geç.

  Tüm `bist_stocks` yazmaları tek `db.batch()` içinde yap (500 limit aşılmazsa — max ~20 sembol değişimi var, güvenli).

  **K. Log tamamlanma**
  ```
  console.log(`BIST100_UPDATED: ${newSymbols.length} symbols, added=[${added}], removed=[${removed}]`);
  ```
  Return: `{ status: 'updated', symbolCount: newSymbols.length, added, removed, announcementId }`

  Dosya: `functions/index.js`
  Doğrulama: `node --check functions/index.js` hata vermemeli.

---

- [ ] 6. **`functions/index.js` sonuna `exports.syncBist100Index` ve `exports.syncBist100Manual` ekle**

  **syncBist100Index** — Haftalık scheduler:
  ```js
  exports.syncBist100Index = onSchedule({
    schedule:       '0 5 * * 1',   // Her Pazartesi 05:00 UTC
    timeZone:       'UTC',
    region:         'europe-west1',
    memory:         '512MiB',
    timeoutSeconds: 300,
    secrets:        [ADMIN_SECRET],
  }, async () => {
    await runBist100Sync({ dryRun: false });
  });
  ```
  Not: Bu fonksiyon Borsa İstanbul'a bağlanıyor, KAP API veya ADMIN_SECRET kullanmıyor.
  Ancak `secrets: [ADMIN_SECRET]` zaten tanımlı secret'ı referans eder — bu deploy için gerekli
  değil ama mevcut pattern'e uyum için bırakılabilir. Daha temiz seçenek: `secrets: []`.
  **Kesin karar:** `secrets: []` kullan — gereksiz secret bağımlılığı olmasın.
  Region ve memory mevcut fonksiyonlarla aynı.

  **syncBist100Manual** — Admin korumalı HTTP endpoint:
  ```js
  exports.syncBist100Manual = onRequest({
    region:         'europe-west1',
    memory:         '512MiB',
    timeoutSeconds: 300,
    secrets:        [ADMIN_SECRET],
  }, async (req, res) => {
    const adminSecret = ADMIN_SECRET.value().trim();
    const provided    = (req.headers['x-admin-secret'] || req.query.secret || '').trim();
    if (!adminSecret || provided !== adminSecret) {
      res.status(403).json({ error: 'Unauthorized' });
      return;
    }
    const dryRun = req.query.dryRun === 'true' || req.query.dryRun === '1';
    try {
      const result = await runBist100Sync({ dryRun });
      res.json({ success: true, dryRun, ...result });
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  });
  ```

  Dosya: `functions/index.js`
  Doğrulama: `node --check functions/index.js` hata vermemeli.
  Deploy için: `firebase deploy --only functions:syncBist100Index,functions:syncBist100Manual`
  (sadece yeni fonksiyonları deploy eder, mevcut fonksiyonlara dokunmaz).

---

- [ ] 7. **`firestore.rules` dosyasına iki yeni collection rule ekle**

  Dosyanın son `}` (service bloğunun kapanışı) öncesine ekle:
  ```
  // ── BIST Hisse Listesi (Cloud Function yazar, uygulama okur) ─────────
  match /bist_stocks/{symbol} {
    allow read:  if true;
    allow write: if false;
  }

  // ── BIST Endeks Meta (Cloud Function yazar, uygulama okur) ───────────
  match /bist_index_meta/{docId} {
    allow read:  if true;
    allow write: if false;
  }
  ```

  Dosya: `firestore.rules`
  Doğrulama: `firebase firestore:rules:test` veya `firebase emulators:start --only firestore`
  ile syntax kontrol edilebilir. En hızlı: dosyayı gözle incele — mevcut pattern'e uyuyor mu?
  (`node --check` burada geçerli değil, rules dosyası JS değil.)

---

## Önemli Kısıtlamalar (Implementer'a hatırlatma)

1. `fetchJson()` dosyada iki kez tanımlı — `fetchHtml()` üçüncü bir tekrar YARATMA.
   `fetchHtml()` sadece bir kez, dosyanın SONUNDA tanımla.

2. `currentSymbols` Firestore'da boş olabilir (ilk çalıştırma).
   Bu durumda `removed` listesi boş olacak, `added` listesi de boş olacak (duyuru sadece
   mevcut liste değişikliklerini içeriyor). Dolayısıyla `newSymbols` boş kalır → validation
   `SYMBOL_COUNT_NOT_100` ile reddeder. Bu beklenen davranış.
   **İLK KURULUM İÇİN:** Birinci çalıştırmada Firestore'da mevcut liste varsa (hardcoded
   `kBist100Symbols` listesi elle Firestore'a yüklenmiş), sonraki duyurular delta olarak
   uygulanır. İlk yükleme için `syncBist100Manual` ile `dryRun=false` çağır ve parse sonucunu
   incele.

3. `alternates` parse başarısız olursa `[]` döndür, `main sync'i engelleme`.
   Task description'da açıkça belirtilmiş.

4. `bist_stocks` güncelleme sırasında `active` / `isActive` alanına **asla** dokunma.
   Sadece `bist100Member: true/false` yaz.

5. `symbols` alanına `alternates` EKLEME. Sadece gerçek üyeler `symbols` içinde.

6. Validation `newSymbols.length !== 100` kontrolünde başarısız olursa
   Firestore'a **hiçbir şey yazılmaz** (hem `bist_index_meta` hem `bist_stocks`).

---

## Deploy Sırası

1. `node --check functions/index.js` — syntax kontrol
2. `firebase deploy --only functions:syncBist100Index,functions:syncBist100Manual`
3. `firebase deploy --only firestore:rules`
4. Manuel test: `syncBist100Manual?dryRun=true&secret=...` ile parse sonucunu gözle incele
5. Gerçek yazma: `syncBist100Manual?dryRun=false&secret=...`

---

## Log Referansı

| Log Mesajı | Anlamı |
|---|---|
| `BIST100_SYNC_STARTED` | Fonksiyon başladı |
| `BIST100_ANNOUNCEMENT_FOUND: {id} - {title}` | Duyuru bulundu |
| `BIST100_NO_CHANGE: announcement {id} already processed` | Yeni duyuru yok, erken çıkış |
| `BIST100_FETCH_ERROR: ...` | HTTP veya parse hatası |
| `BIST100_PARSE_SUCCESS: added=N, removed=N` | Duyuru parse edildi |
| `BIST100_VALIDATION_FAILED: {reason}` | Validation başarısız, Firestore'a yazılmadı |
| `BIST100_UPDATED: N symbols, added=[...], removed=[...]` | Başarıyla güncellendi |
