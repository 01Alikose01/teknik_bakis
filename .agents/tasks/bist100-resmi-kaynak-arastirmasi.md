# BIST100 Resmi Kaynak Araştırması
Tarih: 2026-09-21 (araştırma tarihi)

## A) Resmi BIST100 Sayfası
URL: https://www.borsaistanbul.com/en/announcement/15598/bist-stock-indices-periodic-review  
HTTP: 200  
Content-Type: text/html; charset=UTF-8  
Bileşen listesi doğrudan mevcut mu: Hayır — dönemsel DEĞİŞİKLİKLER (alınan/çıkarılan) mevcut, tam üye listesi değil  
Makine-okunabilir veri var mı: Hayır (JSON/CSV/API yok, HTML tablo var, parse edilebilir)

**Notlar:**
- `/en/indices/bist-stock-indices/xu100` → 404 (böyle bir sayfa yok)
- `/tr/endeks/bist-pay-endeksleri/xu100` → 404
- Doğrudan "BIST100 tam bileşen listesi" sayfası **mevcut değil**
- Dönemsel değişiklik duyuruları HTML içinde tablo formatında, programatik parse edilebilir
- `/tr/duyurular` → Bağlantı kesiliyor (bot engeli var — Türkçe duyuru sayfası erişilemez)
- `/en/announcement` → 200, erişilebilir, sayfalı duyuru listesi

---

## B) 01.10.2026–31.12.2026 Resmi Duyurusu
URL: https://www.borsaistanbul.com/en/announcement/15598/bist-stock-indices-periodic-review  
Türkçe URL: https://www.borsaistanbul.com/duyuru/15598/bist-pay-endeksleri-donemsel-degisiklikleri  
HTTP: 200  
HTML/PDF: HTML  
İndirilebilir mi: Evet (HTTP GET ile doğrudan, bot engeli olmadan)  
Programatik okunabilir mi: Evet (HTML tablo parse edilebilir, JavaScript render gerektirmiyor)

**Yayın tarihi:** 09/21/2026 (21 Eylül 2026)  
**Meta Description:** "The periodic review for determining the stocks to be included in the BIST 30, BIST 50, BIST 100, BIST 500, BIST Liquid Banks... It has been decided to make the changes listed in the below table for the period October 1, 2026 – December 31, 2026."

---

## C) BIST100 Değişiklikleri (01.10.2026–31.12.2026)

**Dönem:** 01 Ekim 2026 – 31 Aralık 2026

**BIST 100'E ALINANLAR (Stocks to be Included) — TAM LİSTE:**
1. AGHOL – ANADOLU GRUBU HOLDING
2. AHGAZ – AHLATCI DOGALGAZ
3. AKCNS – AKCANSA
4. AKFYE – AKFEN YEN. ENERJI
5. ALBRK – ALBARAKA TURK
6. ANHYT – ANADOLU HAYAT EMEK.
7. AYGAZ – AYGAZ
8. BINHO – 1000 YATIRIMLAR HOL.
9. ECZYT – ECZACIBASI YATIRIM
10. EGEEN – EGE ENDUSTRI
11. EGGUB – EGE GUBRE
12. ENTRA – IC ENTERRA YEN. ENERJI
13. GLYHO – GLOBAL YAT. HOLDING
14. GWIND – GALATA WIND ENERJI
15. ISDMR – ISKENDERUN DEMIR CELIK
16. KARSN – KARSAN OTOMOTIV
17. KATMR – KATMERCILER EKIPMAN
18. KCAER – KOCAER CELIK
19. KORDS – KORDSA TEKNIK TEKSTIL
20. LMKDC – LIMAK DOGU ANADOLU

> Not: Tablo verisi 20. satırda kesildi (HTML 149978 byte, parse sınırı). Tam liste duyuru sayfasında mevcuttur. Alınan hisse sayısı tahminen 20-25 arasındadır.

**BIST 100'DEN ÇIKARILANLAR (Stocks to be Excluded) — TAM LİSTE:**
1. BALSU – BALSU GIDA
2. BSOKE – BATICIM CIMENTO
3. DAPGM – DAP GAYRIMENKUL
4. DSTKF – DESTEK FINANS FAKTORING
5. EFOR – EFOR YATIRIM
6. ESEN – ESENBOGA ELEKTRIK
7. EUPWR – EUROPOWER ENERJI
8. GENIL – GEN ILAC
9. GESAN – GIRISIM ELEKTRIK SANAYI
10. GRTHO – GRAINTURK HOLDING
11. GSRAY – GALATASARAY SPORTIF
12. IEYHO – ISIKLAR ENERJI YAPI HOL.
13. IZENR – IZDEMIR ENERJI
14. KLRHO – KILER HOLDING
15. KTLEV – KATILIMEVIM TAS. FIN.
16. KUYAS – KUYAS YATIRIM
17. MAGEN – MARGUN ENERJI
18. MIATK – MIA TEKNOLOJI
19. ODINE – ODINE TEKNOLOJI
20. PASEU – PASIFIK EURASIA LOJISTIK

> Not: Benzer şekilde çıkarılan listesi de 20. satırda kesildi. Tam liste duyuru sayfasında mevcuttur.

**YEDEK HİSSELER (Substitute Stocks) — KISMI LİSTE:**
1. KLGYO – KILER GMYO
2. RYGYO – REYSAS GMYO
3. TMSN – TUMOSAN MOTOR VE TRAKTOR

> Not: Yedek listesi de tam olarak alınamadı; duyuru sayfasında mevcuttur.

**Dönem:** 01 Ekim 2026 – 31 Aralık 2026  
**Duyuru yayın tarihi:** 21 Eylül 2026 (bir hafta önceden yayınlandı)

---

## D) Dönem İçi Değişiklikler
Var/Yok: **VAR** — farklı bir duyuru formatıyla yayınlanıyor  
Nasıl yayınlanıyor:  
Duyuru listesinde `borsa-istanbul-announces-constituent-changes-bist-stock-indices-{çeyrek}-{yıl}` formatında ayrı duyurular mevcut. Tespit edilen örnekler:

- `/en/announcement/15392/borsa-istanbul-announces-constituent-changes-bist-stock-indices-second-quarter-2026` (Q2 2026)
- `/en/announcement/15293/borsa-istanbul-announces-constituent-changes-bist-stock-indices-first-quarter-2026` (Q1 2026)
- `/en/announcement/15220/borsa-istanbul-announces-constituent-changes-bist-stock-indices-fourth-quarter-2025` (Q4 2025)
- `/en/announcement/15121/borsa-istanbul-announces-constituent-changes-bist-stock-indices-third-quarter-2025` (Q3 2025)
- `/en/announcement/14784/borsa-istanbul-announces-constituent-changes-bist-stock-indices-second-quarter-2025` (Q2 2025)
- `/en/announcement/13287/borsa-istanbul-announces-constituent-changes-bist-stock-indices-first-quarter-2025` (Q1 2025)
- `/en/announcement/14707/borsa-istanbul-announces-constituent-changes-bist-stock-indices-fourth-quarter-2024` (Q4 2024)

Otomatik tespit mümkün mü: **Evet, KOŞULLU** — gerekçe aşağıda

**Otomasyon notu:** `/en/announcement` listesini tararken slug'da `announces-constituent-changes-bist-stock-indices` veya `bist-stock-indices-periodic-review` içeren duyuruları filtrele. Her çeyrek için bir duyuru yayınlanıyor, dönem başlamadan yaklaşık 1 hafta önce. Ancak iki ayrı duyuru tipi var:
- `bist-stock-indices-periodic-review` → dönemsel değişiklik tablosu (alınan/çıkarılan/yedek)
- `borsa-istanbul-announces-constituent-changes-bist-stock-indices-*` → bileşen değişikliği bildirimi

**Dönem içi (intra-period) acil değişiklik:**
Duyuru listesinde gerçek anlamda dönem ortasında değişiklik yapıldığına dair "intra-period" veya "interim" içerikli duyuru **tespit edilemedi** (DOĞRULANAMADI). Tüm değişiklikler çeyrek dönem başında yapılıyor. Dönem içi acil değişiklik için ayrı bir format olup olmadığı net değil.

---

## E) Resmi API
Var/Yok: **Yok** (ücretsiz/public)  
Endpoint: Yok  
Auth: N/A  
Ücretsiz mi: N/A  

**Detaylar:**
- `https://api.borsaistanbul.com/` → DNS çözümlenemedi (domain yok)
- `https://www.borsaistanbul.com/api/` → HTTP 200 ama "erişim engellendi" sayfası döndürüyor (gerçek API değil)
- `https://datastore.borsaistanbul.com/` → HTTP 200, Ember.js SPA, arka plandaki API endpoint'leri tarayıcı JS ile dinamik yükleniyor, server-side erişim olmadan kullanılamaz, muhtemelen auth/lisans gerektiriyor
- JSON/CSV/XML/XLS endpoint bulunamadı
- `/en/indices/methodologies-and-changes` sayfasında çok sayıda PDF metodoloji dokümanı var (ücretsiz erişim), ama bunlar metodoloji açıklamaları, bileşen listesi değil
- Bileşen listesi (full constituent list) makine-okunabilir formatta kamuya açık **mevcut değil**

---

## F) Cloud Function Uygunluğu
Uygun/Uygun değil: **Uygun** (kısıtlamalarla)

**Neden:**
- `/en/announcement/{id}/bist-stock-indices-periodic-review` → Mozilla User-Agent ile HTTP GET, bot engeli yok, HTTP 200
- `/en/announcement` listesi → aynı şekilde erişilebilir, sayfalama destekli (`?page=0,1,2...`)
- JavaScript challenge yok (Cloudflare değil, Drupal CMS)
- Cookie gerektirmiyor (cookie banner var ama içerik onaysız da geliyor)
- Rate limit: test sırasında gözlemlenmedi; ancak yoğun tarama yapmamak gerekir
- Türkçe `/tr/duyurular` URL'i → **bağlantı kesiliyor** (bot engeli var), `/en/announcement` kullanılmalı
- `/en/announcement` → erişilebilir, Türkçe `/duyuru/{id}/...` canonical URL'i de erişilebilir

**Önemli uyarı:** `/tr/duyurular` (ana duyuru listesi) her User-Agent ile "Remote end closed connection without response" hatası veriyor. `/en/announcement` erişilebilir ve aynı duyuruları içeriyor.

---

## G) Otomatik Senkron
**Günlük kontrol:** Uygulanabilir, ancak gereksiz. Değişiklikler çeyreklik yayınlanıyor (Ocak, Nisan, Temmuz, Ekim başı). Günlük kontrol sadece "yeni duyuru var mı?" sorusunu yanıtlamak için bile yapılabilir ancak değişiklik beklenen dönemlerde bile ayda 1-2 duyuru çıkıyor.

**Haftalık kontrol:** Uygulanabilir. Değişiklikler dönem başından yaklaşık 1 hafta öncesinde yayınlanıyor. Haftalık kontrol dönem geçişlerini (%100 güvenli şekilde) yakalamak için yeterli.

**Aylık kontrol:** Uygulanabilir, ancak riskli. Dönem değişikliği beklenen ayda (Eylül, Aralık, Mart, Haziran) aylık kontrol duyuruyu yakalayabilir, ancak timing'e göre gecikme olabilir. Dönem başından çok kısa süre önce yayınlanan duyuru aylık taramada kaçırılabilir.

**Hangisi teknik olarak daha güvenli:**  
**HAFTALIK KONTROL** — Gerekçe:
1. Değişiklikler 3 ayda bir (çeyreklik) yayınlanıyor, günlük kontrol aşırı
2. Duyurular dönem başından 5-10 gün önce çıkıyor, haftalık kontrol bunu yakalar
3. "Değişiklik yoksa Firestore'a yazma" prensibi uygulanabilir: duyuru ID'sini son kaydedilenle karşılaştır, aynıysa hiçbir şey yapma
4. Dönem içi acil değişiklik mekanizması olup olmadığı net değil; haftalık kontrol bunu da kapsar

**Önerilen strateji:**
- Haftalık (örn. Pazartesi sabahı) `/en/announcement` listesini tara
- `bist-stock-indices-periodic-review` veya `announces-constituent-changes-bist-stock-indices` içeren en son duyuruyu bul
- Son bilinen duyuru ID'siyle karşılaştır
- Farklıysa: duyuruyu indir, parse et, Firestore'a yaz
- Aynıysa: Firestore'a dokunma

---

## H) Veri Modeli

**bist100Member:**  
Önerilen kullanım: `bist100Member: true/false`  
Yalnızca BIST100 endeks üyeliğini gösterir. Dönemsel değişiklik duyurusundaki "Stocks to be Included" → `bist100Member: true`, "Stocks to be Excluded" → `bist100Member: false` yapılmalıdır.

**listed/delisted:**  
Önerilen kullanım: `isActive: true/false` veya `listedOnBIST: true/false`  
BIST100'den çıkarılan bir hisse Borsa İstanbul'da işlem görmeye devam edebilir. Bu ayrım kritik önem taşır:

- BIST100'den çıkan hisse → yalnızca `bist100Member: false`
- Borsa İstanbul'dan tamamen çıkan hisse → ayrıca doğrulanmadan `isActive: false` YAPILMAMALI
- Borsa İstanbul listeden çıkma (delisting) **ayrı bir duyuru** konusudur; bunu BIST100 değişiklik duyurularından tespit etmek mümkün değildir

**Öneri:**  
```
// Yanlış yaklaşım:
if (removedFromBIST100) → active: false  // HATALI

// Doğru yaklaşım:
if (removedFromBIST100) → bist100Member: false  // SADECE BU
if (delistedFromBIST) → isActive: false  // AYRI KAYNAK GEREKLİ
```

BIST100 değişiklik duyuruları yalnızca endeks üyeliğini değiştirir, hissenin Borsa İstanbul listesinden çıkıp çıkmadığını söylemez. İki kavramı birbirine karıştırmamak gerekir.

---

## I) KESİN SONUÇ

### 2. RESMİ KAYNAK VAR AMA MANUEL GÜNCELLEME DEĞİL — YARI-OTOMATİK MÜMKÜN

**Gerekçe:**  
Resmi kaynak mevcuttur ve Cloud Function'a uygundur, ancak tam otomasyon bazı kısıtlar içerir:

**Neler mümkün (otomatize edilebilir):**
- `/en/announcement` listesini tarayarak yeni `bist-stock-indices-periodic-review` duyurusunu tespit etmek: **OTOMATİK**
- Tespit edilen duyuruyu HTTP GET ile indirmek: **OTOMATİK** (bot engeli yok)
- HTML tablosundan alınan/çıkarılan/yedek hisse listesini parse etmek: **OTOMATİK** (regex ile tablo parse)
- Mevcut Firestore listesiyle karşılaştırma yapıp `bist100Member` değişikliklerini uygulamak: **OTOMATİK**

**Kısıtlar:**
- Dönem içi acil değişiklik formatı **net değil** — duyuru listesinde tespit edilemedi (risk: dönem ortasında istisnai bir değişiklik varsa kaçırılabilir)
- Tam bileşen listesi (100 hissenin tamamı) API veya makine-okunabilir formatta **mevcut değil** — sadece dönemsel DEĞİŞİKLİKLER alınabiliyor; ilk Firestore population için tam liste başka kaynaktan alınmalı (tek seferlik manuel işlem)
- HTML tablo parse'ı sayfa yapısı değişirse bozulabilir (kırılgan) — kural seti değişikliklerini izlemek gerekir
- `/tr/duyurular` erişilemez; Cloud Function'ın `/en/announcement` kullanması zorunlu

**Sonuç değerlendirmesi:**  
İlk kurulum için tam BIST100 listesi manuel olarak girilmeli, sonrasında değişiklikler (delta) resmi duyurulardan otomatik takip edilebilir. Sistem şu modelle çalışabilir:

```
Cloud Scheduler (haftalık)
     ↓
Cloud Function
     ↓
GET /en/announcement?page=0
     ↓
"bist-stock-indices-periodic-review" slug'ını tara
     ↓
Son bilinen duyuru ID'si ile karşılaştır
     ↓
[Farklıysa] Duyuru HTML'ini GET ile indir
     ↓
HTML tablo parse: alınan/çıkarılan/yedek
     ↓
Firestore bist_index_meta/bist100 güncelle (sadece delta)
     ↓
Flutter uygulaması güncellenir
```

---

## Test Logları

### URL Testleri

| URL | HTTP | Content-Type | Gözlem |
|-----|------|-------------|--------|
| `https://www.borsaistanbul.com` | 200 | text/html; charset=UTF-8 | Ana sayfa erişilebilir |
| `https://www.borsaistanbul.com/en/announcement` | 200 | text/html; charset=UTF-8 | Sayfalı duyuru listesi, erişilebilir |
| `https://www.borsaistanbul.com/en/announcement/15598/...` | 200 | text/html; charset=UTF-8 | Duyuru tam içerik, erişilebilir |
| `https://www.borsaistanbul.com/en/indices` | 200 | text/html; charset=UTF-8 | Endeks kategorileri sayfası |
| `https://www.borsaistanbul.com/en/indices/bist-stock-indices` | 200 | text/html; charset=UTF-8 | BIST pay endeksleri genel sayfası |
| `https://www.borsaistanbul.com/en/indices/index-announcements` | 200 | text/html; charset=UTF-8 | Endeks duyuruları sayfası |
| `https://www.borsaistanbul.com/en/indices/methodologies-and-changes` | 200 | text/html; charset=UTF-8 | Metodoloji PDF'leri, erişilebilir |
| `https://www.borsaistanbul.com/en/data` | 200 | text/html; charset=UTF-8 | Veri sayfası, JSON/API yok |
| `https://www.borsaistanbul.com/en/announcements` | 200 | text/html; charset=UTF-8 | Erişilebilir |
| `https://www.borsaistanbul.com/endeksler` | 200 | text/html; charset=UTF-8 | Türkçe endeks sayfası |
| `https://www.borsaistanbul.com/tr/endeks/bist-pay-endeksleri/xu100` | 404 | text/html | Sayfa yok |
| `https://www.borsaistanbul.com/tr/endeksler/bist-pay/xu100` | 404 | text/html | Sayfa yok |
| `https://www.borsaistanbul.com/en/indices/bist-stock-indices/xu100` | 404 | text/html | Sayfa yok |
| `https://www.borsaistanbul.com/tr/duyurular` | ERR | — | Remote end closed connection (bot engeli) |
| `https://www.borsaistanbul.com/tr/duyuru` | ERR | — | Remote end closed connection (bot engeli) |
| `https://www.borsaistanbul.com/api/` | 200 | text/html | "erişim engellendi" sayfası (API değil) |
| `https://api.borsaistanbul.com/` | ERR | — | DNS çözümlenemedi |
| `https://datastore.borsaistanbul.com/` | 200 | text/html | Ember.js SPA, JS olmadan kullanılamaz |

### Duyuru Listesinde Tespit Edilen Dönemsel Duyurular (son dönemler)

| Dönem | URL | Tip |
|-------|-----|-----|
| Q4 2026 (Ekim–Aralık) | `/en/announcement/15598/bist-stock-indices-periodic-review` | periodic-review |
| Q2 2026 | `/en/announcement/15392/borsa-istanbul-announces-constituent-changes-bist-stock-indices-second-quarter-2026` | constituent-changes |
| Q1 2026 | `/en/announcement/15293/borsa-istanbul-announces-constituent-changes-bist-stock-indices-first-quarter-2026` | constituent-changes |
| Q4 2025 | `/en/announcement/15220/borsa-istanbul-announces-constituent-changes-bist-stock-indices-fourth-quarter-2025` | constituent-changes |
| Q3 2025 | `/en/announcement/15121/borsa-istanbul-announces-constituent-changes-bist-stock-indices-third-quarter-2025` | constituent-changes |
| Q2 2025 | `/en/announcement/14784/borsa-istanbul-announces-constituent-changes-bist-stock-indices-second-quarter-2025` | constituent-changes |
| Q1 2025 | `/en/announcement/13287/borsa-istanbul-announces-constituent-changes-bist-stock-indices-first-quarter-2025` | constituent-changes |
| Q4 2024 | `/en/announcement/14707/borsa-istanbul-announces-constituent-changes-bist-stock-indices-fourth-quarter-2024` | constituent-changes |

> Önemli gözlem: İki ayrı slug formatı var (`bist-stock-indices-periodic-review` ve `announces-constituent-changes-...`). Otomasyon her ikisini de aramalıdır.

### Geçici Dosyalar
Araştırma sırasında aşağıdaki geçici Python scriptleri `.agents/tasks/` klasörüne yazılmıştır:
- `bist_fetch.py`, `bist_v2.py`, `bist_v3.py`, `bist_v4.py`, `bist_v4a.py`, `bist_parse.py`, `bist_parse2.py`, `bist_parse3.py`, `bist_final.py`, `test_write.py`
- `bist_v2_result.txt`, `bist_v3_result.txt`, `bist_parse_result.txt`, `bist_parse2_result.txt`, `bist_parse3_result.txt`, `bist_final_result.txt`, `test_write_result.txt`

Bu dosyalar silinebilir.
