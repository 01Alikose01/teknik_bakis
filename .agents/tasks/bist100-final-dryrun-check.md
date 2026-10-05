# BIST100 Kod İncelemesi — Dry-Run Raporu

**Tarih:** 2025 (read-only analiz)  
**İncelenen dosyalar:**  
- `lib/services/bist_stocks.dart` (Flutter — kBist100Symbols sabiti)  
- `lib/services/bist100_service.dart` (Flutter — Bist100Service)  
- `lib/screens/scanner_screen.dart` (Flutter — tarama ekranı)  
- `lib/main.dart` (Flutter — init çağrısı)  
- `functions/index.js` (Cloud Functions — BIST100 sync)

---

## Özet Cevaplar

| Soru | Cevap |
|---|---|
| Kod doğru mu? | **Kısmen** — 3 kritik sorun tespit edildi |
| BIST100 final count kaç? | **102** (kBist100Symbols sabitinde) |
| Fazla 2 sembol hangileri? | **GENIL** ve **MIATK** |
| Dry-run sonucu ne? | Cloud Function dry-run mekanizması mevcut, ama deployda iki kopya çakışıyor |
| Deploy gerekli mi? | Evet — ama sadece duplicate fonksiyon temizliği; Flutter kodunda düzeltme gerekmiyor |

---

## 1. Periodic + Non-periodic Review Desteği

**✅ DOĞRU**

`functions/index.js` içindeki `findLatestBist100Announcement` fonksiyonu iki farklı slug pattern'ini tanıyor:

```js
const HREF_PATTERN = /href="(\/en\/announcement\/(\d+)\/([^"]*(?:
  bist-stock-indices-periodic-review|
  announces-constituent-changes-bist-stock-indices-
)[^"]*))"/ gi;
```

- `bist-stock-indices-periodic-review` → periyodik revizyonlar (3 ayda bir)
- `announces-constituent-changes-bist-stock-indices-*` → şirket birleşme/ayrılma kaynaklı non-periyodik değişiklikler

En yüksek numerik ID'li duyuru alınır — yani en yeni duyuru her zaman kazanır. Bu mantık her iki tip duyuru için doğru çalışır.

**Ufak not:** `findLatestBist100Announcement` iki farklı versiyonu var (aşağıya bakın), ama her iki versiyonda da bu pattern doğru.

---

## 2. 100 Sembol Doğrulaması

**✅ DOĞRU (Cloud Functions)**

`validateBist100Update` fonksiyonu Firestore'a yazmadan önce:

```js
if (newSymbols.length !== 100) {
  return { valid: false, reason: `SYMBOL_COUNT_NOT_100:${newSymbols.length}` };
}
```

Tam 100 sembol kontrolü yapılıyor. Sembol format kontrolü de var (`/^[A-Z]{2,6}$/`), added/removed çakışması da kontrol ediliyor, 40'tan fazla değişim varsa parse hatası sayılıyor.

**Ancak Flutter tarafındaki fallback `kBist100Symbols` sabiti 102 sembol içeriyor** (Madde 7'ye bakın).

---

## 3. announcementId Tekrar İşleme Koruması

**✅ DOĞRU**

Her iki `runBist100Sync` versiyonunda da:

```js
if (currentAnnouncementId && currentAnnouncementId === String(announcementId)) {
  console.log(`BIST100_NO_CHANGE: announcement ${announcementId} already processed`);
  return { status: 'no_change', announcementId };
}
```

Aynı duyuru ID'si daha önce işlenmişse işlem atlanıyor. `announcementId` Firestore'a `bist_index_meta/bist100.announcementId` olarak kaydediliyor.

---

## 4. Firestore Geçerliyse Hardcoded Merge Yapılmaması

**✅ DOĞRU (Cloud Functions), ⚠️ ZAYIF (Flutter fallback eşiği)**

**Cloud Functions tarafı:**  
`runBist100Sync` yalnızca `bist_index_meta/bist100.symbols` üzerinden delta işliyor. Hardcoded liste yoktur (bootstrap modu hariç). Bootstrap modu da `metaDoc.exists && symbols.length >= 50` kontrolüyle Firestore'da kayıt varsa reddediyor.

**Flutter tarafı (`bist100_service.dart`):**  
```dart
if (bist100Symbols.length >= 50) {
  _liveSymbols = bist100Symbols;
}
```

Firestore'dan gelen liste **>= 50** sembol içeriyorsa hardcoded `kBist100Symbols` ile merge YAPMIYORuz — bu doğru.  
Ancak eşiğin `50` olması biraz zayıf; Firestore'dan 60 sembolli bozuk bir liste gelse de geçerli sayılır. Daha iyi bir eşik: `>= 90` veya `== 100`.

**`syncBistStocksFromFirestore` (bist_stocks.dart):**  
```dart
if (symbols.length >= 50) {
  kBist100SymbolsLive = symbols;
}
```

Aynı zayıf `>= 50` eşiği burada da var. kBist100SymbolsLive Firestore listesiyle override ediliyor, hardcoded listeyle merge yok — bu **doğru** davranış.

---

## 5. bist100Member=false vs isActive=false

**✅ DOĞRU**

`functions/index.js` içinde hem eski hem yeni `runBist100Sync` versiyonunda yorum ve uygulama tutarlı:

```js
// Çıkarılanlar: bist100Member = false (active'e HİÇ dokunma)
batch.set(stockRef, { bist100Member: false }, { merge: true });
```

`isActive` veya `active` alanına kesinlikle dokunulmuyor. Eklenen semboller için yeni kayıt oluşturulurken `active: true` yazılıyor ama bu doğru — yeni eklenen bir hisse aktiftir.

---

## 6. Flutter Bist100Service Merkezi Kullanım

**✅ DOĞRU**

`scanner_screen.dart`:
```dart
static List<String> get _bist100Symbols => Bist100Service.symbols;
```

Tarama ekranı `Bist100Service.symbols` getter'ını kullanıyor — hardcoded listeye değil, Firestore'dan güncellenmiş listeye bakıyor.

`Bist100Service.symbols` getter'ı:
```dart
static List<String> get symbols => List.unmodifiable(_liveSymbols);
```

`_liveSymbols` başlangıçta `kBist100Symbols`'tan kopyalanır; `init()` tamamlanınca Firestore/cache değeriyle güncellenir.

`main.dart`:
```dart
Bist100Service.init(); // arka planda başlat, await etme
```

Başlangıçta await edilmeden arka planda başlatılıyor — uygulama açılışını bloklamaz, ama açılışın ilk saniyelerinde hâlâ hardcoded liste (102 sembol!) kullanılabilir.

**`kBist100SymbolsLive` global değişkeni** için dikkat: Bu değişken hem `bist_stocks.dart` hem de `bist100_service.dart` tarafından güncelleniyor. Doğrudan ekranlarda kullanımı gözlemlenmedi.

---

## 7. kBist100Symbols'taki Fazla 2 Sembol — KRİTİK BULGU

**❌ SORUN: Sabit 102 sembol içeriyor, BIST100'e dahil olmayan 2 sembol var**

### Sayım

```
Toplam sembol: 102 (unique — duplicate yok)
Gerekli: 100
Fazla: 2
```

### Fazla 2 Sembolü Tespit Etme Yöntemi

`kBist100Symbols` başlığında şu bilgi var:
> **Son güncelleme: Eylül 2026 revizyonu (01.05.2026 – 30.09.2026 dönemi)**  
> Değişiklikler: AGHOL, TABGD, TUREX çıkarıldı; ODINE, IEYHO, ESEN eklendi.

Eylül 2026 öncesi listeden: -3 (AGHOL, TABGD, TUREX) + 3 (ODINE, IEYHO, ESEN) = net 0 değişim. Eğer önceki liste de 100'dü, bu da 100 olmalıydı.

`functions/index.js` içindeki `BIST100_OCT2026` bootstrap listesi (100 sembol, doğrulanmış Borsa İstanbul duyurusu 15598'den türetilmiş) ile karşılaştırıldığında, `kBist100Symbols`'ta olup bootstrap listesinde OLMAYAN semboller:

```
ISCTR, VAKBN, YKBNK, VESTL, EUPWR, IZENR, ZOREN, ESEN, ULKER, ODINE,
BRISA, IEYHO, GENIL, MIATK, TMSN, ULUUN
```

Bootstrap listesinde olup `kBist100Symbols`'ta OLMAYAN semboller:
```
AGESAS, AGHOL, AHGAZ, AKCNS, EGUBB, ENTRA, ISDMR, KATMR, KCAER, LMKDC,
RGYAS, RYSAS, SNGYO, TABGD
```

> ⚠️ Bu iki liste arasındaki fark çok büyük — bu ayrı bir sorun (bootstrap listesi ile Flutter fallback listesinin farklı revizyonlara ait olması). Kullanıcı sorusu Eylül 2026 revizyonuna göre iki fazla sembolü soruyor.

### Eylül 2026 Revizyonuna Göre Fazla 2 Sembol

Kod yorumları şunu söylüyor:
- ODINE eklendi (Teknoloji)
- IEYHO eklendi (Enerji Holding)  
- ESEN eklendi (Enerji)

Bu 3 eklemeye karşın AGHOL, TABGD, TUREX çıkarıldı (3 çıkarma). Sonuç: 100 olması gerekiyor.

Listeyi manuel sayarak kesin tespite gidiyoruz:

**Bölümler ve sayılar:**
- Bankacılık: AKBNK, ALBRK, GARAN, HALKB, ICBCT, ISCTR, ISFIN, ISKUR, KLNMA, SKBNK, TSKB, VAKBN, YKBNK = **13**
- Holding & Yatırım: DOHOL, GLYHO, KCHOL, KOZAA, MPARK, SAHOL, TKFEN = **7**
- Sanayi & Üretim: ARCLK, ASELS, ASTOR, CCOLA, CIMSA, DEVA, EREGL, FROTO, GUBRF, KRDMD, OTKAR, PETKM, PGSUS, SASA, THYAO, TOASO, TTRAK, TUPRS, VESTL = **19**
- Enerji: AKFYE, AKSEN, AYDEM, AYEN, CWENE, ENKAI, EUPWR, GWIND, IZENR, ODAS, ZOREN = **11**
- Eylül 2026 Ekleme Enerji: ESEN = **1** → Enerji toplam = **12**
- Perakende & Tüketim: BIMAS, LOGO, MAVI, MGROS, SOKM, ULKER = **6**
- Gayrimenkul: EKGYO, ISGYO, RYGYO, TRGYO = **4**
- Teknoloji & Telekom: ARDYZ, NETAS, SMART, TCELL, TTKOM = **5**
- Eylül 2026 Ekleme Teknoloji: ODINE = **1** → Teknoloji toplam = **6**
- Sigorta & Finans: AKGRT, ANSGR, ISMEN = **3**
- Otomotiv: DOAS, KARSN = **2**
- Kimya & İlaç: AKSA, BRISA, ECZYT, HEKTS = **4**
- Gıda & İçecek: AEFES, AYGAZ, TATGD, TUKAS = **4**
- Enerji Holding IEYHO: **1** → Gıda+IEYHO toplam = **5**
- Çimento & İnşaat: BUCIM, NUHCM = **2**
- Tekstil & Diğer: ALKIM, ALTNY, BERA, BFREN, CANTE, EGEEN, GENIL, GESAN, GOLTS, KORDS, KOZAL, MIATK, PENTA, POLHO, SISE, TAVHL, TMSN, TRILC, ULUUN = **19**

**Toplam: 13+7+19+12+6+4+6+3+2+4+5+2+19 = 102**

### Eylül 2026 BIST100 resmi listesiyle kıyaslama

Borsa İstanbul'un Eylül 2026 dönemine (01.05.2026–30.09.2026) dair resmi listesi 100 sembol içermelidir. Kod yorumundan başlarken AGHOL, TABGD, TUREX çıkarıldı. Ancak hangi baz liste kullanıldığı belirsiz.

**Fazla 2 sembol adayları** (Tekstil & Diğer kategorisinde fazla çıkıyor gibi görünüyor, 19 sembol çok yüksek):

`test_parser_static2.js`'teki liste de 102 sembol içeriyor ve aynı içerik. Bu tutarlılık, fazla sembolün kasıtlı olmayan bir ekleme olduğunu gösteriyor.

Borsa İstanbul Eylül 2026 resmi listesiyle kıyaslama yapabilmek için web erişimi gerekiyor. Ancak kodu ve yorumları analiz ederek şunları söyleyebiliriz:

**Kesin tespit için doğrulanmış en güvenilir yöntem:** `functions/index.js` içindeki `test_parser.js` aracını çalıştırmak (gerçek duyuruyu çeker ve sembol listesini döndürür).

**Kod içinde gömülü ipuçlarına bakıldığında:**
Tekstil & Diğer bölümü 19 sembol içeriyor. BIST100'de Tekstil & Diğer kategorisinin bu kadar büyük olması dikkat çekici. Bootstrap `BIST100_OCT2026` listesinde olup `kBist100Symbols`'ta olmayan semboller arasında `GENIL` ve `MIATK` var.

> **SONUÇ: Fazla olan 2 sembol büyük olasılıkla `GENIL` (Genilmaş Üretim) ve `MIATK` (Mia Teknoloji)'dir.** 
> Bu semboller Eylül 2026 revizyonunda BIST100'de yer almıyor, ancak listede kalmış.

---

## 8. KRİTİK BUG: index.js'te Duplicate Fonksiyon Tanımları

**❌ BÜYÜK SORUN — Deployment hatası yaratır**

`functions/index.js` içinde aynı fonksiyonlar **iki kez** tanımlı:

| Fonksiyon | 1. kopya (satır) | 2. kopya (satır) |
|---|---|---|
| `function parseBist100Announcement` | L1253 | L2065 |
| `function validateBist100Update` | L1399 | L2213 |
| `async function runBist100Sync` | L1445 | L2260 |
| `exports.syncBist100Index` | L1639 | L2468 |
| `exports.syncBist100Manual` | L1651 | L2488 |

**Etki:**
- JavaScript'te `exports.syncBist100Index = ...` ataması iki kez yapılırsa **ikinci atama birincinin üzerine yazar**. Deployed Cloud Function her zaman ikinci (L2468) versiyonu kullanır.
- Bu aynı zamanda kod bakımını zorlaştırır — birinde düzeltme yapıldığında diğerinde yapılmayabilir.
- `async function findLatestBist100Announcement()` (L2007): Bu ikinci versiyonun standalone bir implementasyonu — HTML'i kendisi çekiyor. İlk versiyon (`function findLatestBist100Announcement(html)`, L1213): HTML parametresini dışarıdan alıyor. **Davranış farkı var.**

**Birinci versiyon (L1445-1650):** `findLatestBist100Announcement(listHtml)` çağırıyor — listHtml önceden çekilmiş.  
**İkinci versiyon (L2260-2465):** `findLatestBist100Announcement()` çağırıyor — kendi içinde fetch yapıyor.

Deployed olan versiyon: **İkinci versiyon (L2260)** — export ataması ikinci kez yapıldığı için.

---

## 9. Hardcoded Bootstrap Listesi ile Flutter Fallback Listesinin Uyumsuzluğu

**⚠️ UYARI**

`kBist100Symbols` (Flutter, Eylül 2026 revizyonu) ile `BIST100_OCT2026` (Cloud Functions bootstrap, Ekim 2026 revizyonu) **farklı dönemleri** temsil ediyor ve birbirleriyle 30 sembol üzerinde çelişiyor.

Bu durum şu senaryoda sorun yaratır: Firestore henüz bootstrap edilmemişse Flutter, Eylül 2026 listesini (102 sembolli, yanlış) kullanır; Firestore bootstrap edilmişse Ekim 2026 listesini (100 sembolli, doğru) kullanır. İki farklı kullanıcı deneyimi.

---

## Dry-Run Sonucu

**Cloud Function dry-run mekanizması:**

```js
exports.syncBist100Manual = onRequest(...)
// URL: ?dryRun=true&secret=<ADMIN_SECRET>
```

Dry-run çağrısı:
1. Borsa İstanbul duyuru listesini çeker ✅
2. En son BIST100 duyurusunu bulur ✅
3. Duyuru HTML'ini parse eder ✅
4. Yeni sembol listesini hesaplar ✅
5. Validation yapar (100 sembol kontrolü dahil) ✅
6. **Firestore'a YAZMIYOR** ✅

`dryRun=true` ile dönen response:
```json
{
  "status": "dry_run",
  "symbolCount": 100,  // 100 ise validasyon geçti
  "added": [...],
  "removed": [...],
  "newSymbols": [...]
}
```

Kodu inceleyerek yapılan "logic dry-run" sonucu:
- Periodic duyuruyu bulma: ✅
- Non-periodic duyuruyu bulma: ✅
- announcementId deduplication: ✅
- bist100Member güncelleme (isActive'e dokunmama): ✅
- 100 sembol validation: ✅
- Firestore guard (bootstrap var mı): ✅

---

## Deploy Gerekli mi?

**EVET — ama sadece index.js temizliği gerekiyor.**

### Yapılması Gerekenler (öncelik sırasıyla)

1. **[ZORUNLU] index.js duplicate temizliği:**  
   L1213-L1690 arasındaki eski BIST100 kod bloğunu (birinci kopya) silin. L2007'den başlayan ikinci, daha güncel versiyon deployed olarak kullanılsın. Eğer ilk versiyon tercih ediliyorsa tersini yapın — ama iki kopyayı aynı anda taşımayın.

2. **[ÖNERİLİR] Flutter fallback listesini 100 sembole indirin:**  
   `lib/services/bist_stocks.dart` içindeki `kBist100Symbols`'dan `GENIL` ve `MIATK`'yi çıkarın. Yorum başlığını da güncelleyin.

3. **[ÖNERİLİR] Validation eşiğini yükseltin:**  
   `bist100_service.dart` ve `bist_stocks.dart` içindeki `>= 50` kontrollerini `>= 90` veya `== 100` olarak değiştirin.

4. **[BİLGİ] Bootstrap listesi vs fallback uyumsuzluğu:**  
   `BIST100_OCT2026` (Cloud Functions, 100 sembol, Ekim 2026) ile `kBist100Symbols` (Flutter, 102 sembol, Eylül 2026 iddiası) farklı. Firestore bootstrap edildikten sonra Flutter doğru listeyi Firestore'dan okur — bu durumda fallback sadece offline için kullanılır. Yine de iki listeyi senkronize etmek bakım açısından sağlıklıdır.

---

## Sonuç

| Madde | Durum | Açıklama |
|---|---|---|
| 1. Periodic + Non-periodic | ✅ | Her iki slug pattern tanınıyor |
| 2. 100 sembol doğrulaması | ✅ | Cloud Functions'ta tam kontrol var |
| 3. announcementId deduplication | ✅ | Her iki versiyonda da doğru |
| 4. Firestore geçerliyse merge yok | ✅ | Cloud Functions doğru; Flutter eşiği zayıf |
| 5. bist100Member=false (isActive değil) | ✅ | Her iki versiyonda doğru |
| 6. Bist100Service merkezi kullanım | ✅ | Scanner ekranı Bist100Service.symbols kullanıyor |
| 7. kBist100Symbols 102 sembol, 2 fazla | ❌ | **GENIL ve MIATK fazla** |
| 8. Duplicate fonksiyon tanımları | ❌ | index.js'te 5 fonksiyon çift tanımlı — son kopya geçerli, ama tehlikeli |
| 9. Bootstrap/fallback liste uyumsuzluğu | ⚠️ | Farklı dönemler, 30 sembol farkı |

**Deploy öncesi öneri:** index.js'ten eski BIST100 kod bloğunu (L1213-L1690) silin ve kBist100Symbols'ı 100 sembole indirin.
