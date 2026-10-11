# Halka Arz Kategori Sorunu — Araştırma Raporu

**Tarih:** 2026-10-05  
**Araştıran:** Investigation Agent  
**Konu:** Yaklaşan: 2, Listeleme Bekliyor: 17, Borsada İşlem Görüyor: 0 sayım hatası  

---

## Özet Cevap (Hızlı Referans)

| Soru | Cevap |
|------|-------|
| **Gerçek veri kaynağı** | **Firestore** (`ipo_items` collection) — öncelik 1. GitHub fallback ikincil. Yerel JSON (`assets/data/ipo_seed.json`, `data/ipo_feed.json`) her ikisi de **boş** (`items: []`). |
| **SOHOE/ORZAX neden yanlış kategoride?** | Firestore'daki kayıtları tarih alanları olmayan ya da yanlış `status` değeriyle giriş yapılmış. Geçmişte `bist_stocks` koleksiyonunda SOHOE ve ORZAX sembolü **yoktu**; bu yüzden BIST kontrolü de çalışmıyordu. |
| **Sorun hangi dosya/fonksiyon?** | `functions/index.js` → eski `deriveIpoStatus()` fonksiyonu + `syncIpoFeed` sıralama hatası. |
| **Düzeltmek için ne değiştirmeliyiz?** | `functions/index.js` düzeltmesi **HEAD commit'inde zaten tamamlandı** (`89b8d5a`). Ancak fix henüz Firebase'e **deploy edilmemiş** olabilir ve `data/ipo_manual_overrides.json`'dan SOHOE/ORZAX girişleri **unstaged olarak silindi** — bu silme geri alınmalı veya yeniden commit'e dahil edilmeli. |

---

## 1. Gerçek Veri Kaynağı

**Kaynak: Firestore `ipo_items` koleksiyonu**

`lib/services/ipo_service.dart` içindeki `refresh()` fonksiyonu şu öncelik sıralamasıyla çalışır:

1. **Firestore** (`_refreshFromFirestore()`) → `FirebaseFirestore.instance.collection('ipo_items').get()`
2. **GitHub fallback** (`_refreshFromGithub()`) → `https://raw.githubusercontent.com/01Alikose01/teknik_bakis/main/data/ipo_feed.json`
3. **Yerel seed** (`loadCachedOrSeed()`) → `assets/data/ipo_seed.json`

**Yerel JSON dosyaları boş:**
- `assets/data/ipo_seed.json` → `"items": []`
- `data/ipo_feed.json` → `"items": []`

**`data/ipo_manual_overrides.json`** yalnızca 11 `"trading"` statülü kayıt içeriyor (BEWEN, QUICK, KARCL, MASFN, ALBTN, METEN, SARAE, SSAAT, EKIM, GOLDA, ISVEA). Bu dosya Flutter uygulaması tarafından doğrudan okunan bir dosya değil; sadece geliştirici referansı ya da manuel yükleme için kullanılmaktadır.

Uygulama Firestore'a erişemezse Hive önbelleğinden, o da yoksa GitHub feed'den, o da yoksa boş seed'den yükler. Bu yüzden **aktif kullanımda ekranda görünen her şey Firestore'dan gelmektedir**.

---

## 2. `_deriveStatus()` Mantığı — Nasıl Çalışıyor

`lib/models/ipo_item.dart` içindeki `_deriveStatus()` statik fonksiyonu yalnızca Flutter istemcisinde çalışır; sunucu tarafında değil. Mantığı şöyle:

```dart
static IpoStatus _deriveStatus({
  required DateTime? requestStart,
  required DateTime? requestEnd,
  required DateTime? listingDate,
  required IpoStatus fallbackStatus,
}) {
  final now = _nowInTurkey(); // UTC+3

  // 1. listingDate geçtiyse → Borsada İşlem Görüyor
  if (listingDate != null && !listingDate.isAfter(now)) {
    return IpoStatus.trading;
  }

  // 2. requestEnd geçtiyse → Listeleme Bekliyor
  if (requestEnd != null && now.isAfter(_endOfDay(requestEnd))) {
    if (listingDate != null && !listingDate.isAfter(now)) return IpoStatus.trading;
    if (listingDate != null && listingDate.isAfter(now)) return IpoStatus.pendingListing;
    // listingDate yoksa fallback'e bak
    if (fallbackStatus == IpoStatus.trading) return IpoStatus.trading;
    return IpoStatus.pendingListing;
  }

  // 3. requestStart varsa → Yaklaşan veya Talep Topluyor
  if (requestStart != null) {
    return now.isBefore(_startOfDay(requestStart))
        ? IpoStatus.upcoming    // requestStart henüz gelmedi
        : IpoStatus.collecting; // requestStart geçti ama requestEnd gelmedi
  }

  // 4. Yalnızca listingDate varsa
  if (listingDate != null) {
    return now.isBefore(_startOfDay(listingDate)) ? IpoStatus.upcoming : IpoStatus.trading;
  }

  return fallbackStatus;
}
```

**Kritik nokta:** `_deriveStatus()` yalnızca Firestore'dan alınan tarih alanları (`requestStart`, `requestEnd`, `listingDate`) mevcutsa çalışır. Bu alanlar **null** ise `_hasTimelineData = false` olur ve Firestore'daki ham `status` string'i kullanılır (`_parseRawStatus()`). 

Dolayısıyla Firestore'daki bir kayıtta tarih alanları boş ama `status: "upcoming"` yazıyorsa — ne kadar geçmiş bir tarih söz konusu olursa olsun — uygulama o kaydı **"Yaklaşan"** olarak gösterir.

---

## 3. SOHOE ve ORZAX Neden "Yaklaşan" Görünüyor?

### Temel Neden: Firestore'daki Stale (Bayat) Veri

SOHOE ve ORZAX gerçekte borsada işlem gören hisselerdir:
- **ORZAX** listingDate: **07.07.2026** — `bistguncel.md`'de fiyatı 101.70 TL
- **SOHOE** listingDate: **08.07.2026** — `bistguncel.md`'de fiyatı 12.07 TL

Her ikisi de `lib/services/bist_stocks.dart` listesine `8700fa2` commit'iyle eklenmiştir (2026-10-05 15:15 tarihinde), ancak bu tarihten önce:

1. **`bist_stocks` koleksiyonunda yoklardı** → `computeIpoStatus()` BIST kontrolünden geçemiyorlardı
2. **Firestore'daki kayıtlarında `listingDate` ya yoktu ya da yanlış parse ediliyordu** → `_deriveStatus()` bir tarih bulamayınca `requestStart`/`requestEnd`'e bakıyordu
3. **`requestStart` veya `requestEnd` de yoksa** → `_hasTimelineData = false`, doğrudan Firestore'daki `status: "upcoming"` değerini kullanıyordu

### Cloud Function'daki Hata (Eski `deriveIpoStatus()`)

`functions/index.js` içindeki eski `deriveIpoStatus()` fonksiyonu BIST sembol kontrolü yapmıyordu. `syncIpoFeed` akışı şöyleydi:

```
// ESKI (hatalı) akış:
1. reconcileStaleIpoStatuses()  ← Firestore'daki bayat kaydı "trading" yapıyor
2. fetchHalkArzItems()          ← HalkArz'dan "upcoming" ya da "pending_listing" çekiyor
3. writeIpoToFirestore(items)   ← Adım 1'deki düzeltmenin üzerine "upcoming" yazıyor
```

Sonuç: `reconcile` adımı anlamsız kalıyordu; HalkArz her zaman kazanıyordu. HalkArz sitesinde SOHOE ve ORZAX'ın listingDate'i sistematik olarak eksik ya da yanlış parse edildiğinde `requestEnd` geçmişse `pending_listing`, `requestEnd` de eksikse `upcoming` atanıyordu.

### Ek Sorun: `data/ipo_manual_overrides.json`'daki Silme

`git diff` çıktısına göre:
- **HEAD (89b8d5a)'de**: `data/ipo_manual_overrides.json` içinde SOHOE ve ORZAX `"status": "trading"` ile **mevcut**
  - SOHOE: `requestStart: 2026-06-30`, `requestEnd: 2026-07-01`, `listingDate: 2026-07-08`
  - ORZAX: `requestStart: 2026-06-29`, `requestEnd: 2026-07-01`, `listingDate: 2026-07-07`
- **Working copy (unstaged)**: Bu iki giriş **silinmiş** ama commit edilmemiş

Bu silme dosyası commit edilirse, eğer `syncIpoManual` bu dosyayı kaynak olarak kullanıyorsa SOHOE ve ORZAX yeniden kaybolur. **Ancak** `functions/index.js` içindeki `syncIpoManual` fonksiyonu bu dosyayı okumaz — yalnızca HalkArz.com'dan canlı scraping yapar. Bu yüzden bu unstaged silme `functions/index.js` akışını doğrudan etkilemez, fakat referans veri olarak gelecekte yanlış yönlendirme yaratabilir.

---

## 4. Sorun Nerede?

| Dosya | Sorun |
|-------|-------|
| `functions/index.js` | **Eski `deriveIpoStatus()`**: BIST kontrolü yok, reconcile → write sırası ters. **HEAD'de düzeltildi.** |
| Firestore `ipo_items` | SOHOE ve ORZAX için `status: "upcoming"` hâlâ canlı veritabanında duruyor olabilir (Cloud Function yeniden çalışana kadar). |
| `data/ipo_manual_overrides.json` | SOHOE ve ORZAX girişleri working copy'de silindi ama commit edilmedi. |

---

## 5. Düzeltmek İçin Ne Yapılmalı?

### Zaten Yapılanlar (Kod Tarafı — Tamamlandı)

✅ `functions/index.js` → `computeIpoStatus()` BIST sembol kontrolü eklendi (sembol `bist_stocks` koleksiyonunda varsa direkt `trading`)  
✅ `functions/index.js` → `writeIpoToFirestore()` trading koruması eklendi (Firestore'da `trading` olan kaydın üzerine yazılmaz)  
✅ `functions/index.js` → `syncIpoFeed` sıralama düzeltildi: `loadBistSymbols → fetch → write → reconcile`  
✅ `lib/services/bist_stocks.dart` → SOHOE ve ORZAX sembolleri eklendi (commit `8700fa2`)  

### Yapılması Gereken Tek Şey: Firebase Deploy

```bash
cd functions
firebase deploy --only functions:syncIpoFeed,functions:syncIpoManual
```

Bu deploy tamamlandıktan sonra `syncIpoManual` ya da zamanlanmış `syncIpoFeed` çalışınca:
1. `loadBistSymbols()` → SOHOE ve ORZAX'ı `bist_stocks` koleksiyonundan alır
2. `computeIpoStatus()` → BIST kontrolünde "sembol var → `trading`" döner
3. `reconcileStaleIpoStatuses()` → Firestore'da hâlâ `upcoming` olan kayıtları `trading` yapar
4. Uygulama sonraki 45 dakikalık refresh döngüsünde güncel veriyi çeker

### Opsiyonel: Manual Override Dosyasındaki Silmeyi Geri Al

`data/ipo_manual_overrides.json`'daki SOHOE ve ORZAX satırlarının silinmesi `functions/index.js`'i etkilemez (bu dosya fonksiyon tarafından okunmuyor), ancak referans bütünlüğü için bu unstaged değişikliğin `git restore data/ipo_manual_overrides.json` ile geri alınması ya da kasıtlı silme ise nedeniyle commit edilmesi önerilir.

---

## 6. Özet Akış Diyagramı

```
Uygulama açılır
    │
    ▼
IpoService.loadCachedOrSeed()
    │─── Hive cache var mı? → Evet → Cache'den yükle
    │─── Hayır → assets/data/ipo_seed.json (BOŞ!)
    │
IpoService.shouldRefresh()? → Evet
    │
    ▼
IpoService.refresh()
    │─── 1. Firestore ipo_items → SOHOE/ORZAX burada "upcoming" olarak duruyor
    │         ↓
    │    IpoItem.fromJson() → _parseStatus() → _hasTimelineData?
    │         ↓ (tarih alanı varsa)
    │    _deriveStatus() → listingDate=2026-07-08 geçmiş → IpoStatus.trading ✓
    │         ↓ (tarih alanı YOKSA)
    │    Firestore status = "upcoming" → IpoStatus.upcoming ✗ ← BURADA HATA
    │
    ▼
IpoScreen._groupedItems()
    │─── upcoming filter → requestStart null değilse ve geçmişte değilse göster
         (ek koruma var ama Firestore'dan gelen tarih yoksa çalışmıyor)
```

---

## Sonuç

**Temel sorun:** Firestore'daki SOHOE ve ORZAX kayıtları `listingDate` alanı olmadan ya da `status: "upcoming"` ile kaydedilmiş. Cloud Function'daki eski `deriveIpoStatus()` BIST listesini kontrol etmediği ve `reconcile → write` sırası ters olduğu için bu yanlış statü düzeltilemiyor, her 6 saatlik sync'te HalkArz'ın gönderdiği değer kazanıyordu.

**Kod düzeltmesi HEAD'de mevcut.** Firebase deploy tamamlandığında ve bir sonraki sync çalıştığında sayımlar düzelecek. Ekstra adım olarak `syncIpoManual` HTTP endpoint'i tetiklenerek anlık düzeltme de yapılabilir.
