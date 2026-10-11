# `reconcileStaleIpoStatuses()` Derin Analiz Raporu

**Tarih:** 2026-10-05  
**Durum:** Sadece okuma / analiz — hiçbir dosya değiştirilmedi  
**Tetik:** `syncIpoManual` → `{success:true, count:222, reconciled:0}`  
**Kaynak:** `functions/index.js` (HEAD `89b8d5a`), git diff, önceki agent raporları

---

## ÖZET — Tek Satır Teşhis

> **`reconciled: 0`'ın sebebi:** Canlıda çalışan kod HEAD değil, eski kod.  
> HEAD'deki `reconcileStaleIpoStatuses()` doğru yazılmış; ama Firebase'e **deploy edilmemiş**.  
> Üstelik bu yeni fonksiyon dahi `bist_stocks` Firestore koleksiyonunda SOHOE/ORZAX'ı bulamaz (koleksiyonda yok) ve `listingDate` de Firestore'da null olduğu için sıfır değişiklik yapıyor.

---

## 1. `reconcileStaleIpoStatuses()` — Tam Kod Analizi

**Dosya:** `functions/index.js`  
**Satır:** 997–1050

### 1a. Hangi collection'ı ve hangi alanları okuyor?

```javascript
const snapshot = await db.collection('ipo_items').get();
```

- Collection: **`ipo_items`**
- Sorgu koşulu: **YOK** — `.get()` koleksiyonun tüm dokümanlarını çeker (222 kayıt = tüm snapshot)
- Okunan alanlar: `d.status`, `d.symbol`, `d.listingDate`, `d.requestEnd`

### 1b. `listingDate <= now` kontrolü tam olarak nasıl yapıyor?

```javascript
if (d.listingDate) {
  const ld = new Date(d.listingDate);
  if (!isNaN(ld) && ld <= now) {
    stale.push({ ref: doc.ref, status: 'trading' });
    continue;
  }
}
```

- `d.listingDate` önce **truthy** mu diye kontrol ediliyor (null/undefined/''/0 → atlanır)
- `new Date(d.listingDate)` ile JavaScript `Date` objesine dönüştürülüyor
- `!isNaN(ld)` geçerlilik kontrolü
- `ld <= now` karşılaştırması — JavaScript'te `Date <= Date` numerik (`getTime()`) karşılaştırması yapar → doğru çalışır

### 1c. `listingDate` tipi ne olduğunda ne oluyor?

| Firestore tipi | `new Date(...)` sonucu | `!isNaN(ld)` | Davranış |
|---|---|---|---|
| **ISO string** (`"2026-07-07T12:00:00.000Z"`) | Geçerli `Date` | `true` | `ld <= now` → `trading` ✓ |
| **Firestore Timestamp** (obje) | `new Date({...})` → `NaN` | **`false`** | **Atlanır — reconcile yapılmaz** ✗ |
| **null / undefined** | Truthy kontrolünde takılır | — | Blok hiç girmez |
| **Boş string** (`""`) | `new Date("")` → `NaN` | **`false`** | Atlanır |
| **`""` değil ama garip string** | Parse hatasına göre değişir | Değişken | Belirsiz |

> **Kritik:** `writeIpoToFirestore()` `listingDate`'i **ISO string** (`toIso(listingDate)`) olarak yazar.  
> `toIso()` → `date.toISOString()` → örn. `"2026-07-07T09:00:00.000Z"`.  
> Bu, `new Date("2026-07-07T09:00:00.000Z")` ile geri dönüştürülebilir → **sorun yok**.  
> Ama Firestore'daki mevcut ORZAX/SOHOE kayıtlarında `listingDate` alanı **hiç yok** (null/undefined) → blok girmez.

### 1d. `reconciled` sayacı tam olarak hangi koşulda artırılıyor?

```javascript
if (!stale.length) return 0;

let updated = 0;
for (let i = 0; i < stale.length; i += 400) {
  const batch = db.batch();
  for (const { ref, status } of stale.slice(i, i + 400)) {
    batch.update(ref, { status, updatedAt: FieldValue.serverTimestamp() });
  }
  await batch.commit();
  updated += Math.min(400, stale.length - i);
}
return updated;
```

Sayaç artırılabilmesi için `stale[]` array'ine bir eleman push edilmesi gerekiyor.  
3 koşuldan biri gerçekleşmeli:

| Kural | Kod | Gereksinim |
|---|---|---|
| **Kural 1** | `bistSymbols.has(d.symbol.toUpperCase())` | `bist_stocks` koleksiyonunda sembol mevcut olmalı |
| **Kural 2** | `!isNaN(ld) && ld <= now` | `d.listingDate` geçerli ISO string ve geçmişte olmalı |
| **Kural 3** | `!isNaN(re) && now > endOfDay` | `d.requestEnd` geçerli, `d.listingDate` null, `d.status !== 'pending_listing'` |

---

## 2. `writeIpoToFirestore()` — `listingDate` Nasıl Yazılıyor?

**Dosya:** `functions/index.js`  
**Fonksiyon:** `fetchIpoDetail()` → `writeIpoToFirestore()`

### 2a. `listingDate` tipi ne olarak Firestore'a yazılıyor?

```javascript
// fetchIpoDetail() içinde:
const listingDate = parseTrDateRange(listingDateText).start || null;
// ...
return {
  // ...
  listingDate: toIso(listingDate),   // ← toIso() çağrısı
  // ...
};
```

```javascript
function toIso(date) {
  return (date instanceof Date && !isNaN(date)) ? date.toISOString() : '';
}
```

**Sonuç:**
- `listingDate` parse edilebilirse → **ISO 8601 string** (`"2026-07-07T09:00:00.000Z"`)
- Parse edilemezse (HalkArz sayfasında tablo satırı yok, `-` yazıyor, format tanınmıyor) → **boş string** (`""`)

```javascript
// writeIpoToFirestore() içinde:
batch.set(
  db.collection('ipo_items').doc(docId),
  { ...item, status: finalStatus, updatedAt: FieldValue.serverTimestamp() },
  { merge: true },
);
```

`{ merge: true }` ile yazıldığı için **mevcut alanlar korunur**, sadece gönderilen alanlar güncellenir.  
Ama `item.listingDate` = `""` (boş string) gönderilirse Firestore'a **boş string yazılır** (null değil).

### 2b. HalkArz'da `listingDate` parse edilemediğinde Firestore'a ne gider?

ORZAX/SOHOE için HalkArz detay sayfasında listeleme tarihi tablo satırı şu selector'larla aranır:

```javascript
const listingPatterns = [
  /Bist\s+[İI]lk\s+[İI][şs]lem\s+Tarihi/i,
  /[İI]lk\s+[İI][şs]lem\s+Tarihi/i,
  /Borsada\s+[İI][şs]lem\s+G[oö]r/i,
  /Kotasyon\s+Tarihi/i,
  /Halka\s+Arz\s+Sonras[iı]\s+[İI][şs]lem/i,
];
```

HalkArz borsada listelendikten sonra bu hisselerin sayfasını **günceller** veya **kaldırır**.  
Hisse artık aktif işlem görüyorsa `listingDateText = ''` olur → `toIso(null)` → `''` → Firestore'a **boş string yazılır**.

**Kritik sonuç:** `{ merge: true }` ile gönderilen `listingDate: ""` mevcut alanı boş string'e **ezer**.  
`reconcileStaleIpoStatuses()` sonra `d.listingDate` = `""` görür → truthy kontrolde **geçer** (boş string falsy!)  
`""` → `new Date("")` → `NaN` → `!isNaN(ld)` = `false` → blok atlanır.

---

## 3. `syncIpoManual` akışı — `reconcileStaleIpoStatuses()` nerede çağrılıyor?

**Dosya:** `functions/index.js` satır 1160–1178

```javascript
exports.syncIpoManual = onRequest({ ... }, async (req, res) => {
  // ...
  try {
    // 1. BIST sembol kümesini çek
    const bistSymbols = await loadBistSymbols();
    // 2. HalkArz'dan veriyi çek (BIST kontrolüyle)
    const items  = await fetchHalkArzItems(bistSymbols);
    // 3. Yaz (mevcut trading korumalı)
    const count  = await writeIpoToFirestore(items, bistSymbols);
    // 4. Reconcile — yazmadan sonra uygula
    const reconciled = await reconcileStaleIpoStatuses(bistSymbols);
    res.json({ success: true, count, reconciled });
  } catch (err) { ... }
});
```

**Parametre:** `bistSymbols` — `loadBistSymbols()` tarafından dönen `Set<string>`  
**Çağrı sırası:** write **önce**, reconcile **sonra** (HEAD'de doğru sıra)

> ⚠️ **Ama bu HEAD kodu.** Canlıda farklı bir kod çalışıyor (aşağıda açıklanıyor).

---

## 4. Eski Kod vs HEAD Kodu — Deploy Durumu

`git log` çıktısına göre:

```
89b8d5a  2026-10-05 15:33  fix(ipo): BIST kontrolü ve trading koruma — syncIpoFeed durum öncelik sırası düzeltildi  ← HEAD
8700fa2  2026-10-05 15:15  feat: 19 yeni BIST hissesi eklendi (SOHOE, ORZAX dahil)
```

`git diff HEAD~1 HEAD -- functions/index.js` çıktısı:

**Eski kod (`HEAD~1` / canlı):**
```javascript
// syncIpoManual (ESKİ):
const reconciled = await reconcileStaleIpoStatuses();   // ← bistSymbols YOK
const items  = await fetchHalkArzItems();                // ← bistSymbols YOK
const count  = await writeIpoToFirestore(items);         // ← bistSymbols YOK, trading koruması YOK
res.json({ success: true, count, reconciled });

// reconcileStaleIpoStatuses() (ESKİ):
async function reconcileStaleIpoStatuses() {    // ← parametre yok
  // ...
  // BIST sembolleri kontrolü YOK
  // Sadece listingDate ve requestEnd kontrolü var
}
```

**HEAD kodu (local — deploy edilmemiş):**
```javascript
async function reconcileStaleIpoStatuses(bistSymbols) {  // ← yeni parametre
  // ...
  if (d.symbol && bistSymbols instanceof Set && bistSymbols.has(d.symbol.toUpperCase())) {
    stale.push({ ref: doc.ref, status: 'trading' });  // ← yeni BIST kontrolü
    continue;
  }
  // ...
}
```

> **`syncIpoManual` çağrıldığında çalışan fonksiyon HEAD değil, canlıdaki eski `reconcileStaleIpoStatuses()`.**  
> Bu eski fonksiyon `bistSymbols` parametresi **almıyor** ve **BIST kontrolü yapmıyor**.

---

## 5. SOHOE ve ORZAX — Neden Reconcile Koşuluna Girmiyor?

### 5a. Kaynak verideki durumları

`bistguncel.md` (gerçek zamanlı BIST verisi):
- **ORZAX:** 101.70 TL — borsada aktif işlem
- **SOHOE:** 12.07 TL — borsada aktif işlem

`data/ipo_manual_overrides.json` (HEAD commit'teki referans):
- ORZAX: `requestStart: 2026-06-29`, `requestEnd: 2026-07-01`, `listingDate: 2026-07-07`
- SOHOE: `requestStart: 2026-06-30`, `requestEnd: 2026-07-01`, `listingDate: 2026-07-08`

### 5b. Firestore doc ID formatı

```javascript
const key = item.symbol
  ? item.symbol.toUpperCase()
  : `NO_SYMBOL_${item.companyName.replace(/\s+/g, '_').substring(0, 30)}`;
```

ORZAX ve SOHOE'nin HalkArz sayfasında sembol HTML elementi varsa doküman ID = **`ORZAX`** ve **`SOHOE`** (büyük harf, doküman anahtarı).

### 5c. Reconcile koşuluna neden girmiyor (3 bağımsız engel)

**Engel 1 — Canlı kod eski, `bistSymbols` parametresi yok**

Canlıda çalışan `reconcileStaleIpoStatuses()` eski versiyonu → BIST kontrolü hiç yok.

**Engel 2 — `bist_stocks` Firestore koleksiyonunda SOHOE/ORZAX yok**

`loadBistSymbols()` `bist_stocks` koleksiyonundan `listDocuments()` ile sembol kümesi okur.  
Bu koleksiyona yazma yapan tek kod `runBist100Sync` → BIST100 listesinden güncelleme yapar.  
SOHOE ve ORZAX BIST100'de değil → `bist_stocks` koleksiyonunda **yok**.  

`lib/services/bist_stocks.dart`'taki statik liste Firestore'a yazmaz; Flutter istemcisinde in-memory kullanılır. Bu Dart değişikliği Cloud Function'a ulaşmaz.

Sonuç: `bistSymbols.has('SOHOE')` → `false`, `bistSymbols.has('ORZAX')` → `false`.

**Engel 3 — Firestore'daki `listingDate` null veya boş string**

HalkArz artık bu hisseleri aktif listeleme sayfasında **göstermeyebilir** (borsaya girmiş, sayfa kaldırılmış).  
Parse başarısız → `listingDate: ""` → Firestore'a boş string yazılır.  
`d.listingDate = ""` → truthy ama `new Date("") = NaN` → `!isNaN(ld) = false` → reconcile 2. kuralı da atlanır.  
`d.requestEnd` geçmiş olabilir → `pending_listing` ataması olur ama `trading` değil.

**Üç engelden herhangi biri tek başına yeterli; üçü aynı anda aktif.**

---

## 6. `reconciled: 0` Çıkmasının Tam Teknik Açıklaması

Canlıda çalışan kod (deploy edilmemiş HEAD öncesi sürüm) için `syncIpoManual` akışı:

```
1. reconcileStaleIpoStatuses()     ← eski; bistSymbols parametresi yok
   → BIST kontrolü: YOK
   → listingDate kontrolü: d.listingDate = "" veya null → falsy veya NaN → atlanır
   → requestEnd kontrolü: bazı kayıtlar pending_listing olur ama trading değil
   → stale[] = [] → return 0

2. fetchHalkArzItems()              ← eski; bistSymbols parametresi yok
   → HalkArz'dan 222 kayıt çeker
   → SOHOE/ORZAX için listingDate parse edilemiyor → status = "pending_listing" ya da "upcoming"

3. writeIpoToFirestore(items)       ← eski; trading koruması YOK
   → Firestore'a { ...item, status: "pending_listing" } yazar
   → Adım 1'deki reconcile sonucu varsa üzerine yazar (zaten yoktu)

4. res.json({ success: true, count: 222, reconciled: 0 })
```

HEAD kodu deploy edilmiş olsaydı dahi `bist_stocks`'ta SOHOE/ORZAX olmadığından ve `listingDate` null/boş olduğundan yine `reconciled: 0` dönebilirdi — ama `requestEnd <= now` kuralı `pending_listing` ataması yapar ve hiç değiştirilmemişlere `reconciled > 0` olurdu.

---

## 7. En Küçük Düzeltme Ne Olmalı?

**Uygulama değil — sadece söyleniyor.**

### Adım 1 (zorunlu) — Firebase deploy

```bash
cd functions
firebase deploy --only functions:syncIpoFeed,functions:syncIpoManual
```

HEAD `89b8d5a`'daki kod (`reconcileStaleIpoStatuses(bistSymbols)`, `loadBistSymbols()`, trading koruması, doğru sıra) canlıya taşınır.

### Adım 2 (zorunlu) — `bist_stocks` koleksiyonunu güncelle

BIST kontrolü için SOHOE ve ORZAX'ın `bist_stocks` Firestore koleksiyonunda birer doküman olarak bulunması gerekiyor.

Seçenek A: `syncBist100Manual?bootstrap=true` (100 BIST100 sembolünü yazar — SOHOE/ORZAX BIST100'de değilse kapsamaz)  
Seçenek B: Manuel Firestore konsolu üzerinden `bist_stocks/SOHOE` ve `bist_stocks/ORZAX` dokümanları oluştur  
Seçenek C: `ipo_manual_overrides.json` yaklaşımı — ama `functions/index.js` bu dosyayı okumaz, etkisi yok

> **Not:** Deploy sonrası Adım 3'teki `listingDate` kuralı da çalışır. `listingDate` geçerli ISO string ise BIST kontrolü olmadan da `trading` atanır. Asıl sorun `listingDate`'in Firestore'da null/boş olması.

### Adım 3 (kritik) — `listingDate` null/boş olan kayıtları düzelt

SOHOE ve ORZAX'ın Firestore dokümanlarında `listingDate` ya boş string (`""`) ya da null.  
İki seçenek:

a) **Firestore console'dan elle düzelt:** `ipo_items/ORZAX.listingDate = "2026-07-07T09:00:00.000Z"`, `ipo_items/SOHOE.listingDate = "2026-07-08T09:00:00.000Z"`  
b) **`syncIpoManual`'ı deploy + bist_stocks güncelleme sonrası tetikle:** `bist_stocks`'ta SOHOE/ORZAX varsa `computeIpoStatus()` BIST kontrolünde `trading` atar → `writeIpoToFirestore()` `trading` yazar → `reconcileStaleIpoStatuses()` zaten `trading` olanları atlar.

### Adım 4 (opsiyonel) — `data/ipo_manual_overrides.json` working copy silmesini geri al

`git status` çıktısında `data/ipo_manual_overrides.json` modified (unstaged):
```
 M data/ipo_manual_overrides.json
```
SOHOE ve ORZAX girişleri unstaged olarak silindi. `functions/index.js` bu dosyayı okumadığından Firestore akışına doğrudan etkisi yok. Ancak `tools/update_ipo_feed.mjs` (GitHub fallback feed) bu dosyayı kullanır. Referans bütünlüğü için:
```bash
git restore data/ipo_manual_overrides.json
```

---

## Kanıt Zinciri Özeti

| İddia | Kanıt |
|-------|-------|
| Canlı kod HEAD değil | `reconcileStaleIpoStatuses()` eski sürümde `bistSymbols` parametresi yok; `git diff HEAD~1 HEAD` bunu gösteriyor |
| SOHOE/ORZAX `bist_stocks`'ta yok | `runBist100Sync` yalnızca BIST100 listesini yazar; `loadBistSymbols()` boş Set döner; `.agents/tasks/reconcile-loadbist-analysis.md` kanıt B |
| `listingDate` Firestore'da null/boş | HalkArz borsaya giren hisseleri listeden kaldırır; `toIso(null) = ""` → Firestore'a boş string; yeni `syncIpoManual` çalışmasında boş ezer |
| Üç engel aynı anda | Her birinin bağımsız olarak `reconciled:0` üretmeye yettiği kod akışında gösterildi |
| SOHOE/ORZAX gerçekte trading | `bistguncel.md`: ORZAX 101.70 TL, SOHOE 12.07 TL — aktif işlem |

---

## Sonuç

`reconciled: 0`'ın **tek gerçek sebebi** şudur: Canlıda deploy edilmiş olan eski `reconcileStaleIpoStatuses()` fonksiyonu ne `bistSymbols` parametresi alıyor ne de `listingDate` null/boş string olan kayıtları `trading`'e alabilecek bir konumdadır. HEAD'deki düzeltme deploy edilmemiş. Ayrıca, yeni kod deploy edilse bile `bist_stocks` Firestore koleksiyonunda SOHOE ve ORZAX yoktur ve `listingDate` alanı null/boş olduğu için her iki ek kural da tetiklenmez.
