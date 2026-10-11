# Teknik Bakış — BIST100 / BIST500 / IPO Mimari Analizi

**Tarih:** 2026-10-05  
**Analiz tipi:** Salt okunur kod ve veri incelemesi  
**Analiz edilen dosyalar:**
- `functions/index.js` (~2500 satır)
- `lib/services/bist_stocks.dart`
- `lib/services/bist100_service.dart`
- `lib/services/ipo_service.dart`
- `lib/screens/scanner_screen.dart`
- `data/ipo_manual_overrides.json` (git HEAD)
- `data/ipo_feed.json`

---

## ÖZET (TL;DR)

| Kritik bulgu | Detay |
|---|---|
| `loadBistSymbols()` **`bist_stocks` koleksiyonundan** okuyor | BIST100 değil, geniş BIST listesi |
| `bist_stocks` koleksiyonu **büyük olasılıkla boş veya sadece bootstrap ~100 sembol** | SOHOE, ORZAX bu koleksiyonda yok |
| IPO trading kararı için iki mekanizma var; **her ikisi de bağımsız çalışıyor** | BIST seti + `listingDate` |
| **Tasarım hatası YOK** — loadBistSymbols() doğru koleksiyonu hedefliyor | Ama koleksiyon henüz doldurulmamış |
| SOHOE ve ORZAX `bist_stocks.dart` sabit listesinde **var** | Ama Firestore `bist_stocks` koleksiyonunda **yok** |
| Deploy açığı: HEAD (`89b8d5a`) Firebase'e henüz gönderilmemiş | Canlı ortamda eski kod çalışıyor |

---

## 1 — BIST100

### 1.1 Hisseler nerede tutuluyor?

**Firestore:**
```
bist_index_meta / bist100
  {
    symbols: ['AKBNK', 'GARAN', ...],   // 100 sembol
    updatedAt: Timestamp,
    revision: '2026-Q4',
    added: [...],
    removed: [...],
    announcementId: '15598',
    source: 'Borsa Istanbul'
  }
```

**Flutter (sabit fallback):**  
`lib/services/bist_stocks.dart` → `const List<String> kBist100Symbols` — 100 eleman, hardcoded.  
`lib/services/bist100_service.dart` → `_liveSymbols` runtime değişkeni; önce sabit listeden başlar, Firestore'dan güncellenince dinamik hale gelir.

### 1.2 Flutter'da ayrı bir BIST100 listesi var mı?

Evet. İki katmanlı yapı:
- `kBist100Symbols` — sabit (const), derleme zamanı fallback.
- `kBist100SymbolsLive` — runtime, `Bist100Service.init()` sonrası Firestore ile güncellenir.
- `Bist100Service.symbols` getter'ı `_liveSymbols` döndürür (dinamik).

### 1.3 `index.js` içindeki BIST100 fonksiyonları

| Fonksiyon | Tetikleme | Ne yapar |
|---|---|---|
| `syncBist100Index` | Her Pazartesi 05:00 UTC (scheduled) | `runBist100Sync()` çağırır |
| `syncBist100Manual` | HTTP GET/POST, `?secret=` | `runBist100Sync()` veya bootstrap modu |
| `runBist100Sync()` | İç fonksiyon | BI duyurusunu parse edip Firestore'a yazar |
| `findLatestBist100Announcement()` | `runBist100Sync()` içinden | borsaistanbul.com duyuru sayfasını tarar |
| `parseBist100Announcement()` | `runBist100Sync()` içinden | HTML tablosundan added/removed semboller |

### 1.4 `syncBist100Index`, `syncBist100Manual` ve `BIST100_OCT2026` tam olarak ne günceller?

**`syncBist100Index` (haftalık scheduler):**
1. borsaistanbul.com duyuru listesini tarar → en yeni BIST 100 periyodik revizyonunu bulur
2. HTML'i parse eder → `added[]` ve `removed[]` semboller
3. Mevcut `bist_index_meta/bist100.symbols` üzerinde delta uygular
4. Yeni 100-sembol listesini `bist_index_meta/bist100`'e yazar
5. `bist_stocks/{SYMBOL}` dokümanlarında sadece `bist100Member` alanını günceller (`active`'e dokunmaz)

**`syncBist100Manual` (HTTP endpoint):**
- Normal mod (`?dryRun=true/false`): `runBist100Sync()` çağrısı — yukarıdakiyle aynı iş.
- Bootstrap modu (`?bootstrap=true`): Firestore boşken `BIST100_OCT2026` hardcoded listesini yazar. Koleksiyonda ≥50 doküman varsa 409 döner.

**`BIST100_OCT2026`:**
Bootstrap için 100-sembol hardcoded liste. Kaynak: borsaistanbul.com duyuru #15598 (Ekim–Aralık 2026 periyodu). Yalnızca bootstrap modunda kullanılır; normal sync duyuruyu dinamik olarak parse eder.

### 1.5 Sembol sayıları

| Liste | Sembol sayısı | Kaynak |
|---|---|---|
| `kBist100Symbols` (Dart sabit) | **100** | `bist_stocks.dart` satır 826–889 |
| `BIST100_OCT2026` (JS bootstrap) | **100** | `index.js` satır 2437–2447 |
| Firestore `bist_index_meta/bist100` | **100** (bootstrap yapılmışsa) | Dinamik — deploy yapılmamışsa boş olabilir |

⚠️ **Önemli fark:** Dart sabit listesi ile JS bootstrap listesi **aynı değil**.

- Sadece Dart'ta olan 14 sembol: `ISCTR, VAKBN, YKBNK, VESTL, EUPWR, IZENR, ZOREN, ESEN, ULKER, ODINE, BRISA, IEYHO, TMSN, ULUUN`
- Sadece Bootstrap JS'te olan 14 sembol: `AGESAS, AGHOL, AHGAZ, AKCNS, EGUBB, ENTRA, ISDMR, KATMR, KCAER, LMKDC, RGYAS, RYSAS, SNGYO, TABGD`

Bu iki liste farklı revizyonları yansıtıyor — Dart listesi "Eylül 2026" revizyonuna, JS bootstrap ise "Ekim 2026" revizyonuna göre. Her ikisi de 100 sembol içeriyor.

### 1.6 Liste dinamik olarak güncellenebilir mi?

**EVET** — ancak sadece backend tarafında.  
`syncBist100Index` her Pazartesi borsaistanbul.com'dan otomatik günceller.  
Flutter tarafı `Bist100Service.init()` ile Firestore'dan çeker ve Hive'a cache'ler.

### 1.7 BIST100'e yeni şirket eklendiğinde ne olur?

1. Borsa İstanbul duyuru yayınlar → `syncBist100Index` duyuruyu parse eder
2. `bist_index_meta/bist100.symbols` güncellenir
3. `bist_stocks/{YENİ_SEMBOL}.bist100Member = true` olur
4. Bir sonraki Flutter açılışında `Bist100Service._refreshFromFirestore()` yeni listeyi çeker
5. `kBist100SymbolsLive` ve `Bist100Service.symbols` güncellenir

### 1.8 BIST100'den çıkarılan şirket nasıl işaretleniyor?

`runBist100Sync()` içinde (satır 2316–2330):
```javascript
// Çıkarılanlar: bist100Member = false (active'e HİÇ dokunma)
batch.set(stockRef, { bist100Member: false }, { merge: true });
```
Sembol `bist_stocks` koleksiyonundan **silinmiyor**, sadece `bist100Member: false` yapılıyor. `active: true` korunuyor — sembol geniş BIST taramasından çıkmıyor, sadece BIST100 taramasından çıkıyor.

### 1.9 BIST100 taraması hangi veri kaynağını kullanıyor?

Flutter `scanner_screen.dart`:
```dart
static List<String> get _bist100Symbols => Bist100Service.symbols;
```
`Bist100Service.symbols` → `_liveSymbols` → Firestore `bist_index_meta/bist100` (online) veya Hive cache (offline) veya `kBist100Symbols` sabit (ilk açılış).

---

## 2 — BIST500 / Tüm BIST Tarama Listesi

### 2.1 Kullanıcı "BIST500" seçtiğinde gerçekte ne oluyor?

`scanner_screen.dart`:
```dart
static List<String> get _bist500Symbols =>
    kBistStocks.map((e) => e['symbol']!).toList();
```
`kBistStocks` global değişkeni → `bist_stocks.dart` içinde tanımlı.

UI'da gösterilen açıklama: `"Borsa İstanbul'daki güncel hisse listesi üzerinden $kBistListedCount hisse taranır."` — `kBistListedCount = 610`.

**Önemli:** Bu liste BIST500 değil, Borsa İstanbul'da işlem gören **tüm hisseleri** kapsamayı hedefleyen geniş listedir. Uygulama onu "BIST 500" olarak etiketlemiş ama aslında ~610-726 sembollük tam liste.

### 2.2 Liste nerede tutuluyor?

İki katmanlı yapı:

**Birincil (Firestore):**
```
bist_stocks / {SYMBOL}
  {
    symbol: 'AKBNK',
    name: 'Akbank T.A.Ş.',
    active: true,
    bist100Member: true/false
  }
```
`Bist100Service._refreshFromFirestore()` bu koleksiyonu `active != false` filtresiyle çeker.

**Fallback (sabit kod):**  
`lib/services/bist_stocks.dart` → `const List<Map<String, String>> _baseBistStocks` — **726 sembol** (PowerShell sayımına göre).  
`kBistStocks` bu sabit listeden başlar; Firestore güncellemesi gelince güncellenir, sabit listedekiler de merge edilerek korunur.

### 2.3 Flutter'da hangi dosya/sınıf kullanıyor?

- `lib/services/bist_stocks.dart` — `kBistStocks`, `_baseBistStocks`, `syncBistStocksFromFirestore()`
- `lib/services/bist100_service.dart` — Firestore'dan `bist_stocks` çekerek `kBistStocks`'u günceller
- `lib/screens/scanner_screen.dart` — `_bist500Symbols` getter

### 2.4 Kaç sembol var?

| Kaynak | Sembol sayısı |
|---|---|
| `_baseBistStocks` (Dart sabit) | **726** |
| `kBistListedCount` sabiti | **610** (belgesel, sadece UI'da gösterilir) |
| Firestore `bist_stocks` koleksiyonu | Bootstrap yapılmışsa ~100 (sadece BIST100), yoksa boş |

⚠️ **Kritik sorun:** Firestore `bist_stocks` koleksiyonu şu an yalnızca bootstrap ile yazılan ~100 BIST100 sembolünü içeriyor (veya hiç yok). 726 sembollük tam listeyi Firestore'a taşıyan bir Firebase Function **bulunmuyor**.

### 2.5 Bu liste gerçekten BIST'teki tüm hisseleri temsil ediyor mu?

Hedef öyle ama **eksik kalan var**. `_baseBistStocks` 726 sembol içeriyor, `kBistListedCount = 610` diyor, Borsa İstanbul'da 2026 itibarıyla ~610 hisse var. Fark muhtemelen endeks sembolleri (XU100, XU030 vs.) ve BYF'ler. Gerçek hisse sayısı açısından Dart listesi tatmin edici düzeyde kapsamlı görünüyor — ancak statik olduğundan yeni eklenen hisseler otomatik gelmiyor.

### 2.6 Yeni şirket BIST'e girdiğinde nasıl güncelleniyor?

**Otomatik mekanizma: YOK.**  
Geniş BIST listesini otomatik güncelleyen Firebase Function mevcut değil.  
`syncBist100Index` sadece `bist_stocks` koleksiyonunda `bist100Member` alanını değiştiriyor; yeni sembol eklemek için ayrıca doküman oluşturuyor — ama bu sadece BIST100 bileşeni olan semboller için.

Tüm BIST listesine yeni sembol eklemek için:
1. `_baseBistStocks` sabit listesine el ile eklenmesi, veya
2. Firestore `bist_stocks` koleksiyonuna doküman yazılması

### 2.7 Şirket BIST'ten çıktığında nasıl kaldırılıyor?

`active: false` yapılması yeterli. `Bist100Service._refreshFromFirestore()`:
```dart
.where('active', isNotEqualTo: false)
```
Ama bunu yapan otomatik bir mekanizma yok. Manuel müdahale gerekiyor.

### 2.8 Sembol/unvan değişikliğinde ne oluyor?

Otomatik mekanizma yok. Hem `_baseBistStocks` sabit listesi hem Firestore koleksiyonu el ile güncellenmeli.

### 2.9 Bu liste otomatik güncelleniyor mu?

**HAYIR** — Geniş BIST listesini (`bist_stocks` koleksiyonu) otomatik güncelleyen Firebase Function yok.  
Güncelleme sadece BIST100 sync'i dolaylı olarak etkiliyor (yeni BIST100 bileşenlerini ekliyor).

---

## 3 — IPO Sistemi

### 3.1 IPO'nun `trading` olup olmadığını belirleyen kod akışı

**`syncIpoFeed` (her 6 saatte, UTC 00/06/12/18):**
```
1. loadBistSymbols()         → bist_stocks koleksiyonundan sembol Set'i
2. fetchHalkArzItems()       → HalkArz.com scrape + computeIpoStatus()
3. writeIpoToFirestore()     → ipo_items'a yaz (trading korumalı)
4. reconcileStaleIpoStatuses() → geçmiş kayıtları güncelle
```

**`syncIpoManual` (HTTP, admin korumalı):** Aynı akış.

### 3.2 `loadBistSymbols()` hangi koleksiyondan sembol alıyor?

```javascript
// functions/index.js
async function loadBistSymbols() {
  const refs = await db.collection('bist_stocks').listDocuments();
  const symbolSet = new Set(refs.map(r => r.id.toUpperCase()));
  return symbolSet;
}
```

**KESİN CEVAP: `bist_stocks` koleksiyonundan** — yani geniş BIST listesini hedefleyen koleksiyon.  
BIST100-özel `bist_index_meta/bist100`'e **asla bakmıyor**.

### 3.3 `computeIpoStatus()` — karar mantığı

```javascript
function computeIpoStatus({ requestStart, requestEnd, listingDate, symbol, bistSymbols }) {
  // 1. bist_stocks'ta sembol var → 'trading'
  if (symbol && bistSymbols instanceof Set && bistSymbols.has(symbol.toUpperCase()))
    return 'trading';

  // 2. listingDate geçti → 'trading'
  if (listingDate && listingDate <= now) return 'trading';

  // 3. requestEnd geçti → 'pending_listing'
  // 4. requestStart <= now → 'collecting'
  // 5. Varsayılan → 'upcoming'
}
```

### 3.4 `reconcileStaleIpoStatuses(bistSymbols)` — düzeltme mantığı

Tüm `ipo_items` dokümanlarını tarar:
1. `bist_stocks`'ta sembol var → `trading`
2. `listingDate <= now` → `trading`
3. `requestEnd` geçmiş + `listingDate` yok → `pending_listing`

### 3.5 `writeIpoToFirestore(items, bistSymbols)` — güvenlik kuralları

```javascript
// Kural 1: Firestore'da zaten 'trading' varsa koru
if (existingStatuses.get(docId) === 'trading') finalStatus = 'trading';
// Kural 2: bist_stocks'ta aktif sembol → trading
if (bistSymbols.has(item.symbol.toUpperCase())) finalStatus = 'trading';
```

### 3.6 `loadBistSymbols()` — BIST100 mı, BIST500/tüm BIST mi?

`bist_stocks` koleksiyonu **tüm BIST hisselerini içermesi amacıyla tasarlanmış**. Bu doğru tasarım.

Ancak bu koleksiyona veri yazanlar:
- `runBist100Sync()` — sadece BIST100 bileşenleri
- Bootstrap — 100 sembol

Yani **tasarım doğru, uygulama eksik**: koleksiyon yalnızca BIST100 sembolleriyle dolu.

---

## 4 — KRİTİK KONTROL

### IPO "Borsada İşlem Görüyor" kararında BIST100 kullanılıyor mu?

**HAYIR** — `loadBistSymbols()` fonksiyonu `bist_index_meta/bist100`'e bakmıyor.  
`bist_stocks` koleksiyonundan okuyor.

### Ama gerçekte durum nedir?

**Fiilen BIST100 gibi davranıyor** — çünkü `bist_stocks` koleksiyonuna yazılan tek veri BIST100 bootstrap'ından ve BIST100 haftalık sync'inden geliyor. Yani koleksiyon ~100 sembol içeriyor.

Bu şu sonucu doğuruyor:

> **Tasarım niyeti doğrudur** — `loadBistSymbols()` geniş listeyi hedefliyor.  
> **Uygulama hatalıdır** — `bist_stocks` koleksiyonu dolduracak mekanizma eksik.  
> **Pratik etki:** IPO trading kontrolü fiilen BIST100 ile sınırlı çalışıyor.  
> **SOHOE ve ORZAX gibi BIST100 dışındaki IPO'lar** `bist_stocks`'ta olmadığından BIST yolu üzerinden `trading` alamıyor.

---

## 5 — SOHOE ve ORZAX

### 5.1 Kod tabanındaki kaynaklar

**`lib/services/bist_stocks.dart` (Flutter sabit liste):**
```dart
{'symbol': 'ORZAX', 'name': 'Orzaks İlaç ve Kimya Sanayi'},  // satır 475
{'symbol': 'SOHOE', 'name': 'Soho Giyim ve Enerji'},          // satır 568
```
8700fa2 commit'iyle eklendi.

**`data/ipo_manual_overrides.json` (git HEAD, commit 89b8d5a):**

| Alan | ORZAX | SOHOE |
|---|---|---|
| `companyName` | Orzaks İlaç ve Kimya Sanayi Tic. A.Ş. | Soho Giyim ve Enerji A.Ş. |
| `symbol` | ORZAX | SOHOE |
| `status` | `trading` | `trading` |
| `requestStart` | 2026-06-29 | 2026-06-30 |
| `requestEnd` | 2026-07-01 | 2026-07-01 |
| `listingDate` | **2026-07-07** | **2026-07-08** |
| `price` | 69,00 TL | 15,00 TL |
| `lot` | 55.000.000 Lot | 100.000.000 Lot |
| `distributionType` | Oransal Dağıtım | Eşit Dağıtım |
| `source` | Manual Override | Manual Override |

**Dikkat:** `data/ipo_manual_overrides.json` dosyasının **working copy (disk) versiyonunda** SOHOE ve ORZAX **yok** (silinmiş). `git HEAD`'de var. Working copy `functions/index.js` tarafından okunmuyor — bu dosyayı sadece `tools/update_ipo_feed.mjs` kullanıyor.

### 5.2 Firestore'daki durumu (kod analizi yoluyla çıkarım)

Firestore'a doğrudan erişim yapılamadığından, mevcut analizlere ve koda dayanarak çıkarım:

| Soru | ORZAX | SOHOE |
|---|---|---|
| `ipo_items` koleksiyonunda | **VAR** (HalkArz scraper yazdı) | **VAR** (HalkArz scraper yazdı) |
| `status` Firestore'da (muhtemel) | `upcoming` veya `pending_listing` | `upcoming` veya `pending_listing` |
| `listingDate` Firestore'da | Null (HalkArz parse edilemedi) | Null (HalkArz parse edilemedi) |
| `bist_stocks` koleksiyonunda | **YOK** | **YOK** |
| `bist_index_meta/bist100` listesinde | **YOK** | **YOK** |
| `_baseBistStocks` Dart listesinde | **VAR** (satır 475) | **VAR** (satır 568) |

**Neden `trading` olamıyorlar:**
1. `bist_stocks` koleksiyonunda yok → BIST yolu çalışmıyor
2. `listingDate` Firestore kaydında null → tarih yolu çalışmıyor
3. `ipo_manual_overrides.json` → `functions/index.js` tarafından okunmuyor
4. Deploy açığı → HEAD düzeltmesi canlı ortamda çalışmıyor

**Neyi görüyorlar kullanıcılar:**
- ORZAX: `status = upcoming` (requestEnd de null ise) veya `pending_listing` (requestEnd geçmişse)
- SOHOE: `status = pending_listing` (requestEnd geçmiş, listingDate null)

---

## 6 — SONUÇ TABLOSU

| Sistem | Veri kaynağı | Yaklaşık adet | Otomatik güncelleniyor mu? | Amacı |
|---|---|---|---|---|
| **BIST100** | Firestore `bist_index_meta/bist100` (birincil); `kBist100Symbols` sabit (fallback) | **100** | **EVET** — `syncBist100Index` her Pazartesi borsaistanbul.com'dan otomatik günceller | BIST100 taraması |
| **BIST500 / tüm BIST** | `kBistStocks` değişkeni → `_baseBistStocks` sabit (726 sembol); Firestore `bist_stocks` (sadece ~100, eksik) | **726** (Dart sabit) / **~100** (Firestore) | **HAYIR** — geniş listeyi güncelleyen backend function yok | Geniş BIST taraması |
| **IPO trading kontrolü** | Firestore `bist_stocks` koleksiyonu (loadBistSymbols) + `listingDate` karşılaştırması | `bist_stocks` ~100 sembol | **EVET** (6 saatlik sync) — ama etkinliği `bist_stocks`'un doluluk durumuna bağlı | IPO'nun borsada işlem görüp görmediğini belirlemek |

### Üç Kritik Soruya Cevap

**1. BIST100 listesi bağımsız ve güncellenebilir durumda mı?**  
**EVET** — `bist_index_meta/bist100` koleksiyonu `bist_stocks`'tan tamamen bağımsız. Her Pazartesi borsaistanbul.com'dan otomatik güncelleniyor. Flutter tarafı Firestore'dan çekiyor, Hive'da cache'liyor, sabit listeyle fallback sağlıyor. Sistem sağlam tasarlanmış.

**2. BIST500/tüm BIST listesi bağımsız ve güncellenebilir durumda mı?**  
**HAYIR (EKSİK)** — Dart sabit listesi (`_baseBistStocks`, 726 sembol) bağımsız ama güncellemek için kod değişikliği gerekiyor. Firestore `bist_stocks` koleksiyonu bu amaç için tasarlanmış ama dolduracak Firebase Function yok — koleksiyon ya boş ya da sadece BIST100 sembolleri içeriyor. Geniş BIST listesini otomatik güncelleyen backend mekanizması eksik.

**3. IPO trading kontrolü BIST100'den bağımsız olarak tüm aktif BIST hisselerini kontrol ediyor mu?**  
**HAYIR (FİİLİYATTA)** — Tasarım olarak doğru (`bist_stocks` geniş listeyi hedefliyor), pratikte `bist_stocks` koleksiyonu yalnızca BIST100 sembollerini içerdiğinden fiilen BIST100 sınırlı çalışıyor. BIST100 dışında işlem gören IPO'lar (SOHOE, ORZAX gibi) bu yoldan `trading` alamıyor. `listingDate` mekanizması kurtarıcı olabilirdi ama HalkArz scraper'ı bu tarihi parse edemiyor veya Firestore'a yazamıyor.

---

## 7 — ÖNERİLEN DÜZELTMELER (uygulanmadı, sadece rapor)

1. **`bist_stocks` koleksiyonunu tüm BIST hisseleriyle doldur:**  
   `_baseBistStocks` (726 sembol) bir kez Firestore'a yazılmalı. Yeni function eklenebilir: `syncBistStocksFromDart` veya `initBistStocks`.

2. **`loadBistSymbols()` fallback ekle:**  
   `bist_stocks` boşsa Dart sabit listesini kullanabilecek mekanizma yok. Koleksiyon boşken `bistSymbols = new Set()` dönüyor ve tüm BIST kontrolü devre dışı kalıyor.

3. **Firebase deploy:**  
   `89b8d5a` (HEAD) commit'i deploy edilmemiş. `write → reconcile` sırası düzeltmesi canlıya geçmeden SOHOE/ORZAX sorunları kalıcı çözülmüyor.

4. **SOHOE ve ORZAX `bist_stocks`'a ekle:**  
   Bu iki sembol 2026-07'de listelenmiş; Firestore `bist_stocks` koleksiyonuna manuel veya toplu taşıma ile eklenmeli.

5. **`listingDate` parse iyileştirmesi:**  
   HalkArz'da `listingDate` alanı parse edilemiyorsa `pending_listing`'den `trading`'e geçiş `reconcileStaleIpoStatuses`'a kalıyor — ama bu da `bist_stocks` veya `listingDate` olmadan çalışmıyor. Minimum fix: Firestore'daki SOHOE/ORZAX kayıtlarına `listingDate` alanı elle yazılmalı.

---

## Kanıt Referansları

| İddia | Kanıt dosyası | Satır |
|---|---|---|
| `loadBistSymbols()` `bist_stocks`'tan okuyor | `functions/index.js` | ~745–752 |
| `computeIpoStatus()` önce BIST, sonra `listingDate` | `functions/index.js` | ~700–725 |
| `kBist100Symbols` 100 sembol | `lib/services/bist_stocks.dart` | ~826–889 |
| `_baseBistStocks` 726 sembol | `lib/services/bist_stocks.dart` | ~6–725 |
| BIST100 Firestore yolu: `bist_index_meta/bist100` | `lib/services/bist100_service.dart` | ~65–90 |
| BIST500 taraması `kBistStocks` kullanıyor | `lib/screens/scanner_screen.dart` | ~17–20 |
| `syncBist100Index` haftalık scheduler | `functions/index.js` | ~2365–2378 |
| BIST100 bootstrap `BIST100_OCT2026` | `functions/index.js` | ~2437–2448 |
| SOHOE/ORZAX `_baseBistStocks`'ta var | `lib/services/bist_stocks.dart` | 475, 568 |
| SOHOE/ORZAX `ipo_manual_overrides.json`'da | `data/ipo_manual_overrides.json` (git HEAD) | son 2 kayıt |
| Dart/JS BIST100 listesi farkı (14+14 sembol) | PowerShell diff analizi | — |
| `data/ipo_feed.json` boş (`items: []`) | `data/ipo_feed.json` | — |
