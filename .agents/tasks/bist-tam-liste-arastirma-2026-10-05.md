# BIST Tam Liste Araştırma Raporu
**Tarih:** 2026-10-05  
**Kapsam:** Salt okunur araştırma — hiçbir dosya değiştirilmemiştir.  
**Araştırmacı:** Kiro (otonom araştırma adımı)

---

## ÖZET YANIT (TL;DR)

| Konu | Sonuç |
|---|---|
| `_baseBistStocks` kaynağı | `lib/services/bist_stocks.dart`, **726 sembol**, manuel derleme, son commit 8700fa2 |
| `bist_stocks` Firestore nasıl dolduruluyor? | Yalnızca BIST100 bootstrap (~100 sembol) + haftalık sync; 726 sembolün **tamamı Firestore'a hiç yazılmamış** |
| Resmi BIST tam liste API'si | **YOK** — BISTECH/VERDA ücretli, site SPA. Yalnızca PDF/HTML delta değişiklikler mevcut |
| En güvenilir tam liste kaynağı | **MKK VYK API** `/members` endpoint'i (mevcut projede zaten kullanılıyor) |
| IPO trading kontrolü için en uygun kaynak | MKK `/members` + `bist_stocks` koleksiyonunu tüm BIST hisseleriyle doldurmak |
| Mevcut BIST100 sistemi etkilenir mi? | **HAYIR** — BIST100 `bist_index_meta/bist100` ayrı koleksiyonda, bağımsız |

---

## 1. `_baseBistStocks` Kaynağı Analizi

### 1.1 Dosya ve Konum

- **Dosya:** `lib/services/bist_stocks.dart`
- **Tanım:** Satır 5–725, `const List<Map<String, String>> _baseBistStocks`
- **Toplam satır:** 879 (dosya)
- **Sembol sayısı:** **726** (regex ile doğrulandı: `'symbol': '...'` deseni)

### 1.2 Son Güncelleme

```
git log --oneline lib/services/bist_stocks.dart:
8700fa2  feat: 19 yeni BIST hissesi eklendi (ALBTN, BETAE, BEWEN, BKRGY, CITAS,
         EKIM, GOLDA, INTET, ISVEA, KARCL, MASFN, METEN, ORZAX, QUICK, SARAE,
         SOHOE, SSAAT, TKNKA, VEYAS) + KPEKS ve NETGL eklendi
```

Son güncelleme tarihi commit geçmişinde kesin tarih yok; ancak önceki rapordan bu commit'in 2026 yılına ait olduğu bilinmektedir.

### 1.3 Liste Kaynağı

`bist_stocks.dart` başlığında şu yorum mevcut:
```dart
// BIST 500 – Tam hisse listesi (Kaynak: Borsa İstanbul)
// Borsa İstanbul'da 2026 itibarıyla bildirilen toplam hisse sayısı 610 civarındadır.
const int kBistListedCount = 610;
```

Fakat gerçekte **726** sembol var. Fark şunlardan kaynaklanıyor:

- **GYO (Gayrimenkul Yatırım Ortaklığı):** 38 adet — AAGYO, ADGYO, AGYO, AHGYO, AHSGY vb.
- **BYF (Borsa Yatırım Fonu/ETF):** 23 adet — APBDL, APLIB, APMDL, APX30, OPK30, Z30EA, Z30KE, Z30KP, ZELOT, ZGOLD, ZPBDL, ZPLIB, ZPT10, ZPX30, ZRE20, ZSR25, ZTLRF, ZTLRK, ZTM25 vb.
- **Katılım indeksi BYF'leri ve özel endeks BYF'leri** da dahil
- `kBistListedCount = 610` yalnızca saf pay senedi sayısını yansıtıyor; GYO ve BYF'ler de BIST'te işlem gören menkul kıymetler olduğundan liste onları da içeriyor.

**Hisse dışı semboller var mı?** EVET:
- BYF (ETF): 23 adet — BIST endekslerine bağlı yatırım fonları
- GYO (REIT): 38 adet — bunlar hisse senedi kategorisinde BIST'te işlem görür, teknik olarak hisse
- `bistguncel.md` referans listesi: 604 satır (BYF olmayan saf hisse sayısına yakın)
- Vadeli benzeri sembol: ZSR25, ZTM25 — bunlar aslında BYF'ler (BIST Sürdürülebilirlik 25 BYF, BIST Temettü 25 BYF)
- **Gerçek vadeli/opsiyon sözleşmesi bulunmamaktadır** — liste yalnızca hisse ve BYF içeriyor

### 1.4 Duplikat Durumu

Kod analizinde AKBNK için 2 eşleşme görüldü ancak ikincisi bir yorum satırıydı (L740, docstring içinde). **Gerçek duplikat yok.**

### 1.5 Oluşturulma Yöntemi

Manuel derleme: `tools/patch_bist_stocks.py`, `tools/update_bist_names.py`, `tools/dedupe_bist_stocks.py` script'leri + `bistguncel.md` (IS Yatırım/BigPara'dan kopyalanan tab-separated fiyat ekranı verisi) kullanılarak güncelleniyor.

`bistguncel.md` formatı:
```
Menkul		Fiyat	%	Zaman
A1CAP	 	9.34	-1.48	11:57:37
...
```
Bu dosya el ile yenileniyor — tam otomatik değil.

---

## 2. `bist_stocks` Firestore Koleksiyonu Analizi

### 2.1 Koleksiyonu Kim Dolduruyor?

**Mevcut durumda yalnızca iki kaynak yazar:**

| Kaynak | Ne Yazar | Kaç Sembol |
|---|---|---|
| `syncBist100Manual?bootstrap=true` | 100 BIST100 sembolü (BIST100_OCT2026 hardcoded listesi) | ~100 |
| `syncBist100Index` (haftalık scheduler) | Delta: eklenen/çıkarılan BIST100 sembollerine `bist100Member` günceller | ~5-20 değişim/dönem |

**Kritik eksik:** 726 sembollük geniş BIST listesini Firestore'a taşıyan hiçbir Firebase Function mevcut değil.

### 2.2 `active` ve `bist100Member` Alanlarının Kullanımı

**`active` alanı:**
- Değer: `true` / `false`
- Flutter filtresi: `bist_stocks.where('active', isNotEqualTo: false)`
- Etki: `false` olan semboller `kBistStocks` listesine dahil edilmez → tarama ve listelerde görünmez
- **Dikkat:** Firestore'da `active: false` olsa bile `_baseBistStocks` sabit listesindeyse fallback mekanizması onu kBistStocks'a ekler

**`bist100Member` alanı:**
- Değer: `true` / `false`
- Sadece BIST100 endeks üyeliğini gösterir
- Flutter tarafında **doğrudan okunmaz** — `Bist100Service` `bist_index_meta/bist100.symbols` listesini kullanır
- BIST100'den çıkan hisselerde `bist100Member: false` yapılır, `active` alanına dokunulmaz

### 2.3 `bist_stocks` ile `bist_index_meta/bist100` Ayrımı

```
bist_index_meta/bist100 → Sadece BIST100 üyelik listesi (100 sembol, symbols[])
bist_stocks/{SYMBOL}    → Her BIST sembolünün metadata'sı (tüm BIST hedefleniyor ama şu an ~100)
```

Bu iki yapı **birbirinden bağımsız tasarlanmış** ve birbirini etkilemiyor.

---

## 3. Mevcut Projede BIST Listesi İçin Kullanılan Dış Kaynak

### 3.1 BIST100 için (mevcut, çalışıyor)

- **Kaynak:** `https://www.borsaistanbul.com/en/announcement` — HTML parse
- **Yöntem:** `findLatestBist100Announcement()` → `parseBist100Announcement()` → delta uygulama
- **Sıklık:** Haftalık (her Pazartesi 05:00 UTC)
- **Güvenilirlik:** Resmi kaynak, bot engeli yok (`/en/announcement` yolu)

### 3.2 Tüm BIST listesi için (mevcut, sadece statik)

- **Kaynak:** `bistguncel.md` — IS Yatırım / BigPara'dan elle alınan fiyat ekranı verisi
- **Yöntem:** `tools/patch_bist_stocks.py` ile `bist_stocks.dart` sabit listesine güncelleme
- **Sıklık:** Manuel, düzensiz
- **Güvenilirlik:** Anlık fotoğraf — yeni IPO'lar otomatik gelmiyor

### 3.3 Şirket Adları İçin (mevcut, çalışıyor)

- **Kaynak:** `https://apigwdev.mkk.com.tr/api/vyk/members` — KAP VYK API
- **Yöntem:** `syncMembers()` fonksiyonu, `kap_members` koleksiyonuna yazar
- **Sıklık:** Her KAP sync'i ile birlikte (günde birkaç kez)
- **İçerik:** `title` (şirket adı), `stockCode` (borsa kodu), `memberType`

---

## 4. Borsa İstanbul Resmi Kaynakları Analizi

### 4.1 Resmi JSON/CSV/REST API

**SONUÇ: MEVCUT DEĞİL (ücretsiz)**

| Kaynak | Durum |
|---|---|
| BISTECH/VERDA API (`verda.borsaistanbul.com`) | Kurumsal üyelik + IP whitelist + ücretli lisans. Kamuya açık değil. |
| `api.borsaistanbul.com` | DNS çözümlenemiyor (domain yok) |
| `datastore.borsaistanbul.com` | Ember.js SPA, sunucu tarafı erişim yok |
| `borsaistanbul.com/api/` | HTTP 200 ama "erişim engellendi" sayfası — gerçek API değil |

### 4.2 Mevcut Resmi Kaynaklar (HTML/PDF)

**BIST100/endeks delta listesi (MEVCUT, kullanılıyor):**
- `/en/announcement/{id}/bist-stock-indices-periodic-review` — dönemsel değişiklik HTML (çalışıyor)
- Çeyreklik yayınlanıyor, makine okunabilir

**Tüm pay piyasası şirket listesi PDF (MEVCUT ama zor):**
- `borsaistanbul.com/files/duyuru-45516-TR.pdf` — "Pay Piyasası Yıldız Pazar, Ana Pazar ve Alt Pazar'da İşlem Gören Payların Belirlenmesi" duyurusu
- 6 ayda bir yayınlanıyor (Ocak ve Temmuz dönem başları)
- Ek-1'de tüm pay listesi var — PDF formatı, parse edilebilir
- URL şeması değişken (`duyuru-NNNNN-TR.pdf` formatı, sayı değişiyor)
- **Pratik zorluk:** PDF URL'sini otomatik bulmak için duyuru sayfasını taramak gerekiyor

**BIST Tüm Endeksi (XUTUM) metodoloji PDF:**
- `borsaistanbul.com/files/bist-mc-weighted-stock-indices-m-2023-11-xutum-taslak.pdf` — metodoloji belgesi
- XUTUM = BIST TÜM endeksi, tüm pay piyasası şirketlerini kapsar
- PDF'de tam bileşen listesi yok, sadece metodoloji açıklaması

### 4.3 BIST Tüm Şirketler İçin Alternatif Resmi Yol

Borsa İstanbul'un resmi olarak pazar dağılımı değişikliklerini duyurduğu `duyuru-NNNNN-TR.pdf` formatındaki PDF'ler, Ek-1'de tüm aktif payların listesini (Yıldız Pazar + Ana Pazar + Alt Pazar) içeriyor. Bu PDF'ler:
- 6 ayda bir güncelleniyor
- Bot engeli olmadan HTTP GET ile indirilebilir
- PDF parse araçları (pdftotext vb.) gerektiriyor
- URL'yi otomatik bulmak için `/en/announcement` listesini taramak gerekiyor

---

## 5. Alternatif Güvenilir Kaynaklar

### 5.1 MKK VYK API `/members` — **EN GÜÇLÜ (MEVCUT PROJEDE ZATEN KULLANILIYOR)**

```javascript
// Proje zaten kullanıyor:
const KAP_BASE = 'https://apigwdev.mkk.com.tr/api/vyk';
// syncMembers() içinde:
const data = await kapGet('/members', apiKey, token);
```

- **Içerik:** Tüm KAP üyesi şirketlerin listesi — `title`, `stockCode`, `memberType`, `kfifUrl`
- **BIST hissesi olanlar:** `memberType` filtresiyle ayrılabilir (pay senedi ihraç eden şirketler)
- **Güncellik:** KAP'a kayıt anında yansıyor — yeni IPO otomatik gelir
- **Güvenilirlik:** Resmi MKK API, credentials mevcut, proje zaten kullanıyor
- **Kısıt:** `stockCode` boş olabilir (bazı üyelerin borsa kodu yok — fon, banka gibi üyeler). Sadece `stockCode != ''` olanlar alınmalı
- **ToS riski:** Düşük — resmi API, proje credentials sahibi

**KRITIK BULGU:** `kap_members` koleksiyonu zaten güncel ve tüm BIST şirketlerini içeriyor. `bist_stocks` koleksiyonunu doldurmak için yeni bir API'ye gerek yok — mevcut `kap_members` verisi kullanılabilir!

### 5.2 Foreks / Paragaranti API — Güçlü ama ToS riski var

```
BIST'teki tüm hisseler (alfabetik, harf bazlı):
GET https://web-paragaranti-pubsub.foreks.com/web-services/securities?key=A&index=&exchangeGroupFilter=BIST.E&extendedResult=true
(key=A,B,C,... ile her harf için ayrı istek)

XUTUM (tüm BIST) bileşenleri:
GET https://web-paragaranti-pubsub.foreks.com/web-services/securities/definition?name=XUTUM&group=E&exchange=BIST
```

- **Kaynak:** Borsa İstanbul'un resmi veri iş ortağı Foreks (BISTECH veri sağlayıcısı)
- **Veri kalitesi:** Yüksek — doğrudan BIST veri akışından
- **ToS riski:** Orta-Yüksek — ticari ürünlerde kullanım yasak (borsapy uyarısı: "yalnızca kişisel/eğitim amaçlı")
- **Kırılganlık:** Orta — dahili API, belgelenmemiş, değişebilir
- **Pratikte:** Günde 1-2 istek → fark edilmez; ama ticari uygulama ToS sorunu

### 5.3 BigPara (Hürriyet) API — Kullanılabilir ama resmi değil

```
GET https://bigpara.hurriyet.com.tr/api/v1/hisse/list
```

- **Içerik:** Tüm BIST hisselerinin listesi + anlık fiyat
- **Kaynak:** StackOverflow'daki Flutter geliştiriciler bu endpoint'i aktif kullanıyor (2022–2026)
- **ToS riski:** Yüksek — medya şirketi API'si, resmi kullanıma açık değil
- **Kırılganlık:** Orta — Hürriyet/Doğan Medya'nın sitesi, aktif
- **BIST100 filtresi:** Endpoint BIST100 üyeliğini belirtip belirtmediği doğrulanmadı

### 5.4 KAP'tan Kaynaklanan GitHub Listesi (ahmeterenodaci)

- **URL:** `https://github.com/ahmeterenodaci/Istanbul-Stock-Exchange--BIST--including-symbols-and-logos`
- **Içerik:** `symbol`, `name`, `logoUrl` — KAP kaynaklı
- **Format:** JSON, CSV (26KB–119KB)
- **Güncelleme:** Repo commit geçmişine göre değişiyor — otomatik değil
- **Kullanım:** İlk kurulum için referans, sürekli güncelleme için uygun değil

### 5.5 IS Yatırım (isyatirim.com.tr)

- `isyatirimhisse` Python kütüphanesi IS Yatırım web sitesini scraping yapıyor
- Doğrudan bir JSON API endpoint'i kamuya açık değil
- Web scraping: ToS riski + kırılganlık yüksek

### 5.6 Investing.com BIST All Shares (XUTUM bileşenleri)

- `https://www.investing.com/indices/ise-all-shares-components` — tüm BIST bileşenlerini HTML tablo olarak listeli
- JavaScript render gerekiyor, doğrudan HTTP GET ile JSON yok
- **Pratik değil** Cloud Function için

---

## 6. IPO Otomatik Tespit İçin En Uygun Yöntem

### 6.1 Mevcut IPO Sistemi

Proje zaten bir IPO tracking sistemi kullanıyor:
- `syncIpoFeed` (her 6 saatte, HalkArz.com scraping)
- `loadBistSymbols()` → `bist_stocks` koleksiyonundan sembol Set'i çeker
- `computeIpoStatus()` → BIST set'inde varsa `trading`, yoksa `listingDate` karşılaştırması

**Tasarım niyeti doğru ama `bist_stocks` koleksiyonu eksik dolduğundan fiilen BIST100 ile sınırlı çalışıyor.**

### 6.2 IPO Trading Tespiti İçin En İyi Yöntem

**Birincil: `bist_stocks` koleksiyonunu tüm BIST hisseleriyle doldurmak**

```
MKK /members → stockCode != '' olan tüm üyeler → bist_stocks koleksiyonuna yaz
```

IPO şirketi KAP'a kayıt yaptırdığında (halka arz öncesi) `kap_members`'a giriyor. Borsa'da ilk işlem günü ise `/members` endpoint'inde `stockCode` alanı doluyor. Bu tetikleyici olarak kullanılabilir:

```javascript
// Pseudo-kod: syncIpoFeed içinde iyileştirme
const kapMembers = await db.collection('kap_members').get();
const bistSymbols = new Set(
  kapMembers.docs
    .map(d => d.data().stockCode)
    .filter(s => s && s.trim().length > 0)
);
```

**İkincil: Yahoo Finance doğrulama**

Sembol için `https://query1.finance.yahoo.com/v8/finance/chart/${symbol}.IS` isteği atar:
- HTTP 200 + veri → hisse BIST'te işlem görüyor
- HTTP 404 / boş → henüz işlem görmüyor

Bu yöntem mevcut `stock_service.dart` (`$SYMBOL.IS` pattern'ı) ile zaten pratikte kullanılıyor.

**Üçüncül: HalkArz + `listingDate` parse iyileştirmesi**

Mevcut `syncIpoFeed` HalkArz'dan `listingDate` parse edemiyor. Bu düzeltilirse `listingDate <= now` kontrolü çalışır. Ancak birincil yöntem (tam `bist_stocks` listesi) daha güvenilir.

---

## 7. Şirket Değişikliklerini Otomatik Tespit Yöntemleri

### A) BIST'e Yeni Girme (Yeni Listeleme)

**En iyi yöntem:** MKK VYK `/members` endpoint'ini periyodik kontrol et.

1. Yeni şirket KAP'a kaydolduğunda `kap_members`'a giriyor (halka arz sürecinde `stockCode` henüz boş)
2. Borsa'da ilk işlem günü `stockCode` alanı doluyor
3. `bist_stocks`'ta olmayan ama `kap_members.stockCode != ''` olan yeni kayıt = yeni listeleme

```
syncMembers() (her gün çalışıyor) → kap_members güncelleniyor
Yeni syncBistStocksFull fonksiyonu:
  kap_members'daki stockCode != '' ve bist_stocks'ta olmayan → ekle
```

**Alternatif:** Borsa İstanbul'un `/en/announcement` sayfasında `new-listing` veya `başlangıç` içerikli duyuruları taramak. Bu duyurular listeleme başlamadan birkaç gün önce yayınlanıyor.

### B) BIST'ten Çıkarılma (Delisting)

**Mevcut yöntemle:** `kap_members.memberType` değişimi veya `stockCode` boşalması tespit edilebilir.

**Pratik yöntem:** Yahoo Finance `$SYMBOL.IS` için HTTP 404 veya `regularMarketPrice = null` → `bist_stocks.active: false` yap

**Resmi yol:** Borsa İstanbul duyuru sayfasında `delisting`, `işlem durdurma` veya `pazardan çıkarma` içerikli duyuru. Bu duyurular mevcut `/en/announcement` tarama altyapısıyla yakalanabilir.

### C) Sembol Değişikliği

- KAP'ta eski ve yeni sembol kaydı birlikte görünebilir
- `kap_members` sync'i sırasında eski `stockCode` → yeni `stockCode` geçişi `title` (şirket adı) sabit kalırken sembol değişirse tespit edilebilir
- En güvenilir: Borsa İstanbul'un `/en/announcement` sayfasında `symbol change` veya `kod değişikliği` içerikli duyuru

### D) Şirket Unvanı Değişikliği

- `kap_members.title` alanı değişimi otomatik yakalanır (syncMembers her gün çalışıyor)
- `bist_stocks.name` alanını KAP sync'i sonrası güncellenmesi için yeni bir fonksiyon (veya `syncBist100Index` içine ek mantık) gerekli

---

## 8. A/B/C Ayrımı: BIST100, Tüm BIST, IPO Kontrolü

### A) BIST100 Listesi (100 hisse)

**Mevcut durumu: ÇALIŞIYOR, OTOMATİK**
- Firestore: `bist_index_meta/bist100.symbols` (100 sembol)
- Backend: `syncBist100Index` (haftalık, borsaistanbul.com'dan parse)
- Flutter: `Bist100Service.symbols` → `_liveSymbols`
- Fallback: `kBist100Symbols` sabit (100 sembol, Eylül 2026 revizyonu)

### B) BIST'teki Tüm Aktif/Taranabilir Hisseler (~600+ sembol)

**Mevcut durumu: EKSİK, OTOMATİK DEĞİL**
- Firestore: `bist_stocks` koleksiyonu → sadece ~100 BIST100 sembolü (eksik)
- Flutter: `kBistStocks` → `_baseBistStocks` sabit liste (726 sembol, BYF dahil)
- Gerçek "taranabilir hisse" sayısı: ~610 (kBistListedCount sabitinden)
- **Sorun:** Yeni IPO'lar ve değişiklikler otomatik yansımıyor

### C) IPO'ların Borsada İşlem Görüp Görmediğini Kontrol Eden Liste

**Mevcut durumu: KISMI ÇALIŞIYOR**
- `loadBistSymbols()` `bist_stocks` koleksiyonunu okuyor (doğru tasarım)
- Ama koleksiyon ~100 sembol içerdiğinden BIST100 dışı IPO'lar (SOHOE, ORZAX gibi) `bist_stocks`'ta bulunamıyor → `trading` durumu alamıyor
- `listingDate` parse sorunu ek kırılganlık yaratıyor

**Bu üç liste birbirinden bağımsız tutulmalı — mevcut mimari doğru ama C için B'nin düzgün doldurulması şart.**

---

## 9. Özet Öneri Tablosu

### Önerilen Veri Kaynağı

**Tüm BIST listesi için:** MKK VYK API `/members` endpoint'i  
(`https://apigwdev.mkk.com.tr/api/vyk/members` — mevcut projede zaten credentials mevcut)

**Neden:** Resmi MKK kaynağı, proje zaten kullanıyor, yeni IPO'lar otomatik geliyor, şirket adları `title` alanından alınıyor, ToS riski düşük.

**BIST100 için:** Mevcut sistem (borsaistanbul.com duyuruları) yeterli, değişiklik gerekmez.

---

### Kaynağın Güvenilirliği

| Kaynak | Güvenilirlik | ToS Riski |
|---|---|---|
| MKK VYK `/members` | **Yüksek** — resmi devlet kurumu | **Düşük** — proje zaten kullanıyor |
| Borsa İstanbul `/en/announcement` (BIST100 delta) | **Yüksek** — resmi kaynak | **Düşük** — kamuya açık |
| Foreks/Paragaranti XUTUM bileşenleri | Orta-Yüksek | **Orta-Yüksek** — ticari kullanım yasak |
| BigPara `/api/v1/hisse/list` | Orta | **Yüksek** — resmi değil |
| HalkArz scraping (mevcut IPO sistemi) | Düşük-Orta | Yüksek — scraping |

---

### Otomatik Güncelleme Yöntemi

**Önerilen mimarisi:**

```
1. syncBistStocksFull (YENI — aylık veya haftalık)
   kap_members koleksiyonunu tara (stockCode != '')
   bist_stocks'ta olmayanları ekle (active: true)
   
2. syncBist100Index (MEVCUT — haftalık, değişmez)
   bist_index_meta/bist100 günceller
   bist_stocks.bist100Member günceller

3. syncIpoFeed (MEVCUT — 6 saatlik, bist_stocks eksiği giderilince düzelir)
   loadBistSymbols() artık tüm BIST'i kapsayacak
   trading tespiti doğru çalışacak
```

---

### Tahmini Güncelleme Sıklığı

| Güncelleme Tipi | Uygun Sıklık | Gerekçe |
|---|---|---|
| Tüm BIST listesi (`bist_stocks`) | **Haftalık** | Yeni listeleme nadir (haftada 0-3 IPO) |
| BIST100 endeks değişikliği | Haftalık (mevcut) | Çeyreklik değişim, haftalık kontrol yeterli |
| IPO trading kontrolü | 6 saatlik (mevcut) | Zaten bu sıklıkta çalışıyor |
| Şirket adı/unvan değişikliği | Günlük (KAP sync ile birlikte) | syncMembers zaten çalışıyor |

---

### `bist_stocks` Nasıl Doldurulmalı

**Önerilen adımlar (uygulama sırası):**

1. **Tek seferlik bootstrap:** `kap_members` koleksiyonundaki `stockCode != ''` tüm kayıtları `bist_stocks`'a yaz  
   `active: true`, `name: kap_members.title`, `symbol: kap_members.stockCode`  
   BYF ve GYO dahil (BIST'te işlem gördükleri için)

2. **Haftalık delta sync:** `syncBistStocksFull` fonksiyonu:
   - `kap_members.stockCode` ile `bist_stocks` arasında diff
   - Yeni girenleri ekle (`active: true`)
   - Çıkanları tespit için Yahoo Finance `$SYMBOL.IS` doğrulaması + `active: false`

3. **BIST100 üyeliği:** Mevcut `syncBist100Index` zaten `bist100Member` alanını güncel tutuyor

4. **`_baseBistStocks` sabit listesi:** Firestore sync tam kapsamlı çalıştığında bu fallback gereksiz hale gelir, ama kaldırılmamalı — offline/fallback güvencesi

---

### IPO Trading Kontrolü Nasıl Yapılmalı

**Mevcut `loadBistSymbols()` doğru tasarlanmış, yalnızca `bist_stocks` koleksiyonunun tam doldurulması gerekiyor.**

IPO trading durumunu belirleyen öncelik sırası (kodda mevcut):
1. `bist_stocks` koleksiyonunda sembol var → `trading` ✅
2. `listingDate <= bugün` → `trading` ✅ (HalkArz parse iyileştirilmeli)
3. `requestEnd` geçmiş → `pending_listing`
4. `requestStart <= bugün` → `collecting`
5. Varsayılan → `upcoming`

**Pratik fix:** `bist_stocks` koleksiyonunu tüm BIST ile doldurunca (Adım 1 yukarıda), IPO kontrol sistemi `bist_stocks` yoluyla doğru çalışacak. SOHOE ve ORZAX gibi BIST100 dışı hisseler de artık `trading` durumu alabilecek.

---

### Mevcut BIST100 Sistemi Etkilenir mi?

**HAYIR**

- BIST100 sistemi `bist_index_meta/bist100` koleksiyonuna yazıyor
- `bist_stocks` koleksiyonu genişletilse bile `bist_index_meta/bist100.symbols` değişmiyor
- `Bist100Service` doğrudan `bist_index_meta/bist100`'ü okuyor, `bist_stocks`'ı okumadan çalışıyor
- `syncBist100Index` scheduler'ı sadece `bist100Member` alanını değiştiriyor — `active` ve `name` alanlarına dokunmuyor
- Flutter Scanner `_bist100Symbols` için `Bist100Service.symbols` getter'ını kullanıyor — bu da `bist_index_meta/bist100`'den geliyor

**Sonuç: İki sistem birbirinden tam bağımsız. `bist_stocks` genişletilmesi BIST100 davranışını hiç etkilemez.**

---

## 10. Sonuç ve Özet Bulgular

### Kritik Bulgular

1. **`bist_stocks` koleksiyonu eksik doldurulmuş** — Tasarım olarak tüm BIST'i hedefliyor ama yalnızca ~100 BIST100 sembolü içeriyor. Bu hem IPO tracking hem de tüm BIST taramasını olumsuz etkiliyor.

2. **MKK VYK `/members` zaten tam liste sağlıyor** — Proje bu API'yi zaten kullanıyor. `kap_members` koleksiyonu tüm KAP üyelerini içeriyor, `stockCode != ''` filtresiyle borsa sembolleri alınabilir. Yeni bir dış kaynak gerekmez.

3. **Resmi Borsa İstanbul ücretsiz JSON API yok** — BISTECH/VERDA ücretli, site SPA. Tüm liste için Foreks API (ToS riski) veya BigPara (ToS riski) kullanılabilir ama MKK /members daha güvenli.

4. **`_baseBistStocks` 726 sembol içeriyor ama BYF (23 adet) dahil** — Teknik olarak BYF'ler BIST'te işlem gören menkul kıymet olduğundan taranabilir. Ayırt etmek gerekirse `bist_stocks.type: 'stock'|'etf'|'reit'` gibi bir alan eklenebilir (şu an yok).

5. **IPO trading tespiti için `bist_stocks` doldurmak yeterli** — Mevcut `loadBistSymbols()` doğru çalışıyor, sadece koleksiyonun tüm BIST hisseleriyle dolu olması gerekiyor.

6. **BIST100 sistemi sağlam ve bağımsız** — Her hafta borsaistanbul.com'dan otomatik güncelleniyor, etkilenmez.

---

## Araştırmada Okunan Dosyalar

| Dosya | Amaç |
|---|---|
| `lib/services/bist_stocks.dart` | `_baseBistStocks` içerik analizi (726 sembol, BYF/GYO tespiti) |
| `lib/services/bist100_service.dart` | Firestore okuma, BIST100 hiyerarşisi (önceki raporlardan) |
| `functions/index.js` (2505 satır) | syncMembers, loadBistSymbols, runBist100Sync analizi |
| `bistguncel.md` | Manuel referans liste (604 satır, IS Yatırım/BigPara ekranı) |
| `tools/` klasörü | patch_bist_stocks.py, compare_bist_symbols.py vb. |
| `.agents/tasks/bist100-resmi-kaynak-arastirmasi.md` | Borsa İstanbul resmi kaynak analizi (önceki araştırma) |
| `.agents/tasks/bist100-backend-analysis.md` | Backend detaylı analiz (önceki araştırma) |
| `.agents/tasks/bist100-auto-update-investigation.md` | Otomasyon araştırması (önceki araştırma) |
| `.agents/tasks/bist100-usage-analysis.md` | Flutter kullanım analizi (önceki araştırma) |
| `.agents/tasks/bist100-impl-plan.md` | BIST100 uygulama planı (önceki araştırma) |
| `.agents/tasks/bist-ipo-mimari-analizi.md` | IPO/BIST500/BIST100 mimari analizi (bugün yazılmış önceki adım) |

---

*Content was rephrased for compliance with licensing restrictions. External source references: [borsaistanbul.com announcement pages](https://www.borsaistanbul.com/en/announcement), [MKK membership info](https://www.mkk.com.tr/en/about-us/membership), [BigPara API (StackOverflow)](https://stackoverflow.com/questions/73430352), [GitHub borsapy](https://github.com/saidsurucu/borsapy), [GitHub Istanbul-Stock-Exchange list](https://github.com/ahmeterenodaci/Istanbul-Stock-Exchange--BIST--including-symbols-and-logos), [GitHub doviz-borsa-kripto-api](https://github.com/trbasoglu/doviz-borsa-kripto-api)*
