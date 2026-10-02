# BIST100 Backend Sistemi — İmplementasyon Raporu

**Tarih:** 2 Ekim 2026  
**Durum:** ✅ Implementasyon tamamlandı — deploy bekliyor

---

## A) Değiştirilen Dosyalar

| Dosya | Değişiklik |
|---|---|
| `functions/index.js` | Sonuna 5 yeni fonksiyon + 2 yeni export eklendi |
| `firestore.rules` | `bist_stocks` ve `bist_index_meta` kuralları zaten mevcuttu (değiştirilmedi) |

**Flutter / Dart dosyalarına DOKUNULMADI.** `bist100_service.dart` ve `scanner_screen.dart` zaten `Bist100Service.symbols` ile Firestore'dan okuyor — ekstra değişiklik gerekmez.

---

## B) Eklenen Cloud Functions

### `exports.syncBist100Index`
- **Tip:** Scheduled Function
- **Zamanlama:** Her Pazartesi 05:00 UTC (08:00 TR)
- **Region:** europe-west1
- **Memory:** 512MiB / Timeout: 300s
- **Davranış:** `runBist100Sync({ dryRun: false })` çağırır

### `exports.syncBist100Manual`
- **Tip:** HTTP Function (GET/POST)
- **Auth:** `x-admin-secret` header veya `?secret=` query param (ADMIN_SECRET)
- **Region:** europe-west1
- **Desteklenen modlar:**
  - `?dryRun=true` → Parse + validation yapar, Firestore'a yazmaz
  - `?bootstrap=true` → İlk kurulum: Firestore boşsa Ekim 2026 listesini yazar
  - Default → Tam sync (duyuru bul → parse → validate → yaz)

---

## C) Scheduler

| Fonksiyon | Schedule | Açıklama |
|---|---|---|
| `syncBist100Index` | `0 5 * * 1` (Her Pazartesi 05:00 UTC) | Haftalık otomatik BIST100 sync |

---

## D) Firestore Schema

### `bist_index_meta/bist100`

```json
{
  "symbols":           ["AEFES", "AGHOL", ...],  // 100 sembol, sorted
  "updatedAt":         Timestamp,
  "periodStart":       "October 1, 2026",
  "periodEnd":         "December 31, 2026",
  "source":            "Borsa Istanbul",
  "announcementId":    "15598",
  "announcementUrl":   "https://www.borsaistanbul.com/en/announcement/15598/...",
  "announcementTitle": "Bist Stock Indices Periodic Review",
  "added":             ["AGHOL", "AHGAZ", ...],  // delta: eklenenler
  "removed":           ["BALSU", "BSOKE", ...],  // delta: çıkarılanlar
  "alternates":        ["KLGYO", "RYGYO", ...],  // yedekler (symbols'e dahil değil)
  "revision":          "2026-Q4"
}
```

### `bist_stocks/{SYMBOL}` (güncellenen alanlar)

```json
{
  "bist100Member": true    // BIST100'e girenler için
  "bist100Member": false   // BIST100'den çıkanlar için
  // "active" alanına ASLA dokunulmaz
}
```

---

## E) Firestore Rules

`firestore.rules` dosyasında zaten mevcuttu:

```javascript
match /bist_stocks/{symbol} {
  allow read:  if true;
  allow write: if false;  // sadece Admin SDK (Cloud Function)
}

match /bist_index_meta/{docId} {
  allow read:  if true;
  allow write: if false;  // sadece Admin SDK (Cloud Function)
}
```

---

## F) Flutter BIST100 Merkezi Servis Durumu

`lib/services/bist100_service.dart` — **MEVCUT, DEĞİŞTİRİLMEDİ**

Servis zaten doğru çalışıyor:
1. Uygulama açılışında `Bist100Service.init()` çağrılır (await edilmez)
2. Hive cache'den varsa eski veriyi yükler (senkron — offline çalışma)
3. Arka planda Firestore `bist_index_meta/bist100` dokümanını çeker
4. Geçerliyse (≥50 sembol) `_liveSymbols` ve `kBist100SymbolsLive` güncellenir
5. Firestore erişilemiyorsa → Hive cache → `kBist100Symbols` hardcoded fallback

Öncelik zinciri:
```
Firestore (taze) → Hive cache (offline) → kBist100Symbols (hardcoded)
```

---

## G) BIST100 Kullanan Ekranlar

| Ekran | Dosya | BIST100 Kullanım Yöntemi |
|---|---|---|
| Tarama | `scanner_screen.dart` | `Bist100Service.symbols` (doğru ✓) |
| Home | `home_screen.dart` | XU100.IS endeks fiyatı (sembol listesi değil) |
| TradingView | `tradingview_chart_screen.dart` | XU100.IS endeks fiyatı (sembol listesi değil) |

`scanner_screen.dart` içinde:
```dart
static List<String> get _bist100Symbols => Bist100Service.symbols;
```
→ Firestore güncellendiğinde bir sonraki taramada otomatik yeni liste kullanılır.

---

## H) Cache / Fallback Davranışı

| Durum | Davranış |
|---|---|
| Firestore erişilebilir, ≥50 sembol | Firestore listesi kullanılır, Hive'a kaydedilir |
| Firestore erişilemez, Hive dolu | Hive cache kullanılır (TTL yok, son başarılı veri) |
| Firestore erişilemez, Hive boş | `kBist100Symbols` hardcoded fallback |
| Firestore boş liste döner | Güncelleme yapılmaz, önceki cache korunur |
| Firestore <50 sembol döner | Güncelleme yapılmaz, önceki cache korunur |

**ÖNEMLİ:** Firestore'dan gelen liste `kBist100Symbols` ile BİRLEŞTİRİLMEZ. Firestore başarılıysa sadece Firestore listesi kullanılır.

---

## I) Validation Kontrolleri

Firestore'a yazmadan önce `validateBist100Update()` şu kontrolleri yapar:

1. ✅ BIST 100 bölümü HTML'de bulundu mu?
2. ✅ `added` listesi parse edildi mi (array)?
3. ✅ `removed` listesi parse edildi mi (array)?
4. ✅ Yeni sembol listesi boş değil mi?
5. ✅ Yeni liste tam 100 sembol mü? (`SYMBOL_COUNT_NOT_100`)
6. ✅ Her sembol geçerli format `[A-Z]{2,6}` (`INVALID_SYMBOL_FORMAT`)
7. ✅ `added` ve `removed` kesişiyor mu? (`ADDED_REMOVED_OVERLAP`)
8. ✅ Toplam değişim 40'tan fazla mı? (`UNEXPECTED_LARGE_DIFF`)
9. ⚠️  Mevcut Firestore listesi 100 değilse: uyarı loglanır ama engellenmez

**Herhangi bir kontrol başarısız → Firestore'a HİÇBİR ŞEYE YAZILMAZ**

---

## J) Deploy Sırası ve Komutlar

### 1. Syntax Kontrolü (tamamlandı ✓)
```
node --check functions/index.js
→ Exit: 0
```

### 2. Functions Deploy
```bash
# Sadece yeni fonksiyonları deploy et (mevcut fonksiyonlara dokunmaz):
firebase deploy --only functions:syncBist100Index,functions:syncBist100Manual

# Veya tüm functions:
firebase deploy --only functions
```

### 3. Firestore Rules Deploy (zaten güncel, ama deploy edilmemişse)
```bash
firebase deploy --only firestore:rules
```

### 4. Bootstrap (İlk Kurulum)
```bash
# Önce dry run ile kontrol:
curl "https://europe-west1-<PROJECT_ID>.cloudfunctions.net/syncBist100Manual?bootstrap=true&dryRun=true&secret=<ADMIN_SECRET>"

# Dry run başarılıysa gerçek yazma:
curl "https://europe-west1-<PROJECT_ID>.cloudfunctions.net/syncBist100Manual?bootstrap=true&secret=<ADMIN_SECRET>"
```

### 5. Sonraki Dönem Sync Testi (Dry Run)
```bash
curl "https://europe-west1-<PROJECT_ID>.cloudfunctions.net/syncBist100Manual?dryRun=true&secret=<ADMIN_SECRET>"
```

---

## K) Önemli Notlar

### kBist100Symbols Listesi 102 Sembol
`lib/services/bist_stocks.dart` içindeki `kBist100Symbols` sabit listesi 102 sembol içeriyor (hata). Bu liste sadece fallback olarak kullanılıyor — Firestore başarılıysa asla kullanılmaz. Ayrı bir görevde düzeltilmeli.

### Bootstrap Listesi
`syncBist100Manual?bootstrap=true` içinde Ekim 2026 dönemi için hardcoded 100 sembolik liste var. Bu liste Borsa İstanbul resmi duyurusu 15598'e dayanmaktadır. Bootstrap başarılı olduktan sonra sistem otomatik olarak duyuru delta'larını takip edecek.

### Parse Stratejisi
Parser HTML `<tr>/<td>` taglarını işliyor (tag temizlemeden önce). Her `<tr>` satırında 3 `<td>` hücresi: `[added | removed | alternates]`. Hücre formatı: `NumeraSEMBOLŞirketAdı` (bitişik) veya `Numera SEMBOL Şirket Adı` (boşluklu). İkisi de destekleniyor.

---

## L) Log Referansı

| Log | Anlamı |
|---|---|
| `BIST100_SYNC_STARTED` | Fonksiyon başladı |
| `BIST100_ANNOUNCEMENT_FOUND: {id} - {title}` | Duyuru listesinde bulundu |
| `BIST100_NO_CHANGE: announcement {id} already processed` | Yeni duyuru yok, erken çıkış |
| `BIST100_FETCH_ERROR: ...` | HTTP veya parse hatası |
| `BIST100_PARSE_SUCCESS: added=N, removed=N` | HTML parse başarılı |
| `BIST100_VALIDATION_FAILED: {reason}` | Validation başarısız — Firestore'a yazılmadı |
| `BIST100_UPDATED: N symbols, added=[...], removed=[...]` | Başarıyla güncellendi |
| `BIST100_BOOTSTRAP_COMPLETE: N symbols written` | Bootstrap tamamlandı |
