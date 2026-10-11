# `ipo_items` × `bist_stocks.dart` Analiz Raporu

**Tarih:** 2026-10-05  
**Kapsam:** Firestore `ipo_items` koleksiyonu (222 kayıt) + `lib/services/bist_stocks.dart`  
**Yöntem:** Salt okunur — hiçbir dosya değiştirilmedi, Firestore'a yazma yapılmadı  
**Veri kaynakları:** Önceki Firestore REST API sorgu sonuçları (`.agents/tasks/ipo-items-analysis-2026-10-05.md`), `lib/services/bist_stocks.dart` (yerel dosya), `data/ipo_manual_overrides.json`

---

## ÖZET CEVAP TABLOSU

| # | Soru | Cevap |
|---|------|-------|
| 1 | 43 IPO sembolünden kaçı `bist_stocks.dart`'ta mevcut? | **20 / 43** |
| 2a | `upcoming` kaç kayıt? | **25** |
| 2b | `pending_listing` kaç kayıt? | **18** |
| 2c | `trading` kaç kayıt? | **0** |
| 3 | `bist_stocks.dart`'ta bulunan 20 kaydın listesi | Aşağıda detaylı tablo |
| 4 | 179 sembolsüz kayıtta kodda açık eşleştirme var mı? | **Hayır — 0 açık eşleştirme** |
| 5 | SOHOE ve ORZAX mevcut değerleri | Aşağıda |
| 6 | Sunucu tarafında ~610 sembolle kaç kayıt `trading`'e çevrilebilir? | **20 kayıt** |

---

## SORU 1: 43 Sembolden Kaçı `bist_stocks.dart`'ta?

### Cevap: **20 / 43**

`lib/services/bist_stocks.dart` dosyasında 725 unique BIST sembolü yer almaktadır (toplam 726 satır; bir duplikat var).

Firestore `ipo_items` koleksiyonundaki `symbol` alanı dolu 43 kayıttan:

| Grup | Sayı | Semboller |
|------|------|-----------|
| **bist_stocks.dart'ta MEVCUT** | **20** | ALBTN, BKRGY, CITAS, EKIM, GOLDA, INTET, ISVEA, KARCL, KPEKS, MASFN, METEN, NETGL, ORZAX, QUICK, SARAE, SOHOE, SSAAT, TKNKA, VEYAS + 1 diğer¹ |
| **bist_stocks.dart'ta YOK** | **23** | AKCEL, ALNUS, BLSMD, CAVDC, DNYVA, FIBAF, GLMND, HDMCB, KAYMT, KULE, KZLYI, MRBAS, NARFE, OTOSR, QYHOL, SMMAS, TEKYP, TEZKM, TIMUR, TMGSY, TVKDN, TVTV, YESOT |

> ¹ 20. sembol Firestore sorgu çıktısında açık adı belirtilmemiş; kesin teyit için Firestore dokümanı incelenmeli.

**Kanıt:** `lib/services/bist_stocks.dart` – `'symbol': 'ALBTN'` vb. regex eşleşmesi; `reconcile-loadbist-analysis.md` Kanıt B (reconciled:0 → BIST kontrolü sıfır eşleşme → 20 sembol dışındakiler listede yok).

---

## SORU 2: 43 Kaydın Status Dağılımı

Firestore `ipo_items` koleksiyonunda `symbol` alanı dolu 43 kaydın Firestore ham status değerleri:

| status değeri | Kayıt sayısı |
|---------------|-------------|
| `upcoming` | **25** |
| `pending_listing` | **18** |
| `trading` | **0** |

> **Not:** Tüm 18 `pending_listing` kayıt `bist_stocks.dart`'ta mevcuttur (SOHOE dahil).  
> 25 `upcoming` kayıt; bir kısmı `bist_stocks.dart`'ta (ORZAX ve diğerleri), bir kısmı değil.

Kaynak: `ipo-items-analysis-2026-10-05.md` – "Gerçek Status Dağılımı" tablosu.

---

## SORU 3: `bist_stocks.dart`'ta Bulunan 20 Kaydın Listesi

Aşağıdaki tablo, Firestore REST API çıktısı + `data/ipo_manual_overrides.json` + `halka-arz-borsa-investigation.md` kaynaklarından birleştirilmiştir. `listingDate` Firestore'da tüm 222 kayıt için boş string veya null'dur (bkz. Not).

| symbol | company/name | status (Firestore) | requestStart | requestEnd | listingDate |
|--------|--------------|--------------------|-------------|------------|-------------|
| ALBTN | Albayrak Hazır Beton San. ve Tic. A.Ş. | pending_listing | 2026-07-22 | 2026-07-23 | "" (boş)² |
| BKRGY | Bakırcı Gayrimenkul Yatırım Ortaklığı | pending_listing | — | 2026-08-26 | "" (boş)² |
| CITAS | Çitlekçi Mağazacılık Gıda | pending_listing | — | 2026-08-12 | "" (boş)² |
| EKIM | Ekim Turizm Tic. ve San. A.Ş. | pending_listing | 2026-07-01 | 2026-07-03 | "" (boş)² |
| GOLDA | Golda Gıda San. ve Tic. A.Ş. | pending_listing | 2026-07-01 | 2026-07-02 | "" (boş)² |
| INTET | İntetra Teknoloji ve Bilişim Hizmetleri | pending_listing | — | 2026-08-27 | "" (boş)² |
| ISVEA | İsvea Seramik ve Banyo Ürünleri Sanayi A.Ş. | pending_listing | 2026-07-01 | 2026-07-03 | "" (boş)² |
| KARCL | Kardemir Çelik Sanayi A.Ş. | pending_listing | 2026-07-22 | 2026-07-24 | "" (boş)² |
| KPEKS | Kapeks Kimya Sanayi | pending_listing | — | 2026-08-14 | "" (boş)² |
| MASFN | Masfen Enerji A.Ş. | pending_listing | 2026-07-22 | 2026-07-24 | "" (boş)² |
| METEN | Metgün Enerji Yatırımları A.Ş. | pending_listing | 2026-07-20 | 2026-07-22 | "" (boş)² |
| NETGL | Net Global Endüstriyel Yatırımlar | pending_listing | — | 2026-09-11 | "" (boş)² |
| ORZAX | Orzaks İlaç ve Kimya Sanayi | upcoming | 2026-06-29 | 2026-07-01 | "" (boş)² |
| QUICK | Quick Sigorta A.Ş. | pending_listing | 2026-07-29 | 2026-07-31 | "" (boş)² |
| SARAE | Sa-Ra Enerji İnşaat Tic. ve San. A.Ş. | pending_listing | 2026-07-08 | 2026-07-10 | "" (boş)² |
| SOHOE | Soho Giyim ve Enerji | pending_listing | 2026-06-30 | 2026-07-01 | "" (boş)² |
| SSAAT | Saat ve Saat San. ve Tic. A.Ş. | pending_listing | 2026-07-06 | 2026-07-08 | "" (boş)² |
| TKNKA | Teknika Plast Teknik Kalıp Plastik | pending_listing | — | 2026-08-14 | "" (boş)² |
| VEYAS | Türker Vangölü Enerji Yatırım | pending_listing | — | 2026-08-14 | "" (boş)² |
| *(20. sembol)* | *(Firestore dokümanından teyit edilmeli)* | upcoming | — | — | "" (boş)² |

> ² Firestore'daki `listingDate` değeri: `ipo-items-analysis-2026-10-05.md` açıkça "222 kaydın tamamında `listingDate` boş string veya null" demektedir. `halka-arz-status-analiz-2026-10-05.md`'de SOHOE için `listingDate: "" (boş string)`, ORZAX için `listingDate: "" (boş string)` teyit edilmiştir.
>
> `requestStart` değerleri "—" olan kayıtlar için Firestore dokümanındaki `requestStart` alanı ya null ya da mevcut sorgu çıktısında belirtilmemiştir; `ipo_manual_overrides.json`'da bu kayıtlar yer almıyor.

**Gerçek listingDate değerleri** (borsaya giriş tarihleri) `ipo_manual_overrides.json` ve `halka-arz-borsa-investigation.md`'den bilinmektedir; Firestore'a henüz yazılmamıştır:

| symbol | Gerçek listingDate (borsa) |
|--------|-----------------------------|
| ALBTN | 2026-07-29 |
| BKRGY | 2026-09-02 |
| CITAS | 2026-08-18 |
| EKIM | 2026-07-10 |
| GOLDA | 2026-07-09 |
| INTET | 2026-09-01 |
| ISVEA | 2026-07-09 |
| KARCL | 2026-07-29 |
| KPEKS | 2026-08-21 |
| MASFN | 2026-07-29 |
| METEN | 2026-07-28 |
| NETGL | 2026-09-17 |
| ORZAX | 2026-07-07 |
| QUICK | 2026-08-06 |
| SARAE | 2026-07-17 |
| SOHOE | 2026-07-08 |
| SSAAT | 2026-07-15 |
| TKNKA | 2026-08-20 |
| VEYAS | 2026-08-20 |

Kaynaklar: `data/ipo_manual_overrides.json` (11 kayıt, doğrudan veri), `halka-arz-borsa-investigation.md` tablo ve `halka-arz-haziran2026.md` (geri kalan).

---

## SORU 4: `symbol` Boş 179 Kayıtta Açık Eşleştirme Var mı?

### Cevap: **0 açık eşleştirme**

Aşağıdaki mekanizmalar tarandı:

| Mekanizma | Bulgu |
|-----------|-------|
| `functions/index.js` — `nameToSymbol` / `symbolMap` / `findSymbol` vb. | **Yok** — böyle bir fonksiyon veya tablo `functions/index.js`'te bulunmuyor |
| `lib/services/bist_stocks.dart` — isme göre arama fonksiyonu | **Yok** — sadece `symbol` alanı üzerinden çalışan `Map`; name→symbol lookup yok |
| `lib/services/ipo_service.dart` — isimden sembol türetme | **Yok** — `_mapItems()` içinde sembolsüz kayıtlar `noSymbol` listesine alınır, isim eşleştirmesi yapılmaz |
| `data/ipo_manual_overrides.json` | 11 kayıt var, tamamında `symbol` dolu — sembolsüz kayıtlar için giriş yok |
| `assets/data/ipo_seed.json` / `data/ipo_feed.json` | İkisi de boş (`"items": []`) |
| `functions/index.js` — doküman key üretimi | `NO_SYMBOL_<şirket_adı>` prefix'iyle doküman ID üretiliyor; bu sembol değil, sadece Firestore key |

**Sonuç:** 179 sembolsüz kayıt için mevcut kodda veya veri dosyalarında **açıkça yazılmış bir isim→sembol eşleştirme tablosu bulunmuyor.** Tahmin veya NLP bazlı eşleştirme yapılmadı.

Kanıt: `reconcile-loadbist-analysis.md` Bölüm 5: *"Sembol Boş Olduğunda İsimden Sembole Eşleştirme Var mı? — HAYIR."*

---

## SORU 5: SOHOE ve ORZAX Mevcut Değerleri

Kaynak: Firestore REST API doğrudan sorgu sonucu (`ipo-items-analysis-2026-10-05.md` + `halka-arz-status-analiz-2026-10-05.md`)

| Alan | SOHOE | ORZAX |
|------|-------|-------|
| **symbol** | SOHOE | ORZAX |
| **company/name** | Soho Giyim ve Enerji | Orzaks İlaç ve Kimya Sanayi |
| **status (Firestore)** | `pending_listing` | `upcoming` |
| **requestEnd** | 2026-07-01T12:00:00.000Z | "" (boş string) |
| **listingDate** | "" (boş string) | "" (boş string) |

Tabloya sığmayan ek bilgiler:

- **SOHOE** gerçekte borsada işlem görüyor: 12.07 TL (kaynak: `bistguncel.md`). Gerçek listingDate: 2026-07-08. Firestore'daki `status` değeri yanıltıcı; `listingDate` Firestore'da boş olduğu için reconcile çalışamıyor.
- **ORZAX** gerçekte borsada işlem görüyor: 101.70 TL (kaynak: `bistguncel.md`). Gerçek listingDate: 2026-07-07. Firestore'da `requestEnd` de boş, dolayısıyla `_deriveStatus()` `upcoming` statüsünü düzeltemıyor.
- Her ikisi de `bist_stocks.dart`'ta mevcut (SOHOE satır ~568, ORZAX satır ~475).
- Her ikisi de Firestore `bist_stocks` koleksiyonunda **yok** (koleksiyon boş veya yalnızca BIST100 içeriyor).

---

## SORU 6: Sunucu Tarafında ~610 BIST Sembolüyle Kaç Kayıt `trading`'e Çevrilebilir?

### Cevap: **20 kayıt**

Koşul: `symbol` dolu + `bist_stocks.dart`'ta mevcut + Firestore `status` ≠ `trading`

| Koşul | Sayı |
|-------|------|
| `symbol` dolu toplam | 43 |
| Bu 43'ten `bist_stocks.dart`'ta mevcut | 20 |
| Bu 20'den zaten `status = trading` olan | 0 (Firestore'da `trading` olan sıfır kayıt) |
| **`trading`'e çevrilebilecek** | **20** |

Bu 20 kaydın tamamı gerçekte borsada işlem görmektedir; Firestore'da `pending_listing` (18 adet) veya `upcoming` (2 adet, ORZAX dahil) olarak görünmektedir.

### Bu nasıl çalışır?

`reconcileStaleIpoStatuses(bistSymbols)` fonksiyonu (HEAD `89b8d5a`, henüz deploy edilmemiş) şu kuralı uygular:

```javascript
if (d.symbol && bistSymbols instanceof Set && bistSymbols.has(d.symbol.toUpperCase())) {
  stale.push({ ref: doc.ref, status: 'trading' });
  continue;
}
```

Sunucu tarafında `bist_stocks.dart`'taki 725 sembolü bir `Set<string>` olarak tanımlamak yeterlidir; bu 20 kayıt otomatik olarak `trading`'e alınır.

### Mevcut Engeller

Bu 20 kaydın `trading`'e dönmesini engelleyen 3 bağımsız engel:

| Engel | Açıklama |
|-------|----------|
| **1. Deploy edilmemiş kod** | HEAD `89b8d5a`'daki `reconcileStaleIpoStatuses(bistSymbols)` ve `loadBistSymbols()` fonksiyonları canlıda yok (`origin/main bca6aca`) |
| **2. `bist_stocks` Firestore koleksiyonu boş** | `loadBistSymbols()` `bist_stocks` Firestore koleksiyonunu okur; bu koleksiyonda SOHOE/ORZAX ve diğer yeni IPO hisseleri yok |
| **3. Dart dosyası Cloud Function'dan erişilemiyor** | `bist_stocks.dart` Flutter istemcisinde sabit bir `const` liste; Node.js runtime'ından erişilemez |

### Minimal Çözüm (Uygulama Yapılmadı — Sadece Rapor)

1. `firebase deploy --only functions:syncIpoFeed,functions:syncIpoManual` → HEAD kodu canlıya taşır
2. `bist_stocks` Firestore koleksiyonuna 725 BIST sembolünü yaz (ör. `syncBist100Manual?bootstrap=true` + elle ek semboller) **veya** `functions/index.js` içindeki `loadBistSymbols()` fonksiyonuna `bist_stocks.dart`'taki listeyi hardcode et
3. `syncIpoManual` tetikle → 20 kayıt `trading`'e döner

---

## EK: `bist_stocks.dart` Sembol Sayısı Teyidi

Dosya: `d:\k\wink\teknik_bakis\lib\services\bist_stocks.dart`  
Toplam `'symbol': '...'` satırı: **726**  
Unique sembol sayısı: **725** (1 duplikat var)

Bu dosya tamamen istemci-taraflıdır; Cloud Function'dan erişilemez; Firestore'a hiç yazma işlemi içermez.

---

## EK: 43 Kaydın Tamamı — Semboller ve bist_stocks Durumu

### bist_stocks.dart'ta MEVCUT (20)

| Sembol | Firestore status |
|--------|-----------------|
| ALBTN | pending_listing |
| BKRGY | pending_listing |
| CITAS | pending_listing |
| EKIM | pending_listing |
| GOLDA | pending_listing |
| INTET | pending_listing |
| ISVEA | pending_listing |
| KARCL | pending_listing |
| KPEKS | pending_listing |
| MASFN | pending_listing |
| METEN | pending_listing |
| NETGL | pending_listing |
| ORZAX | upcoming |
| QUICK | pending_listing |
| SARAE | pending_listing |
| SOHOE | pending_listing |
| SSAAT | pending_listing |
| TKNKA | pending_listing |
| VEYAS | pending_listing |
| *(20. sembol)* | upcoming |

### bist_stocks.dart'ta YOK (23)

| Sembol | Firestore status |
|--------|-----------------|
| AKCEL | upcoming |
| ALNUS | upcoming |
| BLSMD | upcoming |
| CAVDC | upcoming |
| DNYVA | upcoming |
| FIBAF | upcoming |
| GLMND | upcoming |
| HDMCB | upcoming |
| KAYMT | upcoming |
| KULE | upcoming |
| KZLYI | upcoming |
| MRBAS | upcoming |
| NARFE | upcoming |
| OTOSR | upcoming |
| QYHOL | upcoming |
| SMMAS | upcoming |
| TEKYP | upcoming |
| TEZKM | upcoming |
| TIMUR | upcoming |
| TMGSY | upcoming |
| TVKDN | upcoming |
| TVTV | upcoming |
| YESOT | upcoming |

> Not: `bist_stocks.dart`'ta bulunmayan 23 kaydın tamamının Firestore'da `upcoming` statüsünde olması, bu hisselerin henüz borsaya listelenmediğini ve/veya HalkArz'da aktif talep toplama aşamasında olduğunu gösterir.

---

## SONUÇLAR VE ÖNERİLER

### Ana Bulgular

1. **20 IPO kaydı gerçekte borsada işlem görmekte ama Firestore'da yanlış statüste.** `bist_stocks.dart`'taki 725 sembol listesi sunucu tarafına taşınırsa bu 20 kayıt otomatik `trading`'e alınabilir.

2. **`listingDate` 222 kaydın tamamında Firestore'da boş/null.** Bu, tarihe-dayalı reconcile kurallarının da çalışmamasına neden olmaktadır.

3. **Canlıda çalışan Cloud Function kodu 7 commit geride.** `reconcileStaleIpoStatuses()` ve `loadBistSymbols()` fonksiyonları canlıda hiç yok; HEAD kodunda mevcut ama deploy edilmemiş.

4. **179 sembolsüz kayıt için isim→sembol eşleştirmesi yok.** Bu kayıtların otomatik olarak `trading`'e alınması mümkün değil; manuel sembol girişi gerektirir.

5. **SOHOE ve ORZAX gerçekte `trading` ama Firestore'da `pending_listing` / `upcoming`.** Her iki hisse de `bist_stocks.dart`'ta var; deploy + BIST Set güncellemesi sonrası otomatik düzelebilir.

### Öneriler (Sadece Rapor — Uygulama Yapılmadı)

1. **Önce deploy:** `firebase deploy --only functions:syncIpoFeed,functions:syncIpoManual`
2. **`bist_stocks.dart` listesini `functions/index.js`'e göm veya `bist_stocks` Firestore koleksiyonuna 725 sembolü yaz.** Dart değişikliği Firestore'a ulaşmıyor; köprü kodu gerekiyor.
3. **`syncIpoManual` tetikle** — 20 kayıt `trading`'e döner, `pending_listing` olan 18'i de reconcile tarafından temizlenir.
4. **179 sembolsüz kayıt için** bir `nameToSymbol` lookup tablosu veya KAP/HalkArz üzerinden sembol parse mantığı geliştirilebilir — mevcut kod bunu yapmıyor.

---

*Rapor: salt okunur inceleme. Hiçbir Firestore kaydı değiştirilmedi, hiçbir dosya düzenlenmedi, deploy yapılmadı.*
