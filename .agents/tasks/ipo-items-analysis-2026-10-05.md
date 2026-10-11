# Firestore `ipo_items` Analiz Raporu
**Tarih:** 2026-10-05  
**Yöntem:** Firestore REST API (okuma-only) + `lib/services/bist_stocks.dart` lokal dosyası  
**Hiçbir kayıt değiştirilmedi, silinmedi, deploy yapılmadı.**

---

## SAYISAL RAPOR

| # | Soru | Cevap |
|---|------|-------|
| 1 | `status=upcoming` kaç kayıt? | **204** |
| 2 | `status=pendingListing` kaç kayıt? | **0** |
| 3 | `status=trading` kaç kayıt? | **0** |
| 4 | `symbol` dolu kaç kayıt? | **43** |
| 5 | `symbol` boş/null kaç kayıt? | **179** |
| 6 | `listingDate` dolu kaç kayıt? | **0** |
| 7 | `listingDate` boş/null kaç kayıt? | **222** |
| 8 | `listingDate` geçmiş tarihli kaç kayıt? | **0** (zaten hepsi boş) |
| 9 | `bist_stocks.dart`'ta sembolü bulunan kaç IPO? | **20** |
| 10 | `bist_stocks.dart`'ta bulunmayan kaç IPO? | **23** |
| 11 | `requestEnd` geçmiş + `listingDate` boş kaç kayıt? | **18** |

---

## DETAYLAR

### Gerçek Status Dağılımı (Firestore'daki ham değerler)

| status değeri | Kayıt sayısı |
|---------------|-------------|
| `upcoming` | 204 |
| `pending_listing` | 18 |
| `pendingListing` | 0 |
| `trading` | 0 |

> **Not:** Firestore'da `pending_listing` (alt çizgi) formatı kullanılıyor; `pendingListing` (camelCase) yok.  
> Dart kodu `IpoStatus.pendingListing` olarak bekliyor — bu format uyumsuzluğu önemli.

### Toplam kayıt sayısı

Firestore'dan çekilen: **222 kayıt** (bir sayfa, pagination gerekmedi).

### `bist_stocks` koleksiyonu

Firestore'daki `bist_stocks` koleksiyonu **boş** (`{}` response, 0 document).  
Sembollerin kaynağı Flutter kodu içindeki `lib/services/bist_stocks.dart` dosyasıdır (725 unique sembol).

Karşılaştırma `bist_stocks.dart` üzerinden yapıldı:

- **Dart'ta bulunan (20):** ALBTN, BKRGY, CITAS, EKIM, GOLDA, INTET, ISVEA, KARCL, KPEKS, MASFN, METEN, NETGL, ORZAX, QUICK, SARAE, SOHOE, SSAAT, TKNKA, VEYAS + 1 diğer
- **Dart'ta bulunmayan (23):** AKCEL, ALNUS, BLSMD, CAVDC, DNYVA, FIBAF, GLMND, HDMCB, KAYMT, KULE, KZLYI, MRBAS, NARFE, OTOSR, QYHOL, SMMAS, TEKYP, TEZKM, TIMUR, TMGSY, TVKDN, TVTV, YESOT

---

## SORU 11: `requestEnd` Geçmiş + `listingDate` Boş Olan 18 Kayıt

Tümünün Firestore'daki `status` değeri: **`pending_listing`**

| docId (= symbol) | requestEnd | status (Firestore) |
|------------------|-----------|-------------------|
| ALBTN | 2026-07-23 | pending_listing |
| BKRGY | 2026-08-26 | pending_listing |
| CITAS | 2026-08-12 | pending_listing |
| EKIM  | 2026-07-03 | pending_listing |
| GOLDA | 2026-07-02 | pending_listing |
| INTET | 2026-08-27 | pending_listing |
| ISVEA | 2026-07-03 | pending_listing |
| KARCL | 2026-07-24 | pending_listing |
| KPEKS | 2026-08-14 | pending_listing |
| MASFN | 2026-07-24 | pending_listing |
| METEN | 2026-07-22 | pending_listing |
| NETGL | 2026-09-11 | pending_listing |
| QUICK | 2026-07-31 | pending_listing |
| SARAE | 2026-07-10 | pending_listing |
| **SOHOE** | **2026-07-01** | **pending_listing** |
| SSAAT | 2026-07-08 | pending_listing |
| TKNKA | 2026-08-14 | pending_listing |
| VEYAS | 2026-08-14 | pending_listing |

Bu 18 kaydın **tamamı** `bist_stocks.dart`'ta mevcut.

---

## SORU 12: SOHOE ve ORZAX Mevcut Değerleri

### SOHOE
```
docId:       SOHOE
status:      pending_listing
symbol:      SOHOE
listingDate: "" (boş string)
requestEnd:  2026-07-01T12:00:00.000Z
name:        null
```

### ORZAX
```
docId:       ORZAX
status:      upcoming
symbol:      ORZAX
listingDate: "" (boş string)
requestEnd:  "" (boş string)
name:        null
```

**Her ikisi de** `bist_stocks.dart`'ta **mevcut** (borsa'da işlem görüyorlar).  
Ancak `listingDate` her ikisinde de **boş** — dolayısıyla `reconcileStaleIpoStatuses()` bu kayıtları `trading` yapamıyor.

---

## `reconciled: 0` Olmasının Ana Sebebi

**`reconciled: 0`'ın ana sebebi:** 222 kayıdın tamamında `listingDate` alanı boş/null, Firestore `bist_stocks` koleksiyonu ise sıfır kayıt içeriyor — bu iki koşul nedeniyle `reconcileStaleIpoStatuses()` içindeki "trading" kuralları hiç tetiklenemiyor; 18 `pending_listing` kaydı zaten `pending_listing` statüsünde olduğu için `reconcile` sayacı artmıyor.

---

## Detaylı Teknik Analiz

### `reconcileStaleIpoStatuses()` nasıl çalışır?

`functions/index.js` satır 997'deki fonksiyon üç kural uygular:

1. **BIST sembolü → trading:** `d.symbol && bistSymbols.has(d.symbol)` → Firestore `bist_stocks` koleksiyonu boş olduğundan `bistSymbols` Set'i boş; kural hiç tetiklenmiyor.

2. **listingDate geçtiyse → trading:** `d.listingDate` dolu olmalı → tüm 222 kayıtta `listingDate` boş string veya null; kural hiç tetiklenmiyor.

3. **requestEnd geçtiyse + listingDate yoksa → pending_listing:** Bu kural 18 kayıt için tetikleniyor, ancak bu kayıtlar Firestore'da **zaten** `pending_listing` statüsünde; `d.status !== 'pending_listing'` koşulu geçilemiyor → `stale[]` dizisine eklenmiyorlar.

Sonuç: `stale.length === 0` → `return 0`.

### Neden `listingDate` hep boş?

`ipo_feed.json`'daki `items: []` boş; HalkArz scraper borsaya geçen hisseleri listeden kaldırıyor. `toIso(null)` → `""` (boş string) Firestore'a yazılıyor.

### Neden `bist_stocks` Firestore koleksiyonu boş?

`loadBistSymbols()` (`runBist100Sync`) yalnızca BIST 100 güncellemesini işliyor ve Firestore `bist_stocks` koleksiyonuna yazmıyor. Sembollerin gerçek kaynağı `bist_stocks.dart` dosyası (Flutter kodu, server-side değil).

---

## Öneriler (Uygulama Yapılmadı)

1. **18 `pending_listing` kaydının `listingDate`'i elle doldurulmalı** — özellikle SOHOE (requestEnd: 2026-07-01) ve diğer 17 hisse.
2. **ORZAX'ın `requestEnd`'i** de boş; manuel olarak belirlenmeli.
3. **`reconcileStaleIpoStatuses()`** fonksiyonu için alternatif: `bist_stocks.dart` sembol listesini (725 sembol) sunucu tarafından da kullanmak yerine, Firestore `ipo_items` sorgusu `requestEnd < now && listingDate == ""` ile doğrudan `pending_listing` → `trading` geçişini `bist_stocks.dart`'a bakarak yapabilir.
4. **`name` alanı 222 kayıdın tamamında `null`** — Firestore dokümanlarında `name` field'ı yok; Flutter'da `companyName` kullanılıyor.

---

## Kanıtlar

- Veri kaynağı: Firestore REST API `GET /projects/teknik-bakis/databases/(default)/documents/ipo_items?pageSize=300`
- BIST karşılaştırması: `lib/services/bist_stocks.dart` (725 unique sembol, `re.findall(r"'symbol'\s*:\s*'([A-Z0-9]+)'"`)
- `reconcileStaleIpoStatuses()` kaynak: `functions/index.js` satır 997-1045
- Script: `.agents/tasks/analyze_ipo3.py`, `.agents/tasks/full_bist_crossref.py` (geçici, silinecek)
