# IPO / BIST Kod Analiz Raporu

**Tarih:** 2026-10-05  
**Kapsam:** `functions/index.js`, `lib/services/bist_stocks.dart`, `lib/services/bist100_service.dart`  
**Yöntem:** Salt okunur kaynak kodu ve git geçmişi incelemesi. Hiçbir dosya değiştirilmedi.

---

## ÖZET (Önce Yanıtlar)

| Soru | Kısa Yanıt |
|------|-----------|
| `write → reconcile` sırası var mı? | **Evet — yerelde var, canlıda YOK** |
| `syncIpoManual` ne çağırıyor? | Yerelde: `loadBistSymbols` → `fetchHalkArzItems` → `writeIpoToFirestore` → `reconcileStaleIpoStatuses`. Canlıda: sadece `fetchHalkArzItems` → `writeIpoToFirestore` |
| Canlı kod güncel mi? | **HAYIR. Yerel HEAD, `origin/main`'den 7 commit öndedir; canlı versiyon eski.** |
| `bist_stocks` neden boş/eksik? | Koleksiyona ilk veri yazan kod hiç çalıştırılmamış. Mevcut kod sadece BIST100 değişikliği duyurusu gelince `added` sembollerini yazar. |
| `bist_stocks.dart` Firestore'a yazıyor mu? | **HAYIR. Dart dosyası yalnızca okuma/in-memory merge yapar.** |

---

## 1. `syncIpoFeed` ve `reconcileStaleIpoStatuses` — `write → reconcile` Sırası

### Yerel `HEAD` (commit `89b8d5a`)

`functions/index.js` satır 1131–1155:

```
exports.syncIpoFeed = onSchedule({
  schedule: '0 */6 * * *',
  ...
}, async () => {
  // 1. BIST sembol kümesini çek
  const bistSymbols = await loadBistSymbols();
  // 2. HalkArz'dan veriyi çek (bistSymbols ile)
  const items = await fetchHalkArzItems(bistSymbols);
  if (!items.length) { ... return; }
  // 3. Yaz (trading korumalı)
  const count = await writeIpoToFirestore(items, bistSymbols);
  // 4. Reconcile — HalkArz'ın üzerine yazmasından SONRA uygula
  const reconciled = await reconcileStaleIpoStatuses(bistSymbols);
});
```

**`write → reconcile` sırası yerelde MEVCUT ve doğru.** Kod yorumunda da açıkça belirtilmiş: `"HalkArz'ın üzerine yazmasından sonra uygula (kalıcı olur)"`.

### Canlı `origin/main` (commit `bca6aca`)

`git show origin/main:functions/index.js` çıktısından elde edilen `syncIpoFeed` gövdesi:

```
exports.syncIpoFeed = onSchedule({...}, async () => {
  const items = await fetchHalkArzItems();          // bistSymbols parametresi YOK
  if (!items.length) { ... return; }
  const count = await writeIpoToFirestore(items);   // bistSymbols parametresi YOK
  // reconcile çağrısı TAMAMEN YOKTUR
});
```

Ayrıca `origin/main` üzerinde şu fonksiyonların **hiçbiri bulunmuyor**:
- `loadBistSymbols()` — yok
- `reconcileStaleIpoStatuses()` — yok  
- `bistSymbols` parametresi — yok
- `bist_stocks` koleksiyon referansı — yok

---

## 2. `syncIpoManual` — Hangi Fonksiyonları Çağırıyor?

### Yerel kod (`functions/index.js` satır 1157–1178):

```javascript
exports.syncIpoManual = onRequest({
  region: 'europe-west1',
  memory: '512MiB',
  timeoutSeconds: 300,
  secrets: [ADMIN_SECRET],
}, async (req, res) => {
  // Admin doğrulama
  const secret = ADMIN_SECRET.value().trim();
  ...
  // 1. BIST sembol kümesini çek
  const bistSymbols = await loadBistSymbols();
  // 2. HalkArz'dan veriyi çek
  const items = await fetchHalkArzItems(bistSymbols);
  // 3. Yaz
  const count = await writeIpoToFirestore(items, bistSymbols);
  // 4. Reconcile — yazmadan SONRA uygula
  const reconciled = await reconcileStaleIpoStatuses(bistSymbols);
  res.json({ success: true, count, reconciled });
});
```

Çağrı sırası: `loadBistSymbols` → `fetchHalkArzItems(bistSymbols)` → `writeIpoToFirestore(items, bistSymbols)` → `reconcileStaleIpoStatuses(bistSymbols)`

### Canlı kod (`origin/main`):

```javascript
exports.syncIpoManual = onRequest({...}, async (req, res) => {
  const items = await fetchHalkArzItems();
  const count = await writeIpoToFirestore(items);
  res.json({ success: true, count });
  // reconcile YOKTUR
});
```

---

## 3. Canlıya Deploy Edilmiş Kodun Güncelliği

### Git durumu

```
Yerel HEAD:     89b8d5a  (fix(ipo): BIST kontrolü ve trading koruma — ...)
origin/main:    bca6aca  (chore: update ipo feed)
```

Yerel `main`, `origin/main`'den **7 commit önde**:

```
89b8d5a  fix(ipo): BIST kontrolü ve trading koruma
8700fa2  feat: 19 yeni BIST hissesi eklendi
6c376e8  chore: agent görev dosyaları
e90663f  chore: uygulama son hali
7a1447c  fix: halka arz tarih bazlı sınıflandırma
bed1913  fix: halka arz convergence fixes
0979985  fix: halka arz convergence fixes
```

`functions/index.js` yerel ve uzak arasında **150 satır fark** var (`git diff --stat` çıktısı: `150 ++++, 28 ----`).

### Sonuç

Firebase Cloud Functions `firebase deploy` komutu GitHub push'a bağlı değil; manuel tetiklenir. `origin/main`, en son yerel `main`'den çok geride kaldığından:

- **Canlıda çalışan kod `bca6aca` sürümüdür.**  
- Bu sürümde `loadBistSymbols`, `reconcileStaleIpoStatuses`, `bistSymbols` destekli `writeIpoToFirestore` **hiçbiri yoktur.**

> Not: Firebase Console üzerinden deploy geçmişi bu araçlarla doğrulanamaz; yukarıdaki analiz git geçmişine dayanmaktadır. Firebase CLI `firebase functions:list` ile canlı fonksiyon sürümü doğrulanabilir.

---

## 4. `bist_stocks` Koleksiyonu Neden Boş/Eksik?

### Koleksiyona veri yazacak tek kod: `runBist100Sync`

`functions/index.js` satır 2279–2340'ta `runBist100Sync` fonksiyonu, `syncBist100Index` (her Pazartesi 05:00 UTC) ve `syncBist100Manual` tetikleyicileriyle çalışır.

Bu fonksiyon `bist_stocks` koleksiyonuna yalnızca şu koşulda yazar:

```javascript
// Sadece Borsa İstanbul duyurusundaki "added" semboller için:
for (const sym of added) {
  const stockRef = db.collection('bist_stocks').doc(symbol);
  if (stockDoc && stockDoc.exists) {
    batch.set(stockRef, { bist100Member: true }, { merge: true }); // GÜNCELLEME
  } else {
    batch.set(stockRef, { symbol, name, active: true, bist100Member: true }); // YENİ KAYIT
  }
}
// Çıkarılanlar için sadece bist100Member: false — active'e dokunulmaz:
for (const sym of removed) {
  if (stockDoc && stockDoc.exists) {
    batch.set(stockRef, { bist100Member: false }, { merge: true });
  } else {
    // Belge yoksa ATLANIYOR — yeni kayıt oluşturulmaz
  }
}
```

### Boşluk nedenleri (kod üzerinden tespit)

1. **İlk toplu yükleme (bootstrap) hiç yapılmamış olabilir.**  
   `bist_stocks` koleksiyonu, `syncBist100Manual?bootstrap=true` endpoint'i ile tohumlanabilir. Bu endpoint Firestore'da `>=50` sembol içeren bir kayıt varsa reddeder. Koleksiyon boşsa bootstrap çalıştırılmış ama sonraki sorgular başarısız olmuşsa ya da henüz hiç çalıştırılmamışsa koleksiyon boş kalır.

2. **BIST100 duyuru parser'ı yeni semboller bulmadıkça yeni kayıt eklemez.**  
   Haftalık `syncBist100Index` yalnızca "eklenen" semboller için yeni doküman açar. Tüm `~610` BIST hissesini baştan yazmaz. 

3. **Canlı `syncIpoFeed`'in eski sürümü `bist_stocks`'a hiç bakmıyor.**  
   `origin/main`'deki `writeIpoToFirestore(items)` imzasında `bistSymbols` yok; koleksiyon okunmuyor bile. BIST kontrolüne dayanan `trading` statüsü canlıda çalışmıyor.

4. **`loadBistSymbols` canlıda yok**, dolayısıyla `bist_stocks` koleksiyonu IPO sync'e katkı sağlamıyor.

### Hangi fonksiyon, hangi koşulda yazıyor?

| Fonksiyon | Koşul | Ne Yazar |
|-----------|-------|----------|
| `runBist100Sync` → `syncBist100Index` | Her Pazartesi 05:00 UTC, Borsa İstanbul yeni duyuru varsa | Sadece `added[]` sembolleri — tam liste değil |
| `runBist100Sync` → `syncBist100Manual?bootstrap=true` | Manuel tetik + koleksiyon boşken | Bootstrap listesi (hardcoded 100 sembol) |
| `syncIpoFeed` / `syncIpoManual` (yerel) | Her 6 saatte bir / manuel — ama bu sürüm **canlıda yok** | Yok (okur, yazmaz) |
| `syncIpoFeed` / `syncIpoManual` (canlı) | Her 6 saatte bir / manuel | `bist_stocks`'a **hiç dokunmuyor** |

---

## 5. `lib/services/bist_stocks.dart` — Firestore'a Yazma Var Mı?

**Hayır.** `bist_stocks.dart` Dart dosyası tamamen istemci tarafı / in-memory bir kütüphanedir:

- `_baseBistStocks` — ~610 hissenin sabit kodlu listesi (const)  
- `kBistStocks` — runtime'da güncellenen mutable liste  
- `syncBistStocksFromFirestore({firestoreStocks, firestoreBist100})` — Firestore'dan okunan veriyle `kBistStocks`'u in-memory merge eder  
- `syncBistStocksWithIpoItems(ipoItems)` — IPO kayıtlarını in-memory listede birleştirir  

Dosyada `FirebaseFirestore`, `.collection(`, `.set(`, `.update(`, `.add(` gibi yazma işlemlerine ait **tek bir satır bile yok.**

### `bist100_service.dart` akışı (okuma tarafı)

`lib/services/bist100_service.dart` şu sırayla çalışır:

1. Firestore `bist_index_meta/bist100` dokümanından BIST 100 sembol listesini çeker  
2. Firestore `bist_stocks` koleksiyonunu `where('active', isNotEqualTo: false)` filtresiyle çeker  
3. İki kaynak da boşsa işlem yapmaz (fallback olarak `_baseBistStocks` sabit listesi kalır)  
4. Veri varsa `syncBistStocksFromFirestore(...)` ile in-memory birleştirme yapar  

Flutter uygulaması `bist_stocks` koleksiyonuna **hiçbir zaman yazmaz**, yalnızca okur.

---

## Sonuçlar ve Öneriler

### Kritik Sorun: Deploy Edilmemiş Kod

Yerel `main` branch'inde `loadBistSymbols`, `reconcileStaleIpoStatuses` ve `bistSymbols` destekli IPO sync kodu mevcuttur. Ancak bu kod **canlıya deploy edilmemiştir**. `origin/main` (canlı temel) eski sürümü içermektedir.

**Önerilen aksiyon:** `firebase deploy --only functions` ile yereldeki `index.js`'i canlıya alın. (Bu rapor kapsamı dışında — değişiklik yapmıyorum.)

### `bist_stocks` Koleksiyonu Nasıl Doldurulur?

Bootstrap endpoint'i mevcuttur ve tek seferlik çalıştırılabilir:

```
GET https://europe-west1-teknik-bakis.cloudfunctions.net/syncBist100Manual
    ?bootstrap=true&secret=<ADMIN_SECRET>
```

Bu, `BIST100_OCT2026` hardcoded listesindeki 100 sembolü `bist_stocks`'a yazar. Sonrasında haftalık `syncBist100Index` duyuru bazlı güncellemeleri devam ettirir.

> Dikkat: Bootstrap, koleksiyonda `>=50` doküman varsa reddeder. Önce koleksiyonun gerçek durumu kontrol edilmelidir.

### Özet Akış (Yerel — Doğru Versiyon)

```
syncIpoFeed / syncIpoManual
  │
  ├─ 1. loadBistSymbols()
  │       └─ bist_stocks koleksiyonunu okur → Set<String>
  │
  ├─ 2. fetchHalkArzItems(bistSymbols)
  │       └─ computeIpoStatus(..., bistSymbols) → BIST kontrolüyle durum atar
  │
  ├─ 3. writeIpoToFirestore(items, bistSymbols)
  │       └─ ipo_items/{symbol} dokümanlarını yazar
  │          trading koruması: Firestore'da trading varsa HalkArz'ın üstüne yazmaz
  │
  └─ 4. reconcileStaleIpoStatuses(bistSymbols)
          └─ ipo_items tamamını tarar
             listingDate geçmişse → trading
             BIST'te varsa → trading
             requestEnd geçmişse → pending_listing
```

**`write → reconcile` sırası yerelde mevcuttur, doğrudur, ve canlıya deploy edilmemiştir.**
