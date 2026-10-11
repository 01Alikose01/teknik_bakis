# KAP Sync Firestore Durum Raporu

**Tarih:** 5 Ekim 2026  
**Proje:** teknik-bakis (Firebase)  
**Yöntem:** Firestore REST API + depolanan OAuth token (okuma-only, hiçbir değişiklik yapılmadı)

---

## ÖZet Cevap

**Kategori: E — Başka bir hata**

Hata mesajı: **`Invalid character in header content ["Authorization"]`**

Bu hata HTTP 401/403 **değildir**. API'ye ulaşılıyor, kimlik doğrulaması sırasında değil; HTTP isteği oluşturulurken **header değerinde geçersiz karakter** bulunuyor. Büyük ihtimalle `KAP_TOKEN` secret değeri boşluk, newline (`\n`) veya başka bir kontrol karakteri içeriyor.

---

## 1. `kap_sync_logs` — En Son Kayıt

**En son kayıt (finished_at'a göre):**

| Alan | Değer |
|------|-------|
| `id` | `1Simv3FD8vfTz74gwHob` |
| `status` | **`failed`** |
| `error_message` | **`Invalid character in header content ["Authorization"]`** |
| `trigger` | `scheduled` |
| `started_at` | `2026-10-05T20:15:03.102Z` (UTC) = 5 Ekim 23:15 TR |
| `finished_at` | `2026-10-05T20:17:33.238Z` (UTC) = 5 Ekim 23:17 TR |
| `records_added` | `0` |
| `records_updated` | `0` |
| `createdAt` | *(bu alan mevcut değil — döküman createTime: 2026-10-05T20:17:33.266316Z)* |
| `details` | *(bu alan mevcut değil)* |

> **Not:** Koleksiyon boş görünüyordu çünkü ilk sorgumda `createdAt` alanına göre sıralama yaptık — bu alan kayıtlarda yok. Asıl alan isimleri `started_at` ve `finished_at`.

**Pattern:** Son 5 kontrol edilen log da dahil olmak üzere **her kayıt** aynı hatayla `failed`. Koleksiyonda Eylül başından bu yana aynı hata tekrarlanıyor.

---

## 2. `meta/kap` Dökümanı

| Alan | Değer |
|------|-------|
| `lastSyncStatus` | **`failed`** |
| `lastSyncAt` | *(bu alan mevcut değil)* |
| `lastError` | *(bu alan mevcut değil)* |

> **Not:** Gerçek alan ismi `lastError` değil, **`lastSyncError`**:

| Gerçek Alan | Değer |
|-------------|-------|
| `lastSyncStatus` | `failed` |
| `lastSyncError` | **`Invalid character in header content ["Authorization"]`** |

`lastSyncAt`, `lastSuccessfulSync` alanları mevcut değil — demek ki son başarılı bir sync gerçekleşmedi.

---

## 3. Firebase Functions Logs (syncMembers)

Firebase Functions loglarına doğrudan CLI erişimi bu ortamda kısıtlı (PS execution policy). Ancak Firestore verisinden hata akışı tamamen nettir:

Koddan (`functions/index.js`, `runKapSync` fonksiyonu):
```javascript
async function runKapSync(apiKey, token, trigger = 'scheduled') {
  // ...
  if (trigger === 'scheduled' || trigger === 'manual') {
    await withRetry(() => syncMembers(apiKey, token), 'syncMembers');
  }
  // ...
}
```

`syncMembers` → `kapGet('/members', apiKey, token)` → HTTP isteği kurarken:
```javascript
headers: {
  'Authorization': `Bearer ${token}`,  // ← SORUN BURADA
  ...
}
```

Node.js'in `https` modülü, header değerinde geçersiz karakter (örn. `\n`, `\r`, kontrol karakterleri) olunca `Invalid character in header content ["Authorization"]` hatasını fırlatır. Bu bir ağ hatası veya API reddi değil — **istek hiç gönderilmiyor**.

---

## 4. Hata Kategorisi

| Kategori | Durum |
|----------|-------|
| A) `Şirket listesi boş geldi` | ❌ Hayır |
| B) HTTP 401 | ❌ Hayır |
| C) HTTP 403 | ❌ Hayır |
| D) Başka HTTP hatası | ❌ Hayır |
| **E) Başka bir hata** | ✅ **EVET** |

**Kesin cevap: E — `Invalid character in header content ["Authorization"]`**

KAP API'ye hiç istek atılamıyor. Node.js HTTP katmanı, `Authorization` header'ına set edilmeye çalışılan `Bearer ${token}` değerinde geçersiz karakter bulduğu için isteği **oluşturmayı reddediyor**.

---

## 5. Kök Neden Analizi

### Neden bu hata?

`KAP_TOKEN` secret'inin değeri muhtemelen newline karakteri (`\n`) veya carriage return (`\r`) içeriyor. Bu çok yaygın bir sorun:

1. Secret Firebase Secret Manager'a `echo "token_degeri"` ile set edildi → `echo` sona `\n` ekler
2. Veya secret değeri kopyalanırken sona boşluk/satır sonu geldi

### Kanıt:

`syncKapManual` (admin endpoint) kodunda tam bu sorun için `.trim()` eklenmiş:
```javascript
const adminSecret = ADMIN_SECRET.value().trim();  // ← .trim() var
const provided    = (req.headers['x-admin-secret'] || ...).trim();
```

Ama `runKapSync` içinde:
```javascript
const apiKey = KAP_API_KEY.value();  // ← .trim() YOK
const token  = KAP_TOKEN.value();    // ← .trim() YOK
```

### Zaman damgası:

Tüm loglar aynı hatayı gösteriyor — Eylül başından beri (en eski gördüğümüz kayıt: `2026-09-08`). Başarılı bir sync kaydı hiç yok.

---

## 6. Önerilen Düzeltme (implement etme — sadece bilgi)

### Seçenek A — Secret değerini düzelt (tercih edilen)

Firebase Secret Manager'da `KAP_TOKEN` ve `KAP_API_KEY` secret'larını yeniden set et:

```bash
# Newline olmadan set et:
printf 'gercek_token_degeri' | firebase functions:secrets:set KAP_TOKEN
printf 'gercek_api_key_degeri' | firebase functions:secrets:set KAP_API_KEY
```

`echo` yerine `printf` kullan — `printf` sona `\n` eklemez.

### Seçenek B — Kodda .trim() ekle (güvenlik ağı)

`functions/index.js` içinde `runKapSync`:
```javascript
const apiKey = KAP_API_KEY.value().trim();  // .trim() ekle
const token  = KAP_TOKEN.value().trim();    // .trim() ekle
```

Bu değişiklik `syncKapOpeningPre`, `syncKapOpeningWindow`, `syncKapDisclosures`, ve `syncKapManual` fonksiyonlarının **hepsini** etkiler.

---

## 7. Firestore Koleksiyon Yapısı (gözlemlenen)

Mevcut koleksiyonlar:
```
ai_cache
bist_index_meta
entitlements
fundamentals
ipo_items
ipo_meta
kap_sync_logs      ← incelendi
meta               ← meta/kap incelendi
purchases
subscription_tokens
trials
```

`kap_members` ve `kap_disclosures` koleksiyonları listede **yok** — KAP sync hiç başarıyla tamamlanmadığı için bu koleksiyonlar hiç oluşmadı/dolu değil.

---

## Veri Kaynakları

- `d:\k\wink\teknik_bakis\.agents\tasks\firestore_latest.json` — En son 3 log kaydı
- `d:\k\wink\teknik_bakis\.agents\tasks\firestore_full_results.json` — meta/kap tam alanlar + koleksiyon listesi
- `d:\k\wink\teknik_bakis\functions\index.js` — Kaynak kodu analizi
