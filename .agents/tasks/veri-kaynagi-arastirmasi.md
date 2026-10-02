# Veri Kaynağı Araştırması — Sonuç Raporu

**Tarih:** 2025-07  
**Kapsam:** bilancoveri.com entegrasyonu + Foreks/Paragaranti araştırması  
**Yöntem:** Kaynak kodu tarama + canlı HTTP GET testleri  
**Kısıt:** Hiçbir dosya değiştirilmedi.

---

## Özet (Kısa Yanıt)

| Soru | Yanıt |
|------|-------|
| bilancoveri.com BIST100 üyeliği döndürüyor mu? | **HAYIR** — kesin olarak doğrulandı |
| Foreks paragaranti endpoint'i erişilebilir mi? | **HAYIR** — DNS çözümlenemiyor (subdomain yok/kaldırılmış) |
| Mevcut entegrasyondan BIST100 listesi çıkarılabilir mi? | **HAYIR** — ek kaynak gerekli |
| Alternatif çalışan kaynak var mı? | **BELİRSİZ** — fintables/bigpara JSON API test edilemedi |

---

## A) Bilancoveri.com Sonucu

### Kullanılan Endpoint'ler

**1. Tüm şirketler listesi (Cloud Function tarafından kullanılan):**
```
GET https://bilancoveri.com/api/v1/sirketler.json
```
- Kaynak: `functions/index.js` satır 463 (`fetchAllFundamentals` fonksiyonu)
- Auth: Yok — kimlik doğrulama gerektirmez
- User-Agent: `TeknikBakis-Backend/1.0`

**2. Tekil hisse endpoint'i (Flutter istemci tarafından kullanılan):**
```
GET https://bilancoveri.com/api/v1/hisse/{ticker}.json
```
- Kaynak: `lib/services/bilanco_veri_service.dart` satır 27
- Örnek: `https://bilancoveri.com/api/v1/hisse/thyao.json`
- Auth: Yok

---

### Gerçek Test Yanıtı — sirketler.json

**HTTP Durumu:** 200 OK  
**Test tarihi:** Canlı test (bu araştırma sırasında)

**Yanıt yapısı (üst düzey):**
```json
{
  "companies": [ ... ],
  "count": 591,
  "generated_at": "2026-10-02T02:50:59Z",
  "source": "KAP / Borsa İstanbul"
}
```

**Her şirket nesnesindeki alanlar (16 alan):**
```
detail, dividend_yield, ev_ebitda, fin_group, float_ratio,
last_period, market_cap_mn_try, name, pb, pe, price,
roa, roe, sector, sector_code, ticker
```

**Örnek 5 kayıt:**
```
ticker=A1CAP  sector=Aracı Kurumlar     pe=1.71
ticker=A1YEN  sector=Elektrik           pe=7.72
ticker=AAGYO  sector=Gayrimenkul Y.O.   pe=-157.0
ticker=ACSEL  sector=Kimya, Petrol      pe=-153.29
ticker=ADEL   sector=Sınai (Diğer)      pe=-15.49
```

**Toplam şirket adedi:** 591

**Sembol formatı:** Düz 4-5 harf kodu, ek uzantı yok — örn. `THYAO`, `A1CAP`, `SISE` (Yahoo Finance `.IS` suffix'i yok)

---

### BIST100 Üyelik Verisi

**SONUÇ: HAYIR — kesin olarak doğrulandı.**

Kontrol edilen alanlar (hiçbiri mevcut değil):
- `bist100` → **YOK**
- `xu100` → **YOK**
- `is_bist100` → **YOK**
- `isBist100` → **YOK**
- `index` → **YOK**
- `index_code` → **YOK**
- `componentSymbols` → **YOK**
- `instruments` → **YOK**

`sector_code` alanındaki değerler endeks kodu değil, sektör kodu:  
`XAKUR, XBANK, XBLSM, XELKT, XFINK, XGIDA, XGMYO, XGSYO, XHOLD, XILTM, XINSA, XKAGT, XKMYA, XMADN, XMANA, XMESY, XSGRT, XSPOR, XTAST, XTCRT, XTEKS, XTRZM, XUHIZ, XULAS, XUMAL, XUSIN, XUTEK, XYORT`

Bunlar Borsa İstanbul sektör endeks kodlarıdır (XBANK = bankacılık sektörü), XU100 endeks üyeliği değil.

`fin_group` değerleri de yalnızca finansal raporlama grubu kodlarıdır: `UFRS`, `UFRS_K`, `XI_29`, `XI_29K`.

**Bireysel hisse endpoint'i** (`/hisse/thyao.json`) da aynı durum: `company` alt nesnesi sirketler.json ile aynı 16 alanı içeriyor; ek endeks üyeliği bilgisi yok.

---

### Mevcut Projede Kullanım

`functions/index.js` içindeki `updateFundamentals` fonksiyonu sirketler.json'u kullanarak şu alanları Firestore `fundamentals/{ticker}` koleksiyonuna yazar:

```javascript
pe, pb, ev_ebitda, roe, roa, dividend_yield, float_ratio,
market_cap_mn_try, name, sector
```

`lib/services/bilanco_veri_service.dart` Flutter tarafında tekil hisse endpoint'ini kullanarak aynı temel göstergeleri çeker. Her iki kullanım da BIST100 listesiyle ilgisiz — sadece temel analiz verisi.

---

## B) Foreks / Paragaranti Sonucu

### Workspace'de Entegrasyon Var mı?

**HAYIR.** `foreks`, `paragaranti`, `finnet`, `matriks` kelimeleri için yapılan arama sonucu:
- Kaynak Dart/JS kodunda bu isimlerle entegrasyon yok
- Yalnızca `.agents/tasks/` altındaki önceki araştırma notlarında bahsediliyor (bu notlar implementasyon değil, araştırma belgesi)

### Foreks Paragaranti Endpoint Testi

Belgelenen endpoint (önceki araştırma notu + GitHub kaynağından):
```
GET https://web-paragaranti-pubsub.foreks.com/web-services/securities/definition?name=XU100&group=E&exchange=BIST
```

**Test sonucu: DNS ÇÖZÜMLENEMIYOR**
- Hata: `"Uzak ad çözülemedi: 'web-paragaranti-pubsub.foreks.com'"`
- `foreks.com` ana domain'i DNS'de çözümleniyor (65.9.9.x IP'leri) ve HTTPS 200 dönüyor
- `web-paragaranti-pubsub` subdomaini artık mevcut değil veya bu ağdan erişilemiyor
- `data.foreks.com` (95.0.13.110) DNS'de çözümleniyor ama aynı path ile yanıt alınamadı
- `api.foreks.com` → DNS çözümlenemiyor

**SONUÇ: `XU100` bileşen listesi döndürdüğü doğrulanamadı. Endpoint erişilemez durumda.**

### Foreks Hakkında Ek Bilgi

Community'de belgelenen bu endpoint (GitHub: trbasoglu/doviz-borsa-kripto-api), Foreks'in Borsa İstanbul'un resmi veri sağlayıcısı olduğu dönemdeki dahili API'ye işaret ediyor. Subdomain değişmiş veya kaldırılmış olabilir. Authentication gerektirip gerektirmediği de test edilemedi.

---

## C) Diğer Entegrasyonlar (Workspace Taraması)

### Yahoo Finance
- `lib/services/stock_service.dart`: `https://query1.finance.yahoo.com/v8/finance/chart` — hisse fiyatı için kullanılıyor
- `lib/screens/tradingview_chart_screen.dart`: `SYMBOL.IS` pattern ile Yahoo Finance URL'leri oluşturuluyor
- **BIST100 üyeliği için uygun mu?** HAYIR — Yahoo Finance BIST100 bileşen listesi endpoint'i sunmuyor; sadece fiyat verisi

### Investing.com
- `lib/services/kap_news_service.dart`: `https://tr.investing.com/equities/{slug}-news` — haber URL'leri için kullanılıyor
- **Veri API'si olarak kullanılıyor mu?** HAYIR — sadece web link oluşturma

### Bigpara (Hürriyet/ForInvest)
- `lib/screens/news_screen.dart`: `https://bigpara.hurriyet.com.tr/rss/borsa/` — RSS haber akışı için
- Önceki araştırma notlarında bahsedilen `http://bigpara.hurriyet.com.tr/api/v1/hisse/list` endpoint'i test edildi: **HTML dönüyor** (ForInvest/Foreks SPA sayfasına yönlendiriliyor), JSON API yanıtı yok
- **BIST100 listesi için kullanılabilir mi?** HAYIR — API endpoint'i artık çalışmıyor

### fintables.com
- Önceki araştırma notlarında `GET https://fintables.com/api/indices/bist100/stocks` önerilmişti
- **Test sonucu:** Yanıt alınamadı (timeout veya bağlantı reddedildi)
- **DOĞRULANAMADI**

### KAP (MKK VYK API)
- `lib/services/kap_news_service.dart`: `https://www.kap.org.tr/tr/api/disclosures` — KAP bildirim haberleri
- BIST100 üyelik bilgisi sunmuyor — sadece şirket bildirimleri

### TradingView
- `lib/screens/tradingview_screen.dart` ve `tradingview_chart_screen.dart`: WebView iframe içinde kullanılıyor
- Programatik API entegrasyonu yok — sadece embed URL

---

## D) Ücretsiz / Kimlik Doğrulamasız Çalışıyor mu?

| Kaynak | Ücretsiz | Auth gerekiyor mu? | Durum |
|--------|----------|-------------------|-------|
| bilancoveri.com sirketler.json | ✅ Evet | Hayır | Çalışıyor, 200 OK |
| bilancoveri.com hisse/{ticker}.json | ✅ Evet | Hayır | Çalışıyor |
| Foreks paragaranti-pubsub | ❓ Bilinmiyor | Bilinmiyor | **DNS yok — erişilemiyor** |
| fintables.com/api/indices/bist100 | ❓ Bilinmiyor | Bilinmiyor | **Timeout — doğrulanamadı** |
| bigpara API v1 | ❓ Bilinmiyor | Bilinmiyor | **HTML dönüyor — JSON yok** |
| Yahoo Finance (fiyat) | ✅ Evet (crumb gerekli) | Cookie/crumb | Çalışıyor, mevcut entegrasyon var |

---

## E) Günlük Otomatik Backend Senkronizasyonuna Uygun mu?

### bilancoveri.com — BIST100 listesi için UYGUN DEĞİL

Mevcut `updateFundamentals` fonksiyonu (günde 3 kez çalışıyor) zaten bilancoveri.com'dan başarıyla veri çekiyor ve Firestore'a yazıyor. Ancak bu veri BIST100 üyeliğini içermiyor. Dolayısıyla:

- **Temel göstergeler (pe, pb, roe, vb.) için:** Mevcut yapı çalışıyor ✅
- **BIST100 bileşen listesi için:** bilancoveri.com kullanılamaz ❌

### Genel Değerlendirme

Mevcut projede `bist_stocks` ve `bist_index_meta` Firestore koleksiyonlarını dolduracak otomatik kaynak **yok**. Önceki araştırma notları (`.agents/tasks/bist100-backend-analysis.md`) bu durumu doğru tespit etmiş.

---

## Öneriler (Uygulama Yapmadan)

Aşağıdaki seçenekler araştırılabilir — hiçbirini bu rapor kapsamında uygulamadım:

1. **fintables.com doğrulaması:** `https://fintables.com/api/indices/bist100/stocks` endpoint'ini tarayıcıdan veya farklı bir ağdan test edin. Eğer JSON döndürüyorsa ve auth gerektirmiyorsa en temiz seçenek.

2. **Borsa İstanbul resmi XU100 bileşen Excel'i:** `https://www.borsaistanbul.com/tr/endeksler/bist-pay-endeksleri/bist-100` sayfasından periyodik Excel indirme. Otomasyonu zor ama resmi veri.

3. **Manuel admin endpoint:** Mevcut `syncKapManual` pattern'ı gibi, bir admin HTTP endpoint'i üzerinden manuel güncelleme yapılabilir. Bu durumda listeyi siz elle girersiniz, Cloud Function yazmaz.

4. **Alternatif Foreks subdomain araştırması:** Foreks'in aktif API subdomainlerini belirlemek için web browser'dan Network tab'ı ile `foreks.com` incelenebilir. `web-paragaranti-pubsub` subdomaini DNS'de çözümlenmiyor; farklı bir subdomain kullanılıyor olabilir.

---

## Kaynak Referansları

| Dosya | İlgili Bulgu |
|-------|--------------|
| `functions/index.js` satır 463 | `fetchAllFundamentals()` — `https://bilancoveri.com/api/v1/sirketler.json` |
| `lib/services/bilanco_veri_service.dart` satır 10 | `_baseUrl = 'https://bilancoveri.com/api/v1'` |
| `lib/services/stock_service.dart` satır 9 | Yahoo Finance `query1.finance.yahoo.com` |
| `lib/services/kap_news_service.dart` satır 253 | KAP bildirimleri API |
| `lib/screens/news_screen.dart` satır 111 | BigPara RSS (haber, API değil) |
| `.agents/tasks/bist100-backend-analysis.md` | Foreks endpoint referansı (önceki araştırma) |
