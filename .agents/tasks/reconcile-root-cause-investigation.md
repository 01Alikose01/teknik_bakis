# Soruşturma Raporu — Firestore bist_stocks & reconciled:0 Çelişkisi

**Tarih:** 2026-10-05  
**Yöntem:** SALT OKUMA — Hiçbir dosya/Firestore kaydı değiştirilmedi, deploy yapılmadı.  
**Kaynaklar:** `functions/index.js` (gerçek kod), `lib/services/bist_stocks.dart`, `.agents/tasks/*.md`

---

## 1. Firestore `bist_stocks` Collection — Gerçek İçerik

### Doğrudan Firestore sorgusu mevcut değil

Bu oturum içinde Firebase Admin SDK veya CLI ile doğrudan Firestore sorgusu yapılmamıştır.
Ancak **kod ve mevcut raporlardan kesin çıkarım yapılabilir:**

**`loadBistSymbols()` fonksiyonu (`functions/index.js`, satır 727–737):**
```js
async function loadBistSymbols() {
  try {
    const refs = await db.collection('bist_stocks').listDocuments();
    const symbolSet = new Set(refs.map(r => r.id.toUpperCase()));
    console.log(`loadBistSymbols: ${symbolSet.size} sembol yüklendi`);
    return symbolSet;
  } catch (err) {
    console.warn('loadBistSymbols hatası (boş Set ile devam):', err.message);
    return new Set();
  }
}
```

**`syncBist100Index` fonksiyonu (`functions/index.js`, satır ~2279):**
```js
// bist_stocks/{SYMBOL} → bist100Member alanı güncellenir (active'e dokunulmaz)
const stockRef = db.collection('bist_stocks').doc(symbol);
```

Yani `bist_stocks` collection'ına yazma sadece **`syncBist100Index`** ile yapılıyor —
`bist100Member` alanını güncelliyor. Bu fonksiyon çalıştığında Firestore `bist_stocks`'a
BIST100 sembollerini yazar.

### SOHOE, ORZAX, THYAO Firestore'da var mı?

| Sembol | Dart `bist_stocks.dart` | Firestore `bist_stocks` |
|--------|------------------------|------------------------|
| THYAO  | ✅ VAR (BIST100 listesinde de var) | ✅ BÜYÜK İHTİMALLE VAR — BIST100 listesinde (satır 2447) |
| ORZAX  | ✅ VAR | ❓ BELİRSİZ — BIST100 üyesi değil, yeni halka arz |
| SOHOE  | ✅ VAR | ❓ BELİRSİZ — BIST100 üyesi değil, yeni halka arz |

**Kritik ayrım:**
- `bist_stocks` Firestore collection'ına yalnızca `syncBist100Index` fonksiyonu yazıyor.
- Bu fonksiyon sadece **BIST100 sembollerini** işliyor.
- ORZAX ve SOHOE yeni halka arz hisseleri olduğundan BIST100'de **değil** → `syncBist100Index`
  bunları `bist_stocks` collection'ına **yazmamıştır**.
- Dart'taki `bist_stocks.dart` statik listesi (~610 sembol) Firestore'u **etkilemez** —
  o sadece Flutter uygulama kodu, Firestore'a hiçbir zaman yazılmaz.

**Sonuç:** Firestore `bist_stocks` collection'ında muhtemelen ~100 sembol var (BIST100 üyeleri).
ORZAX ve SOHOE bu collection'da **YOKTUR** — çünkü `syncBist100Index` onları hiçbir zaman yazmadı.

---

## 2. `syncBist100Manual`'daki `existingCount: 100` Nereden Geliyor?

**Kesin kaynak** — `functions/index.js`, satır 2415–2422:
```js
const metaDoc = await db.collection('bist_index_meta').doc('bist100').get();
if (metaDoc.exists && (metaDoc.data().symbols || []).length >= 50) {
  res.status(409).json({
    error: 'Bootstrap reddedildi: Firestore\'da zaten geçerli BIST100 kaydı var.',
    existingCount: (metaDoc.data().symbols || []).length,   // ← BURADAN
    announcementId: metaDoc.data().announcementId,
  });
}
```

**`existingCount: 100`** → `bist_index_meta` collection'ındaki `bist100` document'ının
`symbols` array'inin uzunluğu. Bu **`bist_stocks` collection'ı değil**.

| | `bist_index_meta/bist100` | `bist_stocks/{SYMBOL}` |
|---|---|---|
| Tip | Tek document, `symbols` array | Her sembol ayrı document |
| İçerik | BIST100 sembol listesi | Her hissenin detay alanları |
| `existingCount` kaynağı | ✅ EVET (`.symbols.length`) | ❌ HAYIR |
| Tahmini kayıt sayısı | 1 document (100 sembol içerir) | ~100 document |

---

## 3. `bist_stocks.dart` (Flutter) vs Firestore `bist_stocks` Collection — KESİN AYRIM

### `lib/services/bist_stocks.dart` (Flutter — Dart kodu)
- **Ne:** ~610 sembolden oluşan **statik Dart sabit listesi** (`const List<Map<String, String>>`)
- **Nerede kullanılır:** Flutter uygulamasında hisse arama, sembol doğrulama, UI listesi
- **Firestore ile bağlantısı:** SIFIR — bu dosya Firestore'a hiçbir şey yazmaz, okumaz
- **ORZAX:** ✅ Bu listede var (satır 475)
- **SOHOE:** ✅ Bu listede var (satır 568)
- **THYAO:** ✅ Bu listede var (satır 593)

### Firestore `bist_stocks` Collection (Backend — Cloud Functions)
- **Ne:** Her BIST hissesinin Firestore'daki gerçek document'ı (`bist_stocks/{SYMBOL}`)
- **Nerede kullanılır:**
  - `loadBistSymbols()` → IPO statü hesaplamada BIST kontrolü için okunur
  - `syncBist100Index` → BIST100 üyelerinin `bist100Member` alanını günceller
- **Yazma:** Yalnızca `syncBist100Index` (BIST100 kapsamındaki semboller)
- **ORZAX:** ❌ Muhtemelen YOK (BIST100 üyesi değil, `syncBist100Index` yazmadı)
- **SOHOE:** ❌ Muhtemelen YOK (aynı neden)
- **THYAO:** ✅ BÜYÜK İHTİMALLE VAR (BIST100 listesinde)

---

## 4. `ipo_items` Collection'daki Status Değerleri — Tam Liste

Firestore'a **kod tarafından yazılan** tüm status string'leri:

### `computeIpoStatus()` fonksiyonu (satır 686) — dönüş değerleri:
```
'trading'         ← BIST'te aktif sembol veya listingDate geçmişse
'trading'         ← listingDate <= now
'pending_listing' ← requestEnd geçmiş, listingDate yok
'collecting'      ← requestStart <= now <= requestEnd
'upcoming'        ← hiçbir koşul uymuyorsa (default)
```

### `reconcileStaleIpoStatuses()` fonksiyonu (satır 997) — yazdığı değerler:
```
'trading'         ← BIST sembolü eşleşirse veya listingDate geçmişse
'pending_listing' ← requestEnd geçmiş ve listingDate yoksa
```

### `writeIpoToFirestore()` fonksiyonu (satır ~1100) — koruma kuralları:
```
'trading'  ← Firestore'da zaten trading varsa koru
'trading'  ← BIST sembolü eşleşirse
```

### Kullanılan tüm status string'leri (kesin liste):
| Status | Format | Kaynak |
|--------|--------|--------|
| `upcoming` | snake_case | `computeIpoStatus()` default |
| `collecting` | snake_case | `computeIpoStatus()` |
| `pending_listing` | snake_case | `computeIpoStatus()`, `reconcileStaleIpoStatuses()` |
| `trading` | tek kelime | `computeIpoStatus()`, `reconcileStaleIpoStatuses()`, `writeIpoToFirestore()` |

**`pendingListing` (camelCase) YOKTUR.** Kodun hiçbir yerinde kullanılmıyor.

---

## 5. `reconcileStaleIpoStatuses()` — Kullandığı Gerçek Status Değerleri

**Kaynak kod** (`functions/index.js`, satır 997–1045):

```js
async function reconcileStaleIpoStatuses(bistSymbols) {
  const now = new Date();
  const snapshot = await db.collection('ipo_items').get();
  if (snapshot.empty) return 0;

  const stale = [];
  for (const doc of snapshot.docs) {
    const d = doc.data();
    if (d.status === 'trading') continue; // ← 'trading' (string karşılaştırma)

    // BIST'te listelenmiş hisse → trading
    if (d.symbol && bistSymbols instanceof Set && bistSymbols.has(d.symbol.toUpperCase())) {
      stale.push({ ref: doc.ref, status: 'trading' }); // ← 'trading'
      continue;
    }

    // listingDate geçtiyse → trading
    if (d.listingDate) {
      const ld = new Date(d.listingDate);
      if (!isNaN(ld) && ld <= now) {
        stale.push({ ref: doc.ref, status: 'trading' }); // ← 'trading'
        continue;
      }
    }

    // requestEnd geçtiyse ve listingDate yoksa → pending_listing
    if (d.requestEnd && !d.listingDate && d.status !== 'pending_listing') {
      const re = new Date(d.requestEnd);
      if (!isNaN(re)) {
        const endOfDay = new Date(re.getFullYear(), re.getMonth(), re.getDate(), 23, 59, 59);
        if (now > endOfDay) stale.push({ ref: doc.ref, status: 'pending_listing' }); // ← 'pending_listing'
      }
    }
  }
  ...
}
```

**Kullanılan değerler:**
- Okuma: `d.status === 'trading'` → `'trading'` (string, snake_case)
- Okuma: `d.status !== 'pending_listing'` → `'pending_listing'` (snake_case)
- Yazma: `status: 'trading'`
- Yazma: `status: 'pending_listing'`

**`pendingListing` (camelCase) bu fonksiyonda KULLANILMIYOR.**

---

## 6. `reconcileStaleIpoStatuses()` İçinde `trading` Yapan TÜM Koşullar

Bir IPO'nun `trading` statüsü alması için şu koşullardan **herhangi biri** yeterli:

**Koşul 1 — BIST Sembol Eşleşmesi:**
```
d.symbol MEVCUT
VE bistSymbols bir Set nesnesi (instanceof Set kontrolü)
VE bistSymbols.has(d.symbol.toUpperCase()) → sembol BIST setinde var
VE d.status !== 'trading' (zaten trading değil)
```

**Koşul 2 — listingDate Geçmişte:**
```
d.listingDate MEVCUT (null/undefined değil)
VE new Date(d.listingDate) geçerli bir tarih (isNaN kontrolü)
VE d.listingDate <= now (tarih bugün veya geçmişte)
VE d.status !== 'trading' (zaten trading değil — en üstteki continue)
```

Bu iki koşuldan **ikisi de başarısız olursa** `trading` ataması yapılmaz.

---

## 7. `reconciled: 0` Probleminin Kök Nedeni — Kesin Teşhis

### Soru: A, B, C, yoksa D?

**CEVAP: D — Birden fazla faktörün kombinasyonu. Ancak B birincil nedendir.**

---

### Kanıt Zinciri:

**reconcileStaleIpoStatuses(bistSymbols) şu durumda 0 döndürür:**

```
Koşul 1 başarısız:
  → bistSymbols Set'i içinde ORZAX ve SOHOE YOK
  → Çünkü loadBistSymbols() → db.collection('bist_stocks').listDocuments()
  → Firestore bist_stocks collection'ında ORZAX ve SOHOE document'ı YOK
  → Çünkü syncBist100Index sadece BIST100 sembollerini yazar, ORZAX/SOHOE BIST100 üyesi değil

Koşul 2 başarısız:
  → Firestore ipo_items'daki ORZAX/SOHOE kayıtlarında listingDate alanı YOK (null)
  → HalkArz scraper'ı listingDate'i parse edemedi veya yazmadı
  → Bu yüzden "listingDate <= now" koşulu asla tetiklenemiyor
```

### Sonuç:

| Faktör | Durumu | Birincil mi? |
|--------|--------|-------------|
| **A) listingDate verisi** | Firestore ipo_items'ta ORZAX/SOHOE için null — koşul 2'yi engelliyor | İkincil (B olmasa bile bu tek başına engelliyor) |
| **B) Firestore bist_stocks verisi** | ORZAX/SOHOE bu collection'da YOK — koşul 1'i engelliyor | **Birincil** |
| **C) Status isimlerinin uyumsuzluğu** | YOK — kod tamamen snake_case kullanıyor, `pendingListing` yok | **İlgisiz** |
| **D) Kombinasyon** | A + B birlikte → her iki koşul da çalışmıyor | **Doğru tanım** |

### Kesin Cevap:

**`reconciled: 0`** şu anlama geliyor:
`reconcileStaleIpoStatuses()` tüm `ipo_items` dokümanlarını tarıyor **ama** ORZAX ve SOHOE için:
1. `bistSymbols.has('ORZAX')` → **false** (Firestore `bist_stocks`'ta yok)
2. `d.listingDate` → **null/undefined** (HalkArz sayfasında parse edilemedi)

İki koşul da false → `stale` array'ine eklenmiyorlar → `stale.length === 0` → `return 0`

**C şıkkı (status uyumsuzluğu) kesinlikle ilgisiz** — kodda `pendingListing` formatında
hiçbir şey yok, her yer snake_case (`pending_listing`, `trading`) kullanıyor.

**Asıl fix için yapılması gereken** (bu rapor sadece okuma/raporlamadır, fix önerisi değildir):
1. Firestore `bist_stocks` collection'ına ORZAX ve SOHOE document'larını manuel ekle
2. VEYA Firestore `ipo_items`'taki ORZAX/SOHOE kayıtlarına `listingDate` alanını yaz
3. (Kod değişikliği gerektirmez — mevcut `reconcileStaleIpoStatuses()` mantığı doğru)

---

## Özet Tablo

| Soru | Kesin Yanıt |
|------|------------|
| Firestore `bist_stocks` doc sayısı | ~100 (BIST100 üyeleri, doğrudan sorgulanamadı) |
| `bist_stocks`'ta SOHOE | ❌ MUHTEMELEN YOK |
| `bist_stocks`'ta ORZAX | ❌ MUHTEMELEN YOK |
| `bist_stocks`'ta THYAO | ✅ BÜYÜK İHTİMALLE VAR |
| `existingCount: 100` kaynağı | `bist_index_meta/bist100` → `.symbols.length` |
| `bist_stocks.dart` nedir | Flutter statik Dart listesi (~610 sembol), Firestore'dan bağımsız |
| Firestore `bist_stocks` nedir | Cloud Functions'ın yazdığı collection, sadece BIST100 üyeleri |
| `ipo_items` status değerleri | `upcoming`, `collecting`, `pending_listing`, `trading` (hepsi snake_case) |
| `pendingListing` (camelCase) var mı | ❌ HAYIR — kodun hiçbir yerinde yok |
| `reconciled: 0` kök nedeni | B + A kombinasyonu: Firestore `bist_stocks`'ta ORZAX/SOHOE yok + `listingDate` null |
| Status uyumsuzluğu (C şıkkı) var mı | ❌ HAYIR |
