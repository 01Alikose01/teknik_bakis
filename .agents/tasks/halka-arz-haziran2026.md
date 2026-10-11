# 1 Haziran 2026 Sonrası Halka Arz Araştırma Raporu

**Tarih:** 5 Ekim 2026  
**Amaç:** 1 Haziran 2026 itibaren BİST'te işlem görmeye başlayan halka arz hisselerini tespit etmek ve bunların `bist 500.md` içinde yer alıp almadığını belirlemek.

---

## ÖZET CEVAP

1 Haziran 2026 – 5 Ekim 2026 arasında **21 yeni hisse** Borsa İstanbul'da işlem görmeye başlamıştır.

- **VAR (bist 500.md'de mevcut):** 2 hisse — KPEKS, NETGL (her ikisi de sıfır değerlerle eklenmiş)
- **YOK (bist 500.md'de eksik):** 19 hisse

---

## TAM LİSTE (Tarihe Göre Sıralı)

| Sembol | Şirket Adı | İşlem Başlangıcı | bist 500.md Durumu |
|--------|-----------|-----------------|-------------------|
| BETAE | Beta Enerji ve Teknoloji | 01.07.2026 | **YOK** |
| ORZAX | Orzaks İlaç ve Kimya | 07.07.2026 | **YOK** |
| SOHOE | Soho Giyim ve Enerji | 08.07.2026 | **YOK** |
| GOLDA | Golda Gıda | 09.07.2026 | **YOK** |
| ISVEA | İsvea Seramik ve Banyo Ürünleri | 10.07.2026 | **YOK** |
| EKIM | Ekim Turizm | 10.07.2026 | **YOK** |
| SSAAT | Saat ve Saat | 15.07.2026 | **YOK** |
| SARAE | Sa-Ra Enerji İnşaat | 17.07.2026 | **YOK** |
| METEN | Metgün Enerji Yatırımları | 28.07.2026 | **YOK** |
| KARCL | Kardemir Çelik Sanayi | 29.07.2026 | **YOK** |
| MASFN | Masfen Enerji | 29.07.2026 | **YOK** |
| ALBTN | Albayrak Hazır Beton | 29.07.2026 | **YOK** |
| BEWEN | Bewen Enerji | 07.08.2026 | **YOK** |
| QUICK | Quick Sigorta | 06.08.2026 | **YOK** |
| CITAS | Çitlekçi Mağazacılık Gıda | 18.08.2026 | **YOK** |
| KPEKS | Kapeks Kimya Sanayi | 21.08.2026 | **VAR** (sıfır değerli) |
| TKNKA | Teknika Plast Teknik Kalıp Plastik | 20.08.2026 | **YOK** |
| VEYAS | Türker Vangölü Enerji Yatırım | 20.08.2026 | **YOK** |
| INTET | İntetra Teknoloji ve Bilişim Hizmetleri | 01.09.2026 | **YOK** |
| BKRGY | Bakırcı Gayrimenkul Yatırım Ortaklığı | 02.09.2026 | **YOK** |
| NETGL | Net Global Endüstriyel Yatırımlar | 17.09.2026 | **VAR** (sıfır değerli) |

> **Not:** Haziran ayı içinde kaynaklarda işlem gören herhangi bir yeni hisseye rastlanmadı — ilk yeni hisseler Temmuz başında işlem görmeye başlamıştır. Bunun nedeni açığa satış kısıtlamasının 26 Haziran 2026'ya kadar sürmesi ve bu süreçte halka arz işlemlerinin yavaşlamış olması olabilir.

---

## VAR / YOK ÖZETİ

| Durum | Sayı | Semboller |
|-------|------|-----------|
| **VAR** | 2 | KPEKS, NETGL |
| **YOK** | 19 | BETAE, ORZAX, SOHOE, GOLDA, ISVEA, EKIM, SSAAT, SARAE, METEN, KARCL, MASFN, ALBTN, BEWEN, QUICK, CITAS, TKNKA, VEYAS, INTET, BKRGY |

---

## DETAYLI BULGULAR

### VAR Olanlar — Özel Not

**KPEKS (Kapeks Kimya Sanayi)** ve **NETGL (Net Global Endüstriyel Yatırımlar)** bist 500.md dosyasında mevcuttur, ancak her ikisi de tüm değerleri sıfır olarak kaydedilmiştir:

```
KPEKS
0	0	0	0	0	0	0	0	0	0

NETGL
0	0	0	0	0	0	0	0	0	0
```

Bu durum, söz konusu sembollerin listeye eklendiğini ancak piyasa verilerinin (fiyat, hacim, vb.) henüz güncellenmediğini göstermektedir.

---

### YOK Olanlar — Doğrulama Kaynakları

Aşağıdaki hisseler hem `bist 500.md` hem de `bistguncel.md` dosyalarında bulunmamaktadır:

| Sembol | Kaynak / Doğrulama |
|--------|-------------------|
| BETAE | `halka-arz-borsa-investigation.md` (proje veri dosyası) |
| ORZAX | `halka-arz-borsa-investigation.md` (proje veri dosyası) |
| SOHOE | TipRanks: "June–July 2026 public offering"; [bigpara.hurriyet.com.tr](https://bigpara.hurriyet.com.tr/borsa/hisse-fiyatlari/sohoe-detay/); bistguncel.md'de var |
| GOLDA | `halka-arz-borsa-investigation.md` (proje veri dosyası) |
| ISVEA | TipRanks: ["began trading on BIST Main Market on 10 July 2026"](https://www.tipranks.com/news/company-announcements/isvea-seramik-shares-debut-on-bist-without-need-for-price-support); bistguncel.md'de var |
| EKIM | `halka-arz-borsa-investigation.md` (proje veri dosyası); bistguncel.md'de var |
| SSAAT | TipRanks: [stabilizasyon alımları 16 Temmuz'dan itibaren](https://www.tipranks.com/news/company-announcements/saat-ve-saat-completes-post-ipo-price-stabilization-on-bist); bistguncel.md'de var |
| SARAE | `halka-arz-borsa-investigation.md`; bistguncel.md'de var |
| METEN | `halka-arz-borsa-investigation.md` |
| KARCL | `halka-arz-borsa-investigation.md` |
| MASFN | `halka-arz-borsa-investigation.md` |
| ALBTN | `halka-arz-borsa-investigation.md` (XHARZ listesinde: ALBTN ALBAYRAK HAZIR BETON) |
| BEWEN | `halka-arz-borsa-investigation.md` |
| QUICK | `halka-arz-borsa-investigation.md` |
| CITAS | `halka-arz-borsa-investigation.md` |
| TKNKA | `halka-arz-borsa-investigation.md` |
| VEYAS | `halka-arz-borsa-investigation.md` |
| INTET | `halka-arz-borsa-investigation.md` |
| BKRGY | `halka-arz-borsa-investigation.md`; [fintables.com/sirketler/BKRGY](https://fintables.com/sirketler/BKRGY) |

---

## ARAŞTIRMADA KULLANILAN KAYNAKLAR

1. **`d:\k\wink\teknik_bakis\bist 500.md`** — Mevcut hisse sembollerinin birincil kaynağı
2. **`d:\k\wink\teknik_bakis\bistguncel.md`** — Güncel fiyat verisi içeren ikincil liste
3. **`d:\k\wink\teknik_bakis\.agents\tasks\halka-arz-borsa-investigation.md`** — Projenin kendi IPO veri dosyası (23 trading statülü hisse)
4. **[XHARZ Hisseleri — uzmanpara.milliyet.com.tr](https://uzmanpara.milliyet.com.tr/endeks-detay/XHARZ/hisseleri/)** — BİST Halka Arz Endeksi bileşenleri
5. **[Borsa İstanbul – KPEKS haberi, aa.com.tr](https://www.aa.com.tr/tr/ekonomi/borsa-istanbulda-gong-kapeks-kimya-sanayi-as-icin-caldi/4033680)** — KPEKS tarihi doğrulaması
6. **[TipRanks – ISVEA debut haberi](https://www.tipranks.com/news/company-announcements/isvea-seramik-shares-debut-on-bist-without-need-for-price-support)** — ISVEA 10 Temmuz tarihi doğrulaması
7. **[TipRanks – SSAAT stabilizasyon](https://www.tipranks.com/news/company-announcements/saat-ve-saat-completes-post-ipo-price-stabilization-on-bist)** — SSAAT tarihi doğrulaması
8. **[TipRanks – SOHOE raporu](https://www.tipranks.com/news/company-announcements/soho-giyim-ve-enerji-releases-first-post-ipo-valuation-assumptions-report)** — SOHOE Haziran-Temmuz 2026 halka arz doğrulaması
9. **[TipRanks – NETGL (ad-hoc-news.de)](https://www.ad-hoc-news.de/boerse/news/nebenwerte/die-net-holding-aktie-legt-vor-dem-borsa-start-zu/70120094)** — NETGL 17 Eylül tarihi doğrulaması
10. **[fintables.com/sirketler/BKRGY](https://fintables.com/sirketler/BKRGY)** — BKRGY veri doğrulaması

---

## ÖNERİLER

1. **19 eksik hissenin tamamı bist 500.md'ye eklenmeli.** Bu hisseler Temmuz–Eylül 2026 arasında BİST'te işlem görmeye başlamış olup şu an bist 500.md dosyasında hiç bulunmuyorlar.

2. **KPEKS ve NETGL'nin sıfır verileri güncellenmeli.** Bu iki hisse dosyada yer alıyor ancak tüm piyasa verileri (fiyat, hacim vb.) sıfır olarak kaydedilmiş. Güncel fiyat verileriyle doldurulmaları gerekiyor.

3. **bistguncel.md ile senkronizasyon.** ISVEA, SOHOE, SSAAT, SARAE, EKIM, BETAE, ORZAX, GOLDA hisseleri `bistguncel.md` dosyasında mevcut ancak `bist 500.md`'de yok — bu iki dosya arasında tutarsızlık var. `bist 500.md` güncellenerek bu hisseler eklenmeli.

4. **Öncelik sırası (halka arz tarihine göre):** En eski tarihli olanlar önce eklenmeli: BETAE (01.07) → ORZAX (07.07) → SOHOE (08.07) → GOLDA (09.07) → ISVEA (10.07) → EKIM (10.07) → SSAAT (15.07) → SARAE (17.07) → sırasıyla devam.

---

*Rapor 5 Ekim 2026 tarihinde otomatik araştırma ajanı tarafından hazırlanmıştır.*  
*Kaynak notları: İçerik lisans kısıtlamaları nedeniyle yeniden ifade edilmiştir.*
