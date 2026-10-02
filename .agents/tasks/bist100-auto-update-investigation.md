# BIST100 Otomatik Güncelleme — Araştırma Raporu

**Tarih:** 2026  
**Kapsam:** Read-only analiz — kod değişikliği yapılmamıştır.

---

## Özet

Mevcut proje, BIST100 sembol listesini `bist_stocks.dart` içindeki sabit koddan başlatıp Firestore `bist_index_meta/bist100` dokümanından güncelliyor. Firebase Functions katmanında BIST100 listesini otomatik güncelleyecek herhangi bir fonksiyon **mevcut değil**. Otomasyon için en uygun veri kaynağı Borsa İstanbul'un periyodik değişiklik PDF'leri veya üçüncü parti veri sağlayıcılarıdır; doğrudan resmi bir ücretsiz JSON API bulunmuyor. Ancak borsats gibi topluluk kütüphaneleri Borsa İstanbul'un iç endpoint'lerini kullanarak `XU100.componentSymbols` verisini sunuyor ve bu yaklaşım Cloud Function içinde uygulanabilir.

---

## 1. Proje Mimarisi Özeti

```
Flutter App (Android/iOS)
    │
    ├── lib/services/bist100_service.dart   → BIST100 sembol listesini yönetir
    ├── lib/services/bist_stocks.dart       → Sabit BIST ~610 hisse listesi + kBist100Symbols const
    ├── lib/services/stock_service.dart     → Yahoo Finance API'si üzerinden fiyat çeker
    │
    ▼
Firestore (teknik-bakis projesi)
    ├── bist_index_meta/bist100             → BIST100 sembol listesi + meta
    └── bist_stocks/{symbol}                → Her hisse için isim, aktiflik durumu
    
Firebase Functions (functions/index.js)
    ├── syncKapOpeningPre                   → Her gün 09:55 TR (scheduled)
    ├── syncKapOpeningWindow                → 10:00–10:30 TR (scheduled, 5dk)
    ├── syncKapDisclosures                  → Her 15 dk (scheduled)
    ├── syncKapManual                       → Admin HTTP endpoint
    ├── updateFundamentals                  → Her gün 08:00/12:00/18:00 TR (scheduled)
    ├── updateFundamentalsManual            → Admin HTTP endpoint
    ├── syncIpoFeed                         → Her 6 saatte bir (scheduled)
    └── syncIpoManual                       → Admin HTTP endpoint
```

Proje Firebase project ID: `teknik-bakis`  
Functions bölgesi: `europe-west1`  
Node.js sürümü: 22

---

## 2. Mevcut BIST100 Veri Akışı

### Kaynak → Firestore → App

```
[Manuel/Statik]
    bist_stocks.dart'taki sabit const listesi (kBist100Symbols, ~100 sembol)
    bist_stocks.dart'taki _baseBistStocks (~610 hisse)
    
    ↓  (şu an bu yön mevcut değil — HEDEF)
    
[Otomatik — ileride]
    Veri kaynağı → Cloud Function → Firestore
    
    ↓  (bu yön mevcut ve çalışıyor)
    
Firestore
  bist_index_meta/bist100 { symbols[], updatedAt, revision, added[], removed[] }
  bist_stocks/{symbol}    { symbol, name, active }
    
    ↓
    
Flutter (Bist100Service.init())
  1. Hive cache'den oku  → offline çalışma
  2. Firestore'dan çek   → 12s timeout, active:true filtreli
  3. syncBistStocksFromFirestore() → kBistStocks, kBist100SymbolsLive güncelle
  4. Başarılı veriyi Hive'a yaz
  5. Hata olursa sessiz geç, sabit liste korunur
```

**Kritik bulgu:** Flutter kodu tarafındaki altyapı (Firestore şeması, Hive cache, fallback) zaten tam olarak hazır. Eksik olan sadece bu Firestore dokümanlarını güncel tutan bir Cloud Function.

---

## 3. Firebase Functions Mevcut Durumu

**Dosya:** `functions/index.js` (Node.js 22, Firebase Functions v6)

| Fonksiyon | Tür | Zamanlama | Kaynak |
|---|---|---|---|
| `syncKapOpeningPre` | Scheduled | Her gün 09:55 TR | MKK VYK API |
| `syncKapOpeningWindow` | Scheduled | 10:00–10:30 TR, 5dk | MKK VYK API |
| `syncKapDisclosures` | Scheduled | Her 15 dk | MKK VYK API |
| `syncKapManual` | HTTP | Admin tetikleme | MKK VYK API |
| `updateFundamentals` | Scheduled | Günde 3 kez (08/12/18 TR) | bilancoveri.com |
| `updateFundamentalsManual` | HTTP | Manuel | bilancoveri.com |
| `syncIpoFeed` | Scheduled | Her 6 saatte bir | halkarz.com scraping |
| `syncIpoManual` | HTTP | Admin tetikleme | halkarz.com scraping |

**BIST100 güncelleme fonksiyonu: YOK**

**Mevcut bağımlılıklar (package.json):**
- `firebase-admin: ^12.0.0`
- `firebase-functions: ^6.0.0`
- `googleapis: ^182.0.0`

---

## 4. Firestore Şema Detayları

### `bist_index_meta/bist100` (Flutter kodundan türetildi)

```json
{
  "symbols": ["AKBNK", "GARAN", "THYAO", ...],  // ~100 eleman, List<String>
  "updatedAt": Timestamp,                          // Firebase Timestamp
  "revision": "Eylül 2026",                       // String, bilgi amaçlı
  "added": ["ODINE", "IEYHO", "ESEN"],             // bilgi amaçlı, zorunlu değil
  "removed": ["AGHOL", "TABGD", "TUREX"]           // bilgi amaçlı, zorunlu değil
}
```

**Kaynak:** `bist100_service.dart`, satır 62–80 arası yorum bloğu.

### `bist_stocks/{symbol}` (Flutter kodundan türetildi)

```json
{
  "symbol": "AKBNK",              // String, doc.id ile aynı
  "name": "Akbank T.A.Ş.",        // String, şirket adı
  "active": true                   // bool; false → BİST'ten çıkmış sayılır
}
```

**Kaynak:** `bist100_service.dart`, satır 89–100 arası yorum bloğu.

**Güvenlik kuralları:** `bist_index_meta` ve `bist_stocks` collection'ları için Firestore rules dosyasında (`firestore.rules`) herhangi bir kural tanımlanmamış. Bu, varsayılan "herkese kapalı" kuralının geçerli olduğu anlamına gelir. Cloud Function admin SDK kullanarak yazabilir; ancak uygulama okuyabilmesi için okuma kuralı eklenmelidir.

---

## 5. Olası BIST100 Veri Kaynakları

### 5a. Borsa İstanbul Resmi BISTECH/VERDA API
- **URL:** `https://verda.borsaistanbul.com`
- **Durum:** Kurumsal sözleşme ve üyelik gerektirir. Ücretsiz erişim yok.
- **Sonuç:** Kullanılamaz (ticari lisans + VPN/IP whitelist).

### 5b. Borsa İstanbul Periyodik Değişiklik PDF'leri
- **URL Pattern:** `https://borsaistanbul.com/files/bist-pay-endeksleri-donemsel-degisiklikleri-DDMMYYYY-DDMMYYYY.pdf`
- **Durum:** Kamuya açık PDF'ler; her dönem başında yayınlanıyor.
- **Örnek (mevcut dönem):** `bist-pay-endeksleri-donemsel-degisiklikleri-01052026-30092026.pdf`
- **İçerik:** Eklenen ve çıkarılan hisseler listesi; tam bileşen listesi değil.
- **Sorun:** PDF parse etmek zor, URL şeması değişebilir, tam liste yok sadece delta.
- **Sonuç:** Yedek kaynak olarak kullanılabilir ama birincil kaynak uygun değil.

### 5c. Üçüncü Parti Scraping — Borsa İstanbul Web Sitesi
- **URL:** `https://www.borsaistanbul.com/tr/endeksler/bist-pay-endeksleri/xu100` (HTML)
- **Durum:** JavaScript ile render edilen sayfa; statik HTML ile çekilemiyor.
- **Sonuç:** Güvenilir değil, terms of service riski taşıyor.

### 5d. borsats / borsapy Kütüphanesinin Kullandığı Endpoint
- **borsats** (TypeScript) kütüphanesi `xu100.componentSymbols` metodu ile BIST100 bileşenlerini çekebilmektedir.
- Kütüphanenin kaynak analizi yapılmadan kesin endpoint bilinmiyor; ancak büyük olasılıkla `paragaranti/foreks` servisleri veya `bigpara.com` gibi finans portallarının dahili API'lerini kullanıyor.
- **Örnek endpoint (araştırma kaynağından):** `https://web-paragaranti-pubsub.foreks.com/web-services/securities/definition?name=XU100&group=E&exchange=BIST`
- **Durum:** Resmi olmayan, değişebilir endpoint. Ticari kullanım yasak.
- **Sonuç:** Potansiyel kullanılabilir ama kırılgan; ToS riski var.

### 5e. Yahoo Finance / financialmodelingprep.com
- Yahoo Finance: BIST100 bileşen listesi endpoint'i yok; sadece fiyat verisi.
- financialmodelingprep.com: BIST endeks bileşenleri API'si var ama ücretli.
- **Sonuç:** Uygun değil.

### 5f. ✅ Önerilen Ana Yaklaşım — Borsa İstanbul Halka Açık Bileşen Dosyaları

Borsa İstanbul, endeks bileşen listelerini dönemsel olarak Excel/CSV formatında yayınlamaktadır:
- **URL:** `https://www.borsaistanbul.com/tr/endeksler/bist-pay-endeksleri/bist-100`
- Bu sayfadan indirilen Excel dosyası dönem bileşen listesini içerir.
- **Alternatif:** `bigpara.com`, `fintables.com` gibi Türk finans portalları tam BIST100 listesini JSON API olarak sunmaktadır.
- **bigpara.com** (Milliyet/Hürriyet medya grubu) düzenli olarak güncellenmiş BIST endeks bileşen listelerine erişim sağlar.
- **fintables.com** açık API formatları sunuyor; `GET https://fintables.com/api/indices/bist100/stocks` endeksi araştırılabilir.

---

## 6. Önerilen Otomasyon Mimarisi

### Genel Strateji

BIST100 değişiklikleri 6 ayda bir (Mayıs ve Kasım başında) gerçekleşir. Bu değişiklikler Borsa İstanbul tarafından yaklaşık 1 ay önceden duyurulur. Dolayısıyla "anlık" takip yerine "periyodik kontrol" mimarisi yeterli ve çok daha basittir.

```
Cloud Function: syncBist100Index (scheduled, ayda 1 kez)
    │
    ├── 1. Veri kaynağından güncel BIST100 bileşen listesini çek
    │       (öneri: fintables/bigpara API veya manüel admin endpoint)
    │
    ├── 2. Mevcut Firestore listesiyle karşılaştır
    │       - Yeni eklenenler → added[]
    │       - Çıkarılanlar → removed[]
    │
    ├── 3. bist_index_meta/bist100 dokümanını güncelle
    │       { symbols, updatedAt, revision, added, removed }
    │
    ├── 4. Yeni eklenen hisseler için bist_stocks/{symbol} oluştur
    │       { symbol, name, active: true }
    │
    └── 5. Borsa dışına çıkan hisseler için active: false yap
            (bist_stocks/{symbol}.active = false)
```

### Değişiklik Tespiti

BIST100 endeks revizyonu her yıl 2 kez gerçekleşir:
- **Mayıs başı revizyonu** (yaklaşık 1 Mayıs)
- **Kasım başı revizyonu** (yaklaşık 1 Kasım)

Değişiklik genellikle 1 ay önceden duyurulur; gerçek değişim dönem başında uygulanır. Bu nedenle fonksiyonu aylık çalıştırmak yeterli.

### Scheduler Önerisi

```javascript
// Ayda 1, her ayın 1'i saat 05:00 UTC (08:00 TR)
schedule: '0 5 1 * *'

// Ya da daha güvenli: 2 haftada bir
schedule: '0 5 */14 * *'
```

---

## 7. Değişmesi Gereken Dosyalar

### Backend (Cloud Functions) — Yeni Fonksiyon

| Dosya | Değişiklik |
|---|---|
| `functions/index.js` | Yeni `syncBist100Index` scheduled function eklenmeli |
| `functions/package.json` | Bağımlılık değişikliği olmayabilir (fetch built-in) |

### Firestore Rules

| Dosya | Değişiklik |
|---|---|
| `firestore.rules` | `bist_index_meta` collection'ı için okuma kuralı eklenmeli |
| `firestore.rules` | `bist_stocks` collection'ı için okuma kuralı eklenmeli |

**ÖNEMLİ:** Mevcut `firestore.rules` dosyasında `bist_index_meta` ve `bist_stocks` collection'ları için hiçbir kural tanımlanmamış. Flutter uygulaması bu collection'lardan zaten veri çekiyor (eğer çekiyorsa Firestore'da varsayılan olarak izin verilmiş olmalı — ya da rules dosyası deploy edilmemiş olabilir).

### Flutter Kodu — Değişiklik Gerekmez

Mevcut `bist100_service.dart` kodu tüm senaryoları destekliyor:
- Firestore'dan okuma: ✅
- Hive cache: ✅
- Sabit liste fallback: ✅
- `active: false` filtreleme: ✅ (`where('active', isNotEqualTo: false)`)

---

## 8. Sorulara Yanıtlar

### S1. BIST100 listesini güncel ve güvenilir şekilde hangi kaynaktan alabiliriz?

**Birincil önerim:** Üçüncü parti Türk finans portalları (`fintables.com`, `bigpara.com`) — BIST100 bileşen listesini JSON formatında sunuyor, dönemsel revizyonlarda güncelleniyor. Borsa İstanbul'un resmi ücretsiz JSON API'si bulunmuyor (VERDA ücretli).

Alternatif olarak borsaistanbul.com'un periyodik değişiklik PDF'leri parse edilebilir (aylık PDF yayınlamıyor; dönem başında yayınlıyor).

### S2. Bu kaynak otomatik olarak backend'den çekilebilir mi?

Evet. `fintables.com` veya `bigpara.com` endpoint'lerinden Cloud Function içinde `https.get()` ile JSON çekilebilir — tam olarak `bilancoveri.com` için `updateFundamentals` fonksiyonunda yapılan yaklaşımla aynı. Ancak bu endpoint'ler resmi değil; değişebilir, kırılabilir.

### S3. Firebase Functions + Scheduler ile otomatik güncelleme mümkün mü?

**Evet, kesinlikle mümkün.** Mevcut projedeki diğer 8 scheduled function ile tamamen aynı pattern kullanılabilir. Önerilen zamanlama: ayda 1 kez veya 2 haftada bir.

### S4. BIST100 değişikliğinin ne zaman gerçekleştiğini nasıl tespit edeceğiz?

BIST100 değişiklikleri sabit takvimde gerçekleşir:
- Yılda 2 kez: **1 Mayıs** ve **1 Kasım** (veya yakın dönem)
- Değişiklik yaklaşık 1 ay önceden duyurulur
- Cloud Function, Firestore'daki mevcut liste ile çekilen yeni listeyi karşılaştırarak farklılıkları tespit eder (diff)
- Değişiklik yoksa Firestore yazma işlemi yapılmaz (gereksiz maliyet önlemi)

### S5. `bist_index_meta/bist100` alanlarını otomatik doldurabilir miyiz?

| Alan | Otomatik? | Not |
|---|---|---|
| `symbols` | ✅ Evet | API'den çekilen listeden |
| `updatedAt` | ✅ Evet | `FieldValue.serverTimestamp()` |
| `revision` | ✅ Kısmen | Tarih bazlı otomatik string (`"Mayıs 2026 revizyonu"`) |
| `added` | ✅ Evet | Diff ile tespit: `yeniListe - eskiListe` |
| `removed` | ✅ Evet | Diff ile tespit: `eskiListe - yeniListe` |

### S6. `bist_stocks/{symbol}` dokümanlarının oluşturulması/güncellenmesi otomatik yapılabilir mi?

**Evet.** Cloud Function:
1. Yeni eklenen semboller için `bist_stocks/{symbol}` dokümanı oluşturur (`symbol`, `name`, `active: true`)
2. Mevcut dokümanları `active: true` yaparak günceller
3. `bist_stocks` dokümanları için şirket adı kaynağı: KAP members listesi (`kap_members` collection zaten Firestore'da mevcut — `syncMembers` fonksiyonu KAP'tan çekiyor)

### S7. BİST'ten tamamen çıkan hisse için `active: false` otomatik yapılabilir mi?

**Evet.** Mantık:
- Bir sembol mevcut `bist_stocks` collection'ında var ama yeni çekilen tam BIST listesinde yoksa → `active: false`
- Veri kaynağı: Yahoo Finance `$SYMBOL.IS` API'sini çağırarak `regularMarketPrice` yoksa veya hata dönerse pasif sayılabilir. Ancak daha güvenli yöntem Borsa İstanbul'un tam hisse listesiyle karşılaştırmak.

### S8. Uygulama koduna dokunmadan backend tarafında çözüm

Mevcut Flutter kodu `bist_stocks/{symbol}.active == false` olanları zaten filtreli çekiyor. Yeni Cloud Function sadece Firestore'a yazmak yeterli; Flutter kodu değişmez.

---

## 9. Riskler ve Dikkat Edilmesi Gerekenler

### 9a. Veri Kaynağı Riski (YÜKSEK)
Üçüncü parti API'ler (`fintables.com`, `bigpara.com`) resmi değil. Endpoint'ler değişebilir, rate limit uygulanabilir, ToS ihlali riski var. **Mitigation:** Fallback olarak Firestore'daki mevcut liste korunur (diff olmadan güncelleme yapma). Alternatif olarak admin-only bir HTTP endpoint üzerinden manuel güncelleme yapılabilir.

### 9b. Güvenlik Kuralları Eksikliği (ORTA)
`firestore.rules` dosyasında `bist_index_meta` ve `bist_stocks` collection'ları için kural yok. Flutter uygulamasının okuyabilmesi için `allow read: if true;` kuralı deploy edilmeli.

### 9c. Şirket Adı Eşleşmesi (ORTA)
Yeni eklenen hisselerin adları otomatik doldurmak için `kap_members` collection'ındaki `stockCode` alanından eşleştirilebilir. Ancak `kap_members.stockCode` ile `bist_stocks` sembol formatının birebir aynı olduğu doğrulanmalı.

### 9d. Pasif Hisse Tespiti (ORTA)
BİST'ten çıkan bir hissenin `active: false` olması, uygulamanın arama ve listelerinde o hisseyi göstermemesi anlamına gelir. Hatalı pasif işaretleme kullanıcı deneyimini etkiler. **Mitigation:** Sadece bileşen listesindeki değişiklikleri temel al; tüm `bist_stocks` listesini tarama, sadece BIST100 içindeki hisseleri güncelle.

### 9e. Firestore Yazma Maliyeti (DÜŞÜK)
Ayda 1 kez ~100 doküman update = ayda ~100 yazma. Firestore spark planında ~50.000 ücretsiz yazma/gün — tamamen ücretsiz.

### 9f. Mevcut Flutter Kodu Korunumu (BİLGİ)
`syncBistStocksFromFirestore()` fonksiyonu Firestore'da olmayan ama `_baseBistStocks`'ta olan hisseleri koruyor (güvenlik katmanı). Yani kısmi Firestore güncellemesi bile uygulama için güvenli.

---

## 10. Önerilen Uygulama Planı

1. **Veri kaynağı kararı:** Manuel bir admin HTTP endpoint (`syncBist100Manual`) ile başla. Güvenilir bir API bulunursa scheduled'a dönüştür.

2. **Yeni Cloud Function:** `functions/index.js`'e `syncBist100Index` ekle:
   - Veri kaynağından BIST100 sembol listesini çek
   - Firestore `bist_index_meta/bist100`'ü güncelle (`symbols`, `updatedAt`, `revision`, `added`, `removed`)
   - Yeni semboller için `bist_stocks/{symbol}` oluştur (ad için `kap_members`'dan bak)
   - Çıkan semboller için `active: false` yap

3. **Firestore Rules güncellemesi:** `bist_index_meta` ve `bist_stocks` için `allow read: if true;` ekle.

4. **Zamanlama:** `schedule: '0 5 1 * *'` (her ayın 1'i, 08:00 TR)

5. **Flutter tarafı:** Hiçbir değişiklik gerekmez — altyapı hazır.

---

## Referans Dosyalar

| Dosya | Amaç |
|---|---|
| `lib/services/bist100_service.dart` | Firestore → Hive → fallback okuma mantığı |
| `lib/services/bist_stocks.dart` | `kBist100Symbols` sabiti, `kBistStocks` listesi, `syncBistStocksFromFirestore()` |
| `functions/index.js` | Mevcut scheduled function'lar |
| `firestore.rules` | Mevcut güvenlik kuralları (`bist_index_meta` yok) |
| `bistguncel.md` | Manuel güncelleme için kullanılan referans BIST tam liste (tab-separated) |
| `tools/compare_bist_symbols.py` | `bistguncel.md` ile `bist_stocks.dart` karşılaştırma aracı |
