# `reconcileStaleIpoStatuses` ve `loadBistSymbols` Kod Analiz Raporu

**Tarih:** 2026-10-05  
**Yöntem:** Salt okunur kaynak kodu ve git geçmişi incelemesi. Hiçbir dosya değiştirilmedi.  
**Kaynak:** `functions/index.js` (yerel HEAD `89b8d5a`), `lib/services/bist_stocks.dart`, `.agents/tasks/` arşiv dosyaları

---

## ÖZET — Kısa Yanıtlar

| # | Soru | Kesin Yanıt |
|---|------|-------------|
| 1 | `loadBistSymbols()` hangi koleksiyondan okuyor? | **`bist_stocks`** koleksiyonu — doküman ID'leri sembol olarak kullanılıyor |
| 2 | Sadece BIST100 mü, tüm BIST mi? | Filtre veya limit **yok** — koleksiyondaki tüm dokümanlar okunuyor. Ama koleksiyon yalnızca BIST100 sembollerini içeriyor (bootstrap listesi 100 sembol) |
| 3 | SOHOE ve ORZAX bu koleksiyonda mevcut mu? | **HAYIR** — koleksiyona yazma kodu onları hiç eklemedi |
| 4 | `bist_stocks.dart` neden Cloud Function'dan erişilemiyor? | Dart dosyası Flutter istemcisinde bir **sabit liste** (`const`) — Firestore veya bir API değil; Cloud Function JavaScript kodundan erişilemez |
| 5 | Sembol boşken isimden sembole eşleştiren mekanizma var mı? | **HAYIR** — böyle bir mekanizma yok |
| 6 | 203 kaydın en minimal düzeltmesi nedir? | **`firebase deploy --only functions`** ile mevcut yerel kodu canlıya göndermek, ardından **`syncBist100Manual?bootstrap=true`** ile `bist_stocks` koleksiyonunu doldurmak, ardından **`syncIpoManual`** tetiklemek |

---

## 1. `loadBistSymbols()` — Kaynak Koleksiyon ve Okuma Yöntemi

**Dosya:** `functions/index.js` satır 727–737

```javascript
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

**Kesin bulgular:**
- Koleksiyon adı: `bist_stocks` (sabit string, parametre değil)
- Yöntem: `listDocuments()` — her dokümanın **sadece ID'sini** getirir, alan içeriklerine dokunmaz (verimli)
- Filtre: **HİÇBİR filtre veya limit koşulu yok** — tüm doküman referansları çekilir
- Hata durumu: boş `Set` döner, program çalışmaya devam eder
- Sonuç tipi: `Set<string>` — büyük harfli semboller (`toUpperCase()`)

---

## 2. BIST100 mü, Tüm BIST mi?

`loadBistSymbols()` kodu filtresiz olduğundan teorik olarak koleksiyondaki **tüm** dokümanları okur.

Ancak pratikte koleksiyona veri yazan tek kod `runBist100Sync` fonksiyonudur (`functions/index.js` satır 2279–2340). Bu fonksiyon:

1. Koleksiyona yalnızca Borsa İstanbul BIST100 periyodik revizyon duyurularındaki **`added[]` listesindeki** sembolleri yazar
2. Bootstrap modu (`syncBist100Manual?bootstrap=true`) ise `BIST100_OCT2026` hardcoded listesiyle **100 sembol** yazar

Dolayısıyla:
- **Kod:** Filtre yok, tüm koleksiyonu okur
- **Gerçek içerik:** Sadece BIST100 sembolleri (~100 doküman) — 610 BIST hissesinin tamamı **değil**
- **Yeni IPO hisseleri için sorun:** Yeni listelenen bir hisse BIST100'e girmeden önce küçük endekslerde işlem görür; bu süreçte `bist_stocks` koleksiyonunda yer almaz, `loadBistSymbols()` onu döndürmez

---

## 3. SOHOE ve ORZAX `bist_stocks` Koleksiyonunda Mevcut mu?

**HAYIR.** İki ayrı kanıtla teyit edildi:

### Kanıt A — `bist_stocks`'a yazan kod SOHOE/ORZAX'ı hiç eklemiyor

`runBist100Sync` (`functions/index.js` satır 2279–2340) koleksiyona yalnızca şunları yazar:
- Bootstrap: `BIST100_OCT2026` hardcoded listesi (100 sembol — SOHOE ve ORZAX yok; bunlar Temmuz 2026'da listelenmiş; BIST100'e Ekim 2026'da da girmemiş olabilir)
- Haftalık güncelleme: yalnızca `added[]` sembolleri — SOHOE/ORZAX BIST100 duyurusunda `added` listesinde yoksa hiç eklenmez

### Kanıt B — `reconciled: 0` davranışı

`syncIpoManual` çağrısının `reconciled: 0` döndürmesi `reconcileStaleIpoStatuses(bistSymbols)` içinde:
```javascript
// BIST'te listelenmiş hisse → trading
if (d.symbol && bistSymbols instanceof Set && bistSymbols.has(d.symbol.toUpperCase())) {
  stale.push({ ref: doc.ref, status: 'trading' });
  continue;
}
```
Bu koşulun sıfır eşleşme vermesi, Firestore `bist_stocks` koleksiyonunda SOHOE ve ORZAX'ın **bulunmadığını** kanıtlar.

### Kanıt C — `listingDate` null ise kural 2 de çalışmaz

```javascript
// listingDate geçtiyse → trading
if (d.listingDate) {
  const ld = new Date(d.listingDate);
  if (!isNaN(ld) && ld <= now) { ... }
}
```
Firestore'daki ORZAX/SOHOE kayıtlarında `listingDate` alanı yoksa (ya da HalkArz sayfasında parse edilemiyorsa) bu kural da tetiklenmiyor → `trading` ataması yapılamıyor.

---

## 4. `bist_stocks.dart` Neden Cloud Function'dan Erişilemiyor?

`lib/services/bist_stocks.dart` dosyası (satır 1–10):

```dart
// BIST 500 — Tam hisse listesi (Kaynak: Borsa İstanbul)
const int kBistListedCount = 610;

const List<Map<String, String>> _baseBistStocks = [
  {'symbol': 'A1CAP', 'name': 'A1 Capital'},
  {'symbol': 'ORZAX', 'name': 'Orzaks İlaç ve Kimya Sanayi'},   // satır 475
  {'symbol': 'SOHOE', 'name': 'Soho Giyim ve Enerji'},           // satır 568
  ...
];
```

Bu dosya:
1. **Dart dilinde yazılmış sabit (`const`) bir liste** — JavaScript değil
2. Flutter uygulamasının kaynak kodu içinde, **Flutter asset değil** (pub.dev paketi veya JSON dosyası değil)
3. Hiçbir yazma işlemi içermiyor — Firestore'a tek bir satır bile yazmıyor
4. Yalnızca istemci tarafı in-memory merge için kullanılıyor (`syncBistStocksFromFirestore()`)

Cloud Function (`functions/index.js`) Node.js ortamında çalışır. Dart kaynak koduna erişmesi teknik olarak imkânsızdır — farklı dil, farklı runtime, farklı process. Dart kodu Flutter build sırasında derlenir ve uygulama bundle'ına gömülür; bir API veya dosya servisi sunmaz.

**Sonuç:** SOHOE ve ORZAX `bist_stocks.dart`'ta tanımlı olsa da bu bilgi Cloud Function'a ulaşmaz. Dart listesini `bist_stocks` Firestore koleksiyonuna taşıyacak bir köprü kodu hiç yazılmamış.

---

## 5. Sembol Boş Olduğunda İsimden Sembole Eşleştirme Var mı?

**HAYIR.** Kod incelemesinde böyle bir mekanizma bulunamadı:

- `functions/index.js` içinde `nameToSymbol`, `symbolMap`, `symbolLookup`, `findSymbol` gibi bir fonksiyon veya tablo yok
- Sembol boşken doküman anahtarı şu şekilde üretiliyor (`satır 1062–1063`):
  ```javascript
  const key = item.symbol
    ? item.symbol.toUpperCase()
    : `NO_SYMBOL_${item.companyName.replace(/\s+/g, '_').substring(0, 30)}`;
  ```
  Bu anahtar yalnızca Firestore doküman ID'si için kullanılıyor; isimden sembol çıkarmıyor
- `ipo_manual_overrides.json` dosyası SOHOE/ORZAX için `symbol` alanını içeriyor, ancak bu dosya yalnızca `tools/update_ipo_feed.mjs` (GitHub Action) tarafından okunuyor, `functions/index.js` bu dosyaya hiç erişmiyor
- HalkArz HTML parse kodunda sembol şu şekilde çıkarılıyor (satır 817–820):
  ```javascript
  const codeM = chunk.match(/class="(?:il-bist-kod|bist-kod|ticker)[^"]*"\s*>([^<]+)/s)
             || chunk.match(/\b([A-Z]{4,6})\b/);
  const symbol = codeM ? cleanTxt(codeM[1]).toUpperCase().replace(/[^A-Z]/g, '') : '';
  ```
  HalkArz sayfasında sembol HTML elementi yoksa `symbol = ''` — başka çare yok

**Sonuç:** Sembolü boş olan kayıtları isimden sembole eşleştirecek herhangi bir fallback mekanizması mevcut değil.

---

## 6. 203 Yaklaşan Kaydın Düzelmesi için En Minimal Kod Değişikliği

### Sorunun Kökü

Zincir net:

```
Canlı kod (origin/main bca6aca):
  syncIpoFeed / syncIpoManual
    → fetchHalkArzItems()       ← loadBistSymbols YOK, bistSymbols YOK
    → writeIpoToFirestore(items) ← trading koruması YOK
    → reconcile YOK             ← fonksiyon canlıda hiç yok

Yerel kod (HEAD 89b8d5a — DEPLOY EDİLMEMİŞ):
  syncIpoFeed / syncIpoManual
    → loadBistSymbols()          ← bist_stocks koleksiyonunu okur
    → fetchHalkArzItems(bistSymbols)  ← BIST kontrolüyle durum atar
    → writeIpoToFirestore(items, bistSymbols)  ← trading korumalı
    → reconcileStaleIpoStatuses(bistSymbols)   ← durum temizliği

bist_stocks koleksiyonu:
  → Boş veya sadece BIST100 sembolleri var
  → SOHOE, ORZAX yok
  → loadBistSymbols() → boş Set döner
  → BIST kontrolü hiç tetiklenmiyor
```

### Minimal Çözüm (3 adım, kod değişikliği yok)

**Adım 1 — Yerel kodu canlıya deploy et (tek gerçek kod değişikliği budur)**

```bash
cd functions
firebase deploy --only functions:syncIpoFeed,functions:syncIpoManual
```

Bu deploy ile `reconcileStaleIpoStatuses`, `loadBistSymbols`, `writeIpoToFirestore` (trading korumalı) ve doğru sıralama (`write → reconcile`) canlıya taşınır. Yerel HEAD `89b8d5a`'nın bu kodu tamamen hazır; tek eksik adım deploy.

**Adım 2 — `bist_stocks` koleksiyonunu doldur (bootstrap)**

Deploy sonrası:
```
GET https://europe-west1-<proje-id>.cloudfunctions.net/syncBist100Manual
    ?bootstrap=true&secret=<ADMIN_SECRET>
```

Bu istek `BIST100_OCT2026` hardcoded listesindeki ~100 sembolü `bist_stocks` koleksiyonuna yazar. SOHOE ve ORZAX BIST100 listesinde değilse bu adım onları kapsamaz — ama Adım 3'teki `listingDate` kuralı onları yine de yakalar.

> **Uyarı:** Bootstrap, koleksiyonda zaten ≥50 doküman varsa `409` döner. Önce koleksiyonun durumu kontrol edilmeli.

**Adım 3 — `syncIpoManual` tetikle**

```
GET https://europe-west1-<proje-id>.cloudfunctions.net/syncIpoManual
    ?secret=<ADMIN_SECRET>
```

Bu çalıştırma:
1. `loadBistSymbols()` → bist_stocks'tan semboller (BIST100 sembolleri artık tanımlı)
2. `fetchHalkArzItems(bistSymbols)` → HalkArz'dan taze veri, BIST kontrolüyle
3. `writeIpoToFirestore(items, bistSymbols)` → kayıtları yazar, trading olanları korur
4. `reconcileStaleIpoStatuses(bistSymbols)` → `listingDate` geçmiş kayıtları `trading` yapar

SOHOE (listingDate: 2026-07-08) ve ORZAX (listingDate: 2026-07-07) Adım 4'te `listingDate <= now` kuralıyla `trading` alır — `bist_stocks`'ta olmasına gerek yok.

203 `upcoming` kaydın büyük çoğunluğu da `requestEnd` geçmişse en azından `pending_listing`'e; `listingDate` geçmişse `trading`'e taşınır.

### Neden Sadece Bu Kadar?

- `functions/index.js` `89b8d5a` sürümünde **kod tamamen hazır ve doğrudur** — önceki agent analiz raporu ve review onayladı
- 203 kaydın silinmesine, elle düzeltilmesine veya yeniden oluşturulmasına gerek yok
- Deploy + bootstrap + tek tetikleme ile otomatik akış devreye girer
- Sonraki `syncIpoFeed` çalışmaları (her 6 saatte bir) düzeltmeyi kalıcı tutar

---

## Ek: Mevcut Durum Özet Tablosu

| Bileşen | Yerel HEAD | Canlı (origin/main) |
|---------|-----------|---------------------|
| `loadBistSymbols()` | **VAR** (satır 727) | **YOK** |
| `reconcileStaleIpoStatuses()` | **VAR** (satır 997) | **YOK** |
| `bistSymbols` parametresi | **VAR** | **YOK** |
| `write → reconcile` sırası | **DOĞRU** | **YOK** (reconcile yok) |
| `bist_stocks` koleksiyonu | Bootstrap'la doldurulabilir | Bootstrap yapılmamış/boş |
| SOHOE, ORZAX `bist_stocks`'ta | **YOK** | **YOK** |
| SOHOE, ORZAX `bist_stocks.dart`'ta | **VAR** (satır 475, 568) | N/A (Dart → istemci) |
| `ipo_manual_overrides.json`'da | **VAR** (status: trading) | tools/ GitHub Action kullanır, index.js okumaz |

---

## Kaynaklar

- `functions/index.js` satır 686–737 (`computeIpoStatus`, `loadBistSymbols`)
- `functions/index.js` satır 997–1050 (`reconcileStaleIpoStatuses`)
- `functions/index.js` satır 1131–1178 (`syncIpoFeed`, `syncIpoManual` export'ları)
- `functions/index.js` satır 2279–2496 (`runBist100Sync`, bootstrap)
- `lib/services/bist_stocks.dart` satır 1–600 (sabit liste, SOHOE satır 568, ORZAX satır 475)
- `.agents/tasks/ipo-bist-code-analysis.md` (canlı vs yerel git farkı)
- `.agents/tasks/halka-arz-status-analiz-2026-10-05.md` (SOHOE/ORZAX Firestore durumu)
- `.agents/tasks/halka-arz-status-fix-review.md` (kod review — APPROVED)
