# Uygulama Planı — Halka Arz Durum Belirleme Hatası Düzeltmesi

Dosya: `functions/index.js`
Tarih: 2026-10-04

---

## Keşif Özeti

Kod okunduktan sonra tespit edilen gerçek durum:

**Hata 1 — Sıra sorunu (reconcile → overwrite):**
`syncIpoFeed` şu akışı izliyor:
1. `reconcileStaleIpoStatuses()` → Firestore'daki eski kayıtları `trading` yapar.
2. `fetchHalkArzItems()` → HalkArz'dan veri çeker; her hisse için `deriveIpoStatus()` çağırır.
3. `writeIpoToFirestore(items)` → `{ merge: true }` ile yazar ama `status` alanını **koşulsuz** üzerine yazar.

Sonuç: Adım 1'de `trading` yapılan kayıt, adım 3'te HalkArz'dan gelen `upcoming` veya `pending_listing` değeriyle ezilir. `reconcile` adımı fiilen etkisiz kalır.

**Hata 2 — BIST varlık kontrolü yok:**
`deriveIpoStatus()` fonksiyonu yalnızca `requestStart`, `requestEnd`, `listingDate` parametrelerine bakar. `listingDate` HalkArz sayfasında yoksa ve `requestEnd` geçmişse sonuç her zaman `pending_listing` döner; hissenin BIST'te gerçekten işlem görüp görmediğine bakılmaz.

**BIST hisse listesi kaynağı:**
- `bist_stocks/{SYMBOL}` koleksiyonu — tüm BIST hisselerini içerir (~610 sembol). En kapsamlı kaynak.
- `bist_index_meta/bist100.symbols` — sadece BIST100 (100 sembol). IPO için yeterli değil; yeni halka arzlar önce küçük endekslerde işlem görür.
- Doğru kaynak: **`bist_stocks` koleksiyonu** (veya sembol varsa `bist_index_meta/bist100.symbols` içinde arama — daha az Firestore okuması).

**`writeIpoToFirestore` PRI mantığı:**
Fonksiyon kendi içinde aynı sembollü iki kayıt arasında `PRI: {trading:4, pending_listing:3, ...}` önceliği uygular, ancak Firestore'daki **mevcut** kaydı okumadan `merge:true` ile yazar. Yani Firestore'da `trading` olan kaydın üzerine `upcoming` yazılır.

---

## İstenen Davranış

```
1. Symbol BIST'te listelenmiş mi?   → trading
2. listingDate < now?               → trading
3. applicationEndDate < now?        → pending_listing
4. Aksi hâlde                       → upcoming (veya collecting)
```

Ek kural: Firestore'da zaten `trading` olan kayıt, HalkArz'dan `upcoming` / `pending_listing` gelse bile **`trading` kalır**.

---

## Plan

- [ ] **1. `deriveIpoStatus` → `computeIpoStatus` olarak yeniden yaz**

  `functions/index.js` içindeki `deriveIpoStatus` fonksiyonunu, BIST sembol listesini parametre olarak alan `computeIpoStatus` ile değiştir. Fonksiyon imzası:

  ```js
  function computeIpoStatus({ requestStart, requestEnd, listingDate, symbol, bistSymbols })
  ```

  - `bistSymbols`: `Set<string>` — Firestore'dan önceden çekilmiş BIST sembol kümesi.
  - Öncelik sırası (tam olarak aşağıdaki if-else zinciri):
    1. `symbol && bistSymbols.has(symbol.toUpperCase())` → `'trading'`
    2. `listingDate && listingDate <= now` → `'trading'`
    3. `requestEnd && now > endOfDay(requestEnd)` → `'pending_listing'`
    4. `requestStart && now >= startOfDay(requestStart)` → `'collecting'`
    5. Aksi hâlde → `'upcoming'`
  - `collecting` durumu: mevcut `deriveIpoStatus`'ta vardı, korunmalı (talep hâlâ devam ediyor).
  - Eski `deriveIpoStatus` adını **kaldır** (başka yerde kullanılmıyor — grep ile teyit et).

  **Değiştirilecek dosya:** `functions/index.js`

  **Doğrulama:** `node -e "const f = require('./index.js')"` sözdizim hatası vermeden çalışmalı.
  (`firebase emulators:start` gerektirmez; sadece parse kontrolü yeterli.)

---

- [ ] **2. `fetchHalkArzItems` çağrısını BIST sembol kümesi ile destekle**

  `fetchHalkArzItems()` içinde tek nokta `fetchIpoDetail` sonunda `deriveIpoStatus` çağrısı var.
  Fonksiyon imzasını `fetchHalkArzItems(bistSymbols)` şekline getir ve içindeki
  iki `deriveIpoStatus(...)` çağrısını `computeIpoStatus({ ..., bistSymbols })` ile değiştir:

  - `fetchIpoDetail(item)` içindeki çağrı (satır ~892)
  - `catch` bloğundaki fallback çağrısı (satır ~933)

  `fetchIpoDetail` ayrıca `bistSymbols` parametresine ihtiyaç duyduğundan, ya
  `fetchIpoDetail(item, bistSymbols)` yap ya da `bistSymbols`'ü closure üzerinden aktar
  (daha az değişiklik: `fetchHalkArzItems` içinde `bistSymbols`'ü tanımla, `fetchIpoDetail`'e de parametre ekle).

  **Değiştirilecek dosya:** `functions/index.js`

  **Doğrulama:** Adım 1 ile birlikte `node -e "require('./index.js')"` hatası olmadan bitmeli.

---

- [ ] **3. BIST sembol kümesini Firestore'dan çeken yardımcı fonksiyon yaz**

  ```js
  async function loadBistSymbols() { ... }
  ```

  - `bist_stocks` koleksiyonundaki tüm doküman ID'lerini (sembol) okur.
  - Büyük koleksiyon okumaktan kaçınmak için `.select()` ya da sadece `.get()` ile doc ID'leri topla (Firestore `.listDocuments()` daha verimli ama Firebase Admin v12'de mevcut).
  - Öneri: `db.collection('bist_stocks').listDocuments()` — her dokümanın sadece ID'sini döndürür, tüm alanları çekmez. Bu yaklaşım ~610 docRef için minimal okuma yapar.
  - Alternatif (listDocuments yoksa): `.get()` ile snapshot alıp `snapshot.docs.map(d => d.id)`.
  - Sonuç olarak `Set<string>` (büyük harf semboller) döndür.
  - Hata durumunda: `console.warn` yaz, boş `Set` döndür (BIST kontrolü devre dışı kalır, diğer mantık çalışmaya devam eder).

  **Değiştirilecek dosya:** `functions/index.js` (yeni fonksiyon, IPO bölümüne ekle)

  **Doğrulama:** Sözdizim kontrolü yeterli; Firestore bağlantısı emülatör olmadan test edilemez.

---

- [ ] **4. `syncIpoFeed` akışını düzelt — doğru sıralama**

  Mevcut akış:
  ```
  reconcileStaleIpoStatuses()   ← 1. düzelt
  fetchHalkArzItems()           ← 2. çek (status bozuluyor)
  writeIpoToFirestore(items)    ← 3. yaz (reconcile etkisiz kalıyor)
  ```

  Yeni akış:
  ```
  bistSymbols = await loadBistSymbols()   ← 1. BIST setini çek
  items = await fetchHalkArzItems(bistSymbols)  ← 2. HalkArz (BIST kontrolüyle)
  count = await writeIpoToFirestore(items, bistSymbols)  ← 3. yaz (geriye dönüş korumalı)
  reconcileStaleIpoStatuses(bistSymbols)  ← 4. sonunda reconcile (artık bozulmaz)
  ```

  > `reconcile` adımı yazma işleminin SONUNA alınır. Bu sayede HalkArz'ın yanlış statüsü
  > Firestore'a yazıldıktan hemen sonra reconcile tarafından düzeltilir — ve üzerine yazma
  > olmadığı için düzeltme kalıcı olur.

  `syncIpoFeed` ve `syncIpoManual` export'larının her ikisinde de bu sıra uygulanmalı.

  **Değiştirilecek dosya:** `functions/index.js` — `exports.syncIpoFeed` ve `exports.syncIpoManual`

  **Doğrulama:** `node -e "require('./index.js')"` sözdizim hatası vermemeli.

---

- [ ] **5. `writeIpoToFirestore`'a "trading koruma" ekle**

  Şu an `batch.set(..., { merge: true })` tüm alanları üzerine yazıyor.
  `status` alanının üzerine yazılmadan önce Firestore'daki mevcut değer kontrol edilmeli.

  **Yaklaşım — transaction yerine "mevcut trading'i koru" mantığı:**

  `writeIpoToFirestore` fonksiyonuna `bistSymbols` parametresini ekle.
  Batch yazmadan önce tüm hedef dokümanları tek seferde oku (paralel `getAll` veya ayrı `get`'ler):

  ```js
  async function writeIpoToFirestore(items, bistSymbols) {
    ...
    // Dedupe + entries hesaplaması aynı kalır
    ...
    // Mevcut Firestore durumlarını oku
    const refs = entries.map(([docId]) => db.collection('ipo_items').doc(docId));
    const existingSnaps = await db.getAll(...refs);  // tek round-trip
    const existingStatuses = new Map(
      existingSnaps.map(snap => [snap.id, snap.exists ? snap.data().status : null])
    );

    // Batch yaz
    for (const [docId, item] of entries) {
      const existingStatus = existingStatuses.get(docId);
      let finalStatus = item.status;

      // Kural: Firestore'da trading varsa trading'i koru
      if (existingStatus === 'trading') {
        finalStatus = 'trading';
      }
      // Kural: BIST'te varsa trading yap (loadBistSymbols zaten bunu computeIpoStatus'ta yapar,
      // ama çift güvenlik olarak burada da kontrol et)
      if (item.symbol && bistSymbols.has(item.symbol.toUpperCase())) {
        finalStatus = 'trading';
      }

      batch.set(ref, { ...item, status: finalStatus, updatedAt: ... }, { merge: true });
    }
  }
  ```

  > Not: `db.getAll(...refs)` Firebase Admin SDK'da mevcuttur. 500'den fazla doküman için
  > chunk'lara böl (mevcut batch mantığı gibi 400'lük gruplar).

  **Değiştirilecek dosya:** `functions/index.js` — `writeIpoToFirestore` fonksiyonu

  **Doğrulama:** `node -e "require('./index.js')"` sözdizim hatası vermemeli.

---

- [ ] **6. `reconcileStaleIpoStatuses`'ı BIST kontrolüyle güçlendir**

  Mevcut fonksiyon yalnızca `listingDate` ve `requestEnd`'e bakıyor; BIST varlık kontrolü yok.
  Fonksiyon imzasını `reconcileStaleIpoStatuses(bistSymbols)` yap.

  Mevcut döngüye şu koşulu **en üste** ekle:

  ```js
  // BIST'te listelenmiş hisse → trading
  if (d.symbol && bistSymbols.has(d.symbol.toUpperCase()) && d.status !== 'trading') {
    stale.push({ ref: doc.ref, status: 'trading' });
    continue;
  }
  ```

  Mevcut `listingDate` ve `requestEnd` kontrolleri olduğu gibi kalır — bu kontrol sadece en üste eklenir.

  **Değiştirilecek dosya:** `functions/index.js` — `reconcileStaleIpoStatuses` fonksiyonu

  **Doğrulama:** `node -e "require('./index.js')"` sözdizim hatası vermemeli.

---

- [ ] **7. Bütünleşik sözdizim + mantık doğrulaması**

  Tüm değişiklikler tamamlandıktan sonra:

  ```bash
  cd functions
  node -e "require('./index.js')" && echo "SYNTAX OK"
  ```

  Bu komut Firebase Functions modüllerini import etmeye çalışır; `initializeApp()` ortam yoksa hata verebilir.
  Alternatif olarak salt sözdizim kontrolü:

  ```bash
  node --check functions/index.js && echo "SYNTAX OK"
  ```

  Beklenen çıktı: `SYNTAX OK` — herhangi bir `SyntaxError` olmamalı.

---

- [ ] **8. Flutter testlerini çalıştır (regresyon kontrolü)**

  Flutter tarafındaki `IpoItem` modeli ve `bist_stocks.dart` servisi değişmiyor.
  Mevcut testlerin hâlâ geçtiğini doğrula:

  ```bash
  flutter test test/ipo_logic_test.dart --reporter compact
  ```

  Beklenen: tüm testler yeşil. (Bu testler Flutter/Dart mantığını test ediyor; Cloud Functions değişikliği bunları etkilemez, ancak regresyon olmadığını teyit eder.)

---

## Önemli Kısıtlamalar (DOKUNULMAYACAK)

Aşağıdaki kod bölgelerine hiçbir şekilde değişiklik yapılmayacak:

- `exports.syncKapDisclosures`, `exports.syncKapOpeningWindow` — KAP/Haberler kodu
- `exports.analyzeTechnicals` — NVIDIA NIM proxy
- `exports.verifyGooglePurchase`, `exports.validateSubscription` — Google Play Billing
- `pubspec.yaml` içindeki `in_app_purchase` sürümü
- Android Billing Library (`android/app/build.gradle.kts`)
- `exports.syncBist100Index`, `exports.syncBist100Manual` — BIST100 sync (halka arz değil)

---

## Kısaca Değişen Şeyler

| Fonksiyon | Değişiklik |
|---|---|
| `deriveIpoStatus` | Silinir, yerine `computeIpoStatus(bistSymbols)` gelir |
| `fetchHalkArzItems` | `bistSymbols` parametresi alır |
| `fetchIpoDetail` | `bistSymbols` parametresi alır |
| `loadBistSymbols` | Yeni fonksiyon — Firestore `bist_stocks` doküman ID'lerini Set olarak döndürür |
| `writeIpoToFirestore` | `bistSymbols` parametresi alır; mevcut `trading` kaydı korunur |
| `reconcileStaleIpoStatuses` | `bistSymbols` parametresi alır; BIST kontrolü en üste eklenir |
| `syncIpoFeed` (export) | Yeni akış: loadBistSymbols → fetchHalkArz → write → reconcile |
| `syncIpoManual` (export) | Aynı yeni akış uygulanır |
