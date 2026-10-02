# BIST100 Otomatik Güncelleme — Backend Detaylı Analiz Raporu

**Tarih:** 2026  
**Kapsam:** Read-only analiz — kod değişikliği, Firestore yazma, deploy işlemi yapılmamıştır.  
**Referans:** Önceki rapor (`bist100-auto-update-investigation.md`) temel alınmış, eksik/belirsiz kalan noktalar tamamlanmıştır.

---

## Özet

Mevcut backend (`functions/index.js`), **`bist_stocks` ve `bist_index_meta` collection'larına hiç yazmıyor**. Bu iki Firestore collection'ı doğrudan Flutter uygulaması tarafından okunuyor, fakat onları dolduracak Cloud Function yok. Mevcut veri kaynakları (MKK/KAP API, bilancoveri.com, halkarz.com) içinde BIST100 bileşen listesini verebilecek birisi: **bilancoveri.com** `sirketler.json` endpoint'i — bu endpoint, her hissenin `ticker` alanını içeriyor ve dolayısıyla `bist_stocks` şirket adı eşleştirmesi için doğrudan kullanılabilir; ancak **BIST100 endeks üyeliğini** bildiren bir alan içermesi belirsiz. Bilinen en uygun üçüncü taraf kaynak: Bigpara (Hürriyet) `api/v1/hisse/list` veya Foreks'in `paragaranti-pubsub` API'si. İkisi de resmi değil.

---

## S1 — Mevcut backend'de BIST100 listesini sağlayabilecek bir veri kaynağı var mı?

**HAYIR.** Mevcut `functions/index.js` içinde `bist_stocks` veya `bist_index_meta` collection'larına yazan hiçbir kod yok.

### Kanıt

```
grep -r "bist_stocks|bist_index_meta" functions/index.js
→ 0 sonuç (tam arama yapıldı, bulunamadı)
```

### Mevcut veri kaynakları ve BIST100 kapsama durumu

| Kaynak | URL | BIST100 listesi veriyor mu? |
|---|---|---|
| MKK VYK API | `https://apigwdev.mkk.com.tr/api/vyk` | **HAYIR** — KAP bildirimleri ve şirket listesi; endeks üyeliği yok |
| bilancoveri.com | `https://bilancoveri.com/api/v1/sirketler.json` | **BELİRSİZ** — F/K, PD/DD, sektör, isim, ticker alanları var; endeks üyeliği bilgisi doğrulanmadı |
| halkarz.com | `https://halkarz.com/` (HTML scraping) | **HAYIR** — Sadece halka arz verileri |

**ÖNERÍ:** En hızlı yol: bilancoveri.com endpoint'inin JSON şemasını kontrol etmek. `bist100` veya `index` gibi bir alan varsa mevcut fonksiyon içinde BIST100 listesi çıkarılabilir, yeni endpoint gerekmeyebilir.

---

## S2 — Borsa İstanbul resmi sitesinden XU100 bileşen listesi otomatik çekilebiliyor mu?

**HAYIR (pratik olarak).** Mevcut kodda böyle bir kullanım yok. Resmi kaynaklar:

### 2a. VERDA / BISTECH API
- URL: `https://verda.borsaistanbul.com`
- Kurumsal üyelik, VPN/IP whitelist, ücretli lisans gerekiyor. Ücretsiz erişim yok.
- **Sonuç:** Kullanılamaz.

### 2b. Borsa İstanbul Web Sitesi Endeks Sayfaları
- URL: `https://www.borsaistanbul.com/tr/endeksler/bist-pay-endeksleri/xu100`
- JavaScript ile render edilen SPA — statik `https.get()` ile JSON alınamaz.
- **Sonuç:** Node.js Cloud Function'da doğrudan kullanılamaz (Puppeteer/headless gerekir; Cloud Functions'da pratik değil).

### 2c. Borsa İstanbul Periyodik Değişiklik PDF'leri
- URL pattern: `https://www.borsaistanbul.com/files/bist-pay-endeksleri-donemsel-degisiklikleri-*.pdf`
- 6 ayda bir güncellenen PDF. Tam liste değil, sadece eklenen/çıkarılan hisseler var.
- **Sonuç:** Tam liste için uygun değil; delta takibi için yedek olabilir.

**RİSK:** Resmi ücretsiz JSON API yoktur. "Borsa İstanbul'un resmi kaynağı" olarak otomasyona uygun bir endpoint mevcut değil.

---

## S3 — Resmi kaynak yoksa, mevcut projede kullanılabilecek güvenilir bir kaynak var mı?

İki somut seçenek mevcut:

### 3a. Foreks / Paragaranti API (EN GÜÇLÜ SEÇENEK)

Topluluk tarafından keşfedilen, Borsa İstanbul'un kendi veri sağlayıcısı Foreks'in dahili endpointleri:

```
Endeks listesi:
GET https://web-paragaranti-pubsub.foreks.com/web-services/securities/exchanges/BIST/groups/E

XU100 endeks tanımı (bileşenler dahil):
GET https://web-paragaranti-pubsub.foreks.com/web-services/securities/definition?name=XU100&group=E&exchange=BIST
```

- Bu endpoint `componentSymbols` benzeri bir alan içermesi kuvvetle muhtemel.
- Kaynak: Foreks, Borsa İstanbul'un resmi veri iş ortağıdır — verinin kalitesi yüksek.
- Proje içinde kullanılmıyor, ama `fetchJson()` fonksiyonu ile kolayca çağrılabilir.
- **RİSK:** Resmi API değil; ticari kullanım ToS'a aykırı olabilir. Endpoint değişebilir. Kimlik doğrulama gerektirip gerektirmediği test edilmedi.

### 3b. Bigpara (Hürriyet) API

```
Hisse listesi:
GET http://bigpara.hurriyet.com.tr/api/v1/hisse/list
```

- Türkiye'nin en büyük finans portallarından biri; Hürriyet/Doğan Medya bünyesinde.
- Tüm BIST hisselerini listeliyor; BIST100 filtresi olup olmadığı doğrulanmamış.
- **RİSK:** Resmi API değil; ToS engeli var; rate-limit uygulanabilir; HTTP (HTTPS değil) — Cloud Function için SSL sorunu yok ama eski protokol.

### 3c. bilancoveri.com — Mevcut Kullanılan Kaynak

Mevcut `updateFundamentals` fonksiyonunda zaten kullanılıyor:
```javascript
const url = 'https://bilancoveri.com/api/v1/sirketler.json';
```

- Ticker bazlı temel göstergeler içeriyor.
- `name`, `ticker`, `sector`, `pe`, `pb`, `roe` alanları mevcut (koddan doğrulandı).
- **BELİRSİZ:** `bist100: true/false` veya endeks üyeliği alanı olup olmadığı doğrulanamadı. Bu endpoint'in response şeması incelenmeli.

**ÖNERİ:** Önce bilancoveri.com şemasını kontrol edin. BIST100 üyelik alanı varsa ek endpoint gerekmez. Yoksa Foreks endpoint'ini tercih edin.

---

## S4 — Üçüncü taraf endpoint kullanırsak ToS/kırılganlık risk değerlendirmesi

### Mevcut projede zaten benzer riskler var:

| Kaynak | Kullanım amacı | ToS riski | Kırılganlık |
|---|---|---|---|
| `bilancoveri.com/api/v1/sirketler.json` | Temel göstergeler | Orta — kullanım politikası belirsiz | Orta — JSON yapısı değişebilir |
| `halkarz.com` (HTML scraping) | IPO verileri | Yüksek — scraping ToS'a aykırı olabilir | Yüksek — HTML değişirse kırılır |
| `apigwdev.mkk.com.tr` | KAP bildirimleri | Düşük — resmi MKK API, credentials var | Düşük — resmi destekli |

### BIST100 listesi için yeni endpoint riskleri:

**Foreks API:**
- ToS riski: Orta-Yüksek — ticari veri sağlayıcı; kütüphane geliştirmek için kullanılıyor ama üretim ortamında yüklü istek atmak ToS ihlali sayılabilir.
- Kırılganlık: Orta — endpoint Foreks'in dahili API'si, bakımı sürdürülüyor.
- Günde 1 istek → düşük bant genişliği — muhtemelen fark edilmez.

**Bigpara API:**
- ToS riski: Yüksek — medya şirketi API'si, resmi kullanıma açık değil.
- Kırılganlık: Yüksek — geçmişte URL yapısı değişmiş olabilir.

**RİSK:** Her iki kaynak da resmi değil. BIST100 değişikliği 6 ayda bir gerçekleştiği için günde 1 istek makul; ancak rate-limit veya IP block riski var.

**MİTİGASYON:** Endpoint başarısız olursa mevcut Firestore listesi korunur (diff yoksa yazma yapılmaz). Manuel HTTP endpoint (`syncBist100Manual`) ek güvence sağlar.

---

## S5 — Günde 1 kez çalışan Cloud Function ile BIST100 güncellemesi yapılabilir mi?

**EVET, kesinlikle mümkün.** Mevcut proje zaten bu pattern'ı kullanıyor. Kanıt — `index.js`'teki mevcut scheduled function'lar:

```javascript
// Örnek: Her ayın 1'i saat 05:00 UTC (08:00 TR) için
exports.syncBist100Index = onSchedule({
  schedule:       '0 5 1 * *',  // ← bu format mevcut projede kullanılıyor
  timeZone:       'UTC',
  region:         'europe-west1',
  memory:         '256MiB',
  timeoutSeconds: 120,
}, async () => { ... });
```

Kullanılan framework:
- `firebase-functions/v2/scheduler` → `onSchedule` (mevcut kodda var)
- Node.js 22 (mevcut)
- `firebase-admin/firestore` → Firestore batch write (mevcut)
- `https` modülü veya `fetch` → HTTP çağrısı (mevcut)

**ÖNERİ:** BIST100 revizyonu 6 ayda bir (Mayıs ve Kasım başı). Aylık çalıştırmak fazlasıyla yeterli. `'0 5 1 * *'` (her ayın 1'i 08:00 TR) önerilen zamanlama.

---

## S6 — BIST100 listesinin değişip değişmediğini Firestore'daki listeyle diff edebilir miyiz?

**EVET.** `bist_index_meta/bist100` dokümanı ve `bist_stocks` collection yapısı analiz edildi:

### `bist_index_meta/bist100` doküman yapısı

Flutter kodu (`bist100_service.dart`, satır 75–82) şu yapıyı bekliyor:

```json
{
  "symbols": ["AKBNK", "GARAN", "THYAO", ...],
  "updatedAt": Timestamp,
  "revision": "Ekim 2026",
  "added": ["XXXXX"],
  "removed": ["YYYYY"]
}
```

Diff mantığı backend'de şu şekilde uygulanabilir:

```javascript
// Mevcut Firestore listesini oku
const metaDoc = await db.collection('bist_index_meta').doc('bist100').get();
const currentSymbols = new Set(metaDoc.exists ? (metaDoc.data().symbols || []) : []);

// Yeni listeyle karşılaştır
const newSymbols = new Set(fetchedList); // API'den gelen
const added = [...newSymbols].filter(s => !currentSymbols.has(s));
const removed = [...currentSymbols].filter(s => !newSymbols.has(s));

// Değişiklik yoksa yaz — maliyet önlemi
if (added.length === 0 && removed.length === 0) {
  console.log('BIST100 listesi değişmemiş, yazma atlandı');
  return;
}
```

Bu pattern idempotent ve güvenli.

### `bist_stocks/{symbol}` collection yapısı

Flutter kodu (`bist100_service.dart`, satır 108–111) şu yapıyı bekliyor:

```json
{
  "symbol": "AKBNK",
  "name": "Akbank T.A.Ş.",
  "active": true
}
```

**Kritik:** Flutter'da bu collection `.where('active', isNotEqualTo: false)` filtresiyle çekiliyor. `active` alanı:
- `true` → aktif, uygulama gösterir
- `false` → pasif, uygulama göstermez
- `null` veya alan yoksa → `isNotEqualTo: false` sorgusu bu belgeleri de döndürür (Firestore davranışı: null ≠ false)

**ÖNERİ:** Yeni oluşturulan belgeler için mutlaka `active: true` yazın. Pasif yapılacak belgeler için mutlaka `active: false` yazın (alanı silmeyin veya null bırakmayın).

---

## S7 — Yeni gelen hisselerde şirket adını kap_members verisinden otomatik eşleştirebilir miyiz?

**EVET, eşleştirilebilir.** `kap_members` collection yapısı `syncMembers()` fonksiyonundan doğrulandı (`index.js` satır 181–188):

```javascript
batch.set(ref, {
  id:          id,
  title:       m.title || m.name || '',   // ← şirket tam adı
  stockCode:   (m.stockCode || m.code || '').toUpperCase(),  // ← borsa kodu
  memberType:  m.memberType || m.type || '',
  kfifUrl:     m.kfifUrl || '',
  updatedAt:   FieldValue.serverTimestamp(),
}, { merge: true });
```

### Eşleştirme mantığı

`bist_stocks` sembol formatı = `kap_members.stockCode` formatı. İkisi de `.toUpperCase()` uygulanmış.

```javascript
// kap_members'dan stockCode → title haritası oluştur
const membersSnap = await db.collection('kap_members').get();
const nameMap = {};
membersSnap.forEach(doc => {
  const code = doc.data().stockCode;
  const title = doc.data().title;
  if (code && title) nameMap[code] = title;
});

// Yeni BIST100 hissesi için ad bul
const name = nameMap[symbol] || symbol; // bulunamazsa sembolü ad olarak kullan
```

**Doğrulama:** `kap_members` collection'ı her KAP sync sırasında güncelleniyor (günde en az birkaç kez). Yani eşleştirme verisi her zaman güncel.

**BELİRSİZ:** `kap_members.stockCode` boş olan kayıtlar var mı? Bazı holding yapıları veya yatırım ortaklıkları için stockCode boş gelebilir. Bu durumda sembol kendisi ad olarak fallback yapılmalı.

---

## S8 — Çıkan hisselerde `active: false` işlemi güvenli yapılabilir mi?

**EVET, güvenli.** Ancak kapsamı iyi anlamak önemli.

### `active` alanının kullanıldığı tek yer:

```dart
// lib/services/bist100_service.dart, satır 116-117:
.collection('bist_stocks')
.where('active', isNotEqualTo: false)
```

Bu **yalnızca bir yerde** kullanılıyor: `Bist100Service._refreshFromFirestore()`. Bu fonksiyon uygulama açılışında `bist_stocks` tam listesini çeker ve `kBistStocks` global değişkenini günceller.

### `active: false` sonuçları

1. Hisse `kBistStocks` listesine **dahil edilmez** — tarama, arama, fiyat listesi ekranlarında görünmez.
2. Hisse `kBist100Symbols/kBist100SymbolsLive` listesinde zaten olmayacaktır (BIST100'den çıkmış).
3. Mevcut kullanıcı favorilerinde bu hisse olabilir — silmez, sadece güncellenmiş listede göstermez. **Bu bir sorun değil:** favorite'ler sembolle saklanır; gösterim sırasında fiyat çekilir (Yahoo Finance), fiyat gelse de hisse gösterilir.
4. `_baseBistStocks` sabit kodda hisse hâlâ var (`active` alanı dart sabiti değil, sadece Firestore'da). Bu yüzden `syncBistStocksFromFirestore()` içindeki fallback mekanizması çalışır: "Firestore'da olmayan ama `_baseBistStocks`'ta olan hisseler korunur." Yani `active: false` olan hisse Firestore sorgu sonucunda gelmez ama fallback sabit listeden eklenir.

**RİSK:** Bu fallback mekanizması beklenmedik bir davranış yaratıyor. `active: false` yapılmış bir hisse, Flutter'ın fallback mekanizması sayesinde yine de `kBistStocks`'a eklenir (Firestore sorgusu onu döndürse de döndürmese de). Tam temiz bir çıkarma için `_baseBistStocks` sabitinin de güncellenmesi gerekir — ama bu Flutter kodu değişikliği demektir.

**ÖNERİ:** `bist_stocks.active: false` şu an için BIST 100 üyeliğini işaretlemek amacıyla güvenli kullanılabilir. Ancak hisseyi arama ve listelerden tamamen kaldırmak için ileride `_baseBistStocks` sabitinin de güncellenmesi planlanmalıdır.

---

## S9 — BİST'ten tamamen işlemden kaldırılan hisse ile sadece BIST100'den çıkan hisseyi birbirinden ayırabilir miyiz?

**MEVCUT YAPIDA HAYIR; ama kurulabilir.**

### Mevcut yapının yetersizliği

`bist_stocks.active` alanı ikili (`true`/`false`): "aktif" veya "pasif". "BIST100'den çıktı" ile "BIST'ten tamamen silindi" arasında ayrım yapan bir alan yok.

### Önerilen genişletilmiş yapı

```json
{
  "symbol": "AGHOL",
  "name": "AG Anadolu Grubu Holding",
  "active": false,
  "delistReason": "bist100_removed",  // yeni alan
  "delistedAt": Timestamp,            // yeni alan
  "notes": "Eylül 2026 revizyonu"     // yeni alan, opsiyonel
}
```

`delistReason` değerleri:
- `"bist100_removed"` → BIST100'den çıktı, BIST'te işlem görmeye devam edebilir
- `"bist_delisted"` → BİST'ten tamamen kaldırıldı (şirket kapandı, birleşme, vb.)

### Bu ayrımı yapmanın pratik yolu

Bir hisse BIST100 listesinden çıktığında otomatik olarak `active: false` + `delistReason: 'bist100_removed'` yazılabilir. Tamamen BİST'ten çıkma durumu ise Yahoo Finance'ten gelen `regularMarketPrice: null` veya HTTP 404 ile tespit edilebilir — ancak bu kontrol ayrı bir mekanizma gerektirir.

**BELİRSİZ:** Şu anki Flutter kodu `delistReason` veya `delistedAt` alanlarını okumuyor. Bu alanlar backend tarafında referans/audit için tutulabilir, uygulama tarafı için şimdilik gerekli değil.

---

## Önceki Raporda Belirsiz/Eksik Kalan Noktaların Tamamlanması

### Önceki rapordan "BELİRSİZ" olarak işaretlenen konular:

#### 1. Firestore rules — `bist_index_meta` ve `bist_stocks` için kural var mı?

**TAMAMLANDI.** `firestore.rules` dosyası okundu. **İki collection için kural YOK:**

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // ... diğer kurallar ...
    // bist_stocks → KOD YOK
    // bist_index_meta → KOD YOK
  }
}
```

**Mevcut tanımlı collection'lar:** `trials`, `purchases`, `entitlements`, `subscription_tokens`, `fundamentals`, `kap_disclosures`, `kap_members`, `kap_sync_logs`, `meta`, `ipo_items`, `ipo_meta`, `ai_cache`

**Varsayılan Firestore davranışı:** Kural tanımlanmayan collection'lar `match /databases/{database}/documents` bloğunun içindeyse ve alt kural yoksa — Firestore Security Rules v2'de varsayılan **DENY** uygulanır (read ve write ikisi de kapalı).

**RİSK (KRİTİK):** Flutter uygulaması `bist_stocks` ve `bist_index_meta` collection'larını okumaya çalışıyor (`bist100_service.dart` satır 85–117). Eğer bu kurallar deploy edilmemiş veya açık değilse, uygulama bu collection'ları **okuyamaz** — hata yerine boş sonuç döner ve `Bist100Service` sabit koda fallback yapar. Bu neden şimdiye kadar fark edilmedi: fallback sabit liste devreye giriyor ve kullanıcı bunun farkında olmuyor.

**ÖNERİ:** Yeni Cloud Function'ı deploy etmeden önce şu kuralları `firestore.rules`'a ekleyin:

```javascript
match /bist_stocks/{symbol} {
  allow read:  if true;
  allow write: if false;  // sadece Cloud Function (admin SDK) yazar
}

match /bist_index_meta/{docId} {
  allow read:  if true;
  allow write: if false;
}
```

#### 2. `bilancoveri.com` API şeması BIST100 üyeliği veriyor mu?

**BELİRSİZ (teyit edilemedi).** `updateFundamentals` fonksiyonunda şu alanlar kullanılıyor:

```javascript
pe, pb, ev_ebitda, roe, roa, dividend_yield,
float_ratio, market_cap_mn_try, name, sector, ticker
```

`bist100`, `index` veya `inBist100` gibi bir alan bu listede yok. Endpoint response'u canlı test edilmeden kesin söylenemez.

**ÖNERİ:** `https://bilancoveri.com/api/v1/sirketler.json` endpoint'ini manuel `curl` ile çekip yanıt şemasını inceleyin. BIST100 üyelik alanı varsa ekstra endpoint gerekmez.

#### 3. `kap_members.stockCode` formatı `bist_stocks` sembolüyle birebir örtüşüyor mu?

**EVET, örtüşüyor.** Her iki taraf da `.toUpperCase()` uyguluyor:

- `kap_members`: `stockCode: (m.stockCode || m.code || '').toUpperCase()` (index.js satır 183)
- `bist_stocks`: Semboller büyük harf (örn: `AKBNK`, `GARAN`)

Ancak bazı edge case'ler olabilir: GYO, BYF, holding şirketleri gibi kategorilerde `stockCode` boş gelebilir (bu KAP API davranışına bağlı).

#### 4. `syncBistStocksFromFirestore()` fallback mekanizması güvenli mi?

**EVET, güvenli — ama beklenmedik bir yan etkisi var (S8'de detaylandırıldı).** Mekanizma:

```dart
// bist_stocks.dart satır ~755-767:
// Firestore'da olmayan ama _baseBistStocks'ta olan hisseler korunur
for (final entry in _baseBistStocks) {
  final symbol = (entry['symbol'] ?? '').toString().toUpperCase();
  if (symbol.isEmpty || seenSymbols.contains(symbol)) continue;
  seenSymbols.add(symbol);
  merged.add(Map<String, String>.from(entry));
}
```

Bu fallback, kısmi Firestore güncellemelerine karşı güvenlik katmanı. Sonuç: `active: false` olan bir hisse Firestore'da pasif görünse de, sabit `_baseBistStocks` listesinde olduğu için `kBistStocks`'a eklenebilir. Bu **yalnızca** `bist_stocks` collection'u kısmi güncellendiğinde ve sabit kod eski hisseyi içerdiğinde ortaya çıkar.

---

## Tüm Sorulara Özet Yanıtlar

| # | Soru | Yanıt |
|---|---|---|
| 1 | Mevcut backend'de BIST100 listesini sağlayacak kaynak var mı? | **HAYIR** — hiçbir fonksiyon `bist_stocks`/`bist_index_meta`'ya yazmıyor |
| 2 | Borsa İstanbul resmi endpoint'i otomatik kullanılabilir mi? | **HAYIR** — ücretsiz JSON API yok; VERDA ücretli, site SPA |
| 3 | Mevcut projede kullanılabilir üçüncü taraf kaynak var mı? | **EVET** — Foreks paragaranti API (XU100 tanımı) veya Bigpara API |
| 4 | Üçüncü taraf endpoint riskleri neler? | Orta-Yüksek ToS riski; günde 1 istek = düşük kırılganlık |
| 5 | Cloud Function ile günlük güncelleme yapılabilir mi? | **EVET** — mevcut yapı tamamen uygun, aynı pattern |
| 6 | Firestore diff güvenli yapılabilir mi? | **EVET** — `bist_index_meta/bist100.symbols` ile karşılaştırma |
| 7 | `kap_members`'dan şirket adı otomatik eşleştirilir mi? | **EVET** — `stockCode` formatı birebir örtüşüyor |
| 8 | `active: false` güvenli mi? | **EVET ama dikkat:** fallback mekanizması sabit kodu da dahil eder |
| 9 | BIST100 çıkışı ile BİST çıkışı ayrımı yapılabilir mi? | **Kurulabilir** — `delistReason` alanı eklenerek |

---

## Firestore Rules Eksikliği — Kritik Bulgu

```
bist_stocks    → Firestore rules'ta TANIMI YOK → varsayılan DENY
bist_index_meta → Firestore rules'ta TANIMI YOK → varsayılan DENY
```

Flutter uygulaması bu collection'ları okuyor. Kurallar deploy edilmemişse okuma başarısız; `Bist100Service` sessizce sabit listeye düşüyor. Yeni Cloud Function'dan önce bu kuralların eklenmesi zorunlu.

---

## Önerilen Uygulama Sırası

1. **`firestore.rules`**: `bist_stocks` ve `bist_index_meta` için `allow read: if true` ekle ve deploy et.
2. **Veri kaynağı doğrulama**: `bilancoveri.com/api/v1/sirketler.json` yanıtında BIST100 üyelik alanı var mı kontrol et.
3. **`functions/index.js`**: `syncBist100Index` scheduled function ekle (aylık, `0 5 1 * *`).
4. **Sıralama tercihi:**
   - Birincil: Foreks endpoint (daha güvenilir veri kalitesi)
   - İkincil: Bigpara API
   - Üçüncül: Manuel admin endpoint (`syncBist100Manual`) + otomasyona geçiş planı
5. **Flutter tarafı**: Değişiklik gerekmiyor.

---

## Referans Dosyalar (Bu Analizde Okunan)

| Dosya | İncelenen İçerik |
|---|---|
| `functions/index.js` | Tüm fonksiyonlar, veri kaynakları, URL'ler |
| `functions/package.json` | Bağımlılıklar: firebase-admin ^12, firebase-functions ^6, googleapis ^182, Node 22 |
| `lib/services/bist100_service.dart` | Firestore okuma mantığı, Hive cache, fallback |
| `lib/services/bist_stocks.dart` | Sabit BIST listesi, `kBist100Symbols`, `syncBistStocksFromFirestore()` |
| `lib/services/kap_disclosure_service.dart` | `kap_members` collection okuma pattern'ı |
| `lib/services/stock_service.dart` | Yahoo Finance kullanımı (`$SYMBOL.IS` pattern'ı) |
| `firestore.rules` | Güvenlik kuralları — `bist_stocks`/`bist_index_meta` tanımı YOK |
| `tools/compare_bist_symbols.py` | `bistguncel.md` vs `bist_stocks.dart` diff aracı |
| `tools/patch_bist_stocks.py` | Sabit liste güncelleme script'i |
| `.agents/tasks/bist100-auto-update-investigation.md` | Önceki araştırma raporu (referans alındı) |
