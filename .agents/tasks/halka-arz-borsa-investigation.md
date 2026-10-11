# Halka Arz – Borsa Araştırma Raporu

**Tarih:** 2026-10-03  
**Araştıran:** Investigator Agent  
**Amaç:** "Yaklaşan" ve "Listeleme Bekliyor" durumundaki halka arz kayıtlarının hangilerinin BIST'te işlem gördüğünü, hangilerinin görmediğini tespit etmek.

---

## Özet Cevap

**Kodda "yaklaşan" veya "listeleme bekliyor" durumundaki bir hissenin BIST'te işlem görüp görmediğini kontrol eden herhangi bir mantık yoktur.** Bu iki durum, tanım gereği henüz borsaya kote edilmemiş hisseleri temsil eder. Mevcut sistemde:

- **Borsada işlem görüyor** (`IpoStatus.trading`) → `kBistStocks` listesine otomatik eklenir.
- **Yaklaşan** (`IpoStatus.upcoming`) ve **Listeleme Bekliyor** (`IpoStatus.pendingListing`) → `kBistStocks` listesine **asla eklenmez**.

Bu ayrım tamamen **tarihe dayalı otomatik durum türetme** (date-derived status) ile yönetilir; hiçbir `isListed` veya `listed` alanı yoktur.

Yerel veri dosyalarındaki (seed + feed) tüm kayıtlar `status: "trading"` durumundadır. "Yaklaşan" ve "Listeleme Bekliyor" kayıtları yalnızca **Firestore** veritabanında bulunur ve bu araştırma sırasında erişilemez durumdaydı.

---

## Kanıtlar ve Dosya Referansları

### 1. Veri Kaynakları

**`data/ipo_feed.json`** ve **`assets/data/ipo_seed.json`** — Her iki dosya da özdeş içeriktedir ve yalnızca `"status": "trading"` olan 23 kayıt içerir. `"upcoming"` veya `"pendingListing"` statülü hiçbir kayıt yoktur.

| # | Sembol | Şirket Adı | Listeleme Tarihi |
|---|--------|-----------|-----------------|
| 1 | NETGL | Net Global Endüstriyel Yatırımlar | 17.09.2026 |
| 2 | BKRGY | Bakırcı Gayrimenkul Yatırım Ortaklığı | 02.09.2026 |
| 3 | INTET | İntetra Teknoloji ve Bilişim Hizmetleri | 01.09.2026 |
| 4 | KPEKS | Kapeks Kimya Sanayi | 21.08.2026 |
| 5 | VEYAS | Türker Vangölü Enerji Yatırım | 20.08.2026 |
| 6 | TKNKA | Teknika Plast Teknik Kalıp Plastik | 20.08.2026 |
| 7 | CITAS | Çitlekçi Mağazacılık Gıda | 18.08.2026 |
| 8 | BEWEN | Bewen Enerji | 07.08.2026 |
| 9 | QUICK | Quick Sigorta | 06.08.2026 |
| 10 | KARCL | Kardemir Çelik Sanayi | 29.07.2026 |
| 11 | MASFN | Masfen Enerji | 29.07.2026 |
| 12 | ALBTN | Albayrak Hazır Beton | 29.07.2026 |
| 13 | METEN | Metgün Enerji Yatırımları | 28.07.2026 |
| 14 | SARAE | Sa-Ra Enerji İnşaat | 17.07.2026 |
| 15 | SSAAT | Saat ve Saat | 15.07.2026 |
| 16 | EKIM | Ekim Turizm | 10.07.2026 |
| 17 | ISVEA | İsvea Seramik ve Banyo Ürünleri | 09.07.2026 |
| 18 | GOLDA | Golda Gıda | 09.07.2026 |
| 19 | SOHOE | Soho Giyim ve Enerji | 08.07.2026 |
| 20 | ORZAX | Orzaks İlaç ve Kimya | 07.07.2026 |
| 21 | BETAE | Beta Enerji ve Teknoloji | 01.07.2026 |
| 22 | EKDMR | Ekinciler Demir ve Çelik Sanayi | 22.05.2026 |
| 23 | ENPRA | Enpara Bank | 07.04.2026 |

Tüm bu hisseler `kBistStocks` listesine `syncBistStocksWithIpoItems()` fonksiyonu aracılığıyla eklenmiş durumdadır.

**Canlı veri** için uygulama iki kaynağa bakar (öncelik sırasıyla):
1. **Firestore** → `ipo_items` collection'ı (`lib/services/ipo_service.dart`, `_refreshFromFirestore()`)
2. **GitHub fallback** → `https://raw.githubusercontent.com/01Alikose01/teknik_bakis/main/data/ipo_feed.json`

---

### 2. Durum Belirleme Mantığı

**`lib/models/ipo_item.dart`** — `_deriveStatus()` metodu, `IpoStatus` değerini Firestore'daki statik `status` alanından değil **tarihlerden** türetir:

```dart
// lib/models/ipo_item.dart, _deriveStatus()
if (listingDate != null && !listingDate.isAfter(now)) {
  return IpoStatus.trading;             // listingDate geçti → Borsada
}
if (requestEnd != null && now.isAfter(_endOfDay(requestEnd))) {
  if (listingDate != null && listingDate.isAfter(now)) {
    return IpoStatus.pendingListing;    // talep bitti + listingDate gelecekte → Listeleme Bekliyor
  }
  return IpoStatus.pendingListing;     // talep bitti + listingDate bilinmiyor → Listeleme Bekliyor
}
if (requestStart != null) {
  return now.isBefore(_startOfDay(requestStart))
      ? IpoStatus.upcoming             // requestStart henüz gelmedi → Yaklaşan
      : IpoStatus.collecting;          // requestStart geçti ama requestEnd gelmedi → Talep Topluyor
}
```

Bu demektir ki:
- Bir hisse **teorik olarak `upcoming` veya `pendingListing` durumunda olup aynı zamanda `kBistStocks` içinde yer alamaz.**
- Dates‑first mantığı Firestore'daki yanlış `status` değerlerini ezdiğinden (`lib/models/ipo_item.dart`, `_parseStatus()` → `hasTimeline` koşulu), bir hissenin durumu gerçek tarihleri yansıtır.

---

### 3. BIST Listesine Ekleme Mekanizması

**`lib/services/bist_stocks.dart`** — `syncBistStocksWithIpoItems()` (satır 785):

```dart
for (final item in ipoItems.where((item) =>
    item.status == IpoStatus.trading && item.symbol.isNotEmpty)) {
  // Sadece IpoStatus.trading olan hisseler kBistStocks'a eklenir
  ...
}
```

Bu fonksiyon `lib/services/ipo_service.dart` içinde her veri yüklemesinde çağrılır:
- `loadCachedOrSeed()` → satır 60, 73
- `_refreshFromFirestore()` → satır 134
- `_refreshFromGithub()` → satır 173

**Sonuç:** `upcoming` veya `pendingListing` durumundaki hiçbir hisse `kBistStocks` listesine girmez. Bu kontrol açık ve tutarlıdır.

---

### 4. UI Sekmeleri ve Gruplama

**`lib/screens/ipo_screen.dart`** — `_groupedItems()` metodu:

- **Yaklaşan sekmesi:** `item.status == IpoStatus.upcoming` olanlar + `requestDates` içinde "ertelendi"/"postponed" yazmayanlar + `requestStart` henüz gelmemiş olanlar.
- **Talep Topluyor sekmesi:** `item.status == IpoStatus.collecting` olanlar.
- **Listeleme Bekliyor sekmesi:** `item.status == IpoStatus.pendingListing` olanlar.
- **Borsada İşlem Görüyor sekmesi:** `item.status == IpoStatus.trading` olanlar, en yeni 10 tanesi gösterilir.

Her hisse yalnızca tek bir sekmede görünür (sekme atlaması yoktur). Bu `test/ipo_logic_test.dart` Senaryo 8'de test edilmiştir.

---

### 5. Firestore'daki Canlı Durum

Araştırma sırasında Firestore'a doğrudan erişim mümkün olmadı. `ipo_items` collection'ındaki gerçek "yaklaşan" ve "listeleme bekleniyor" kayıtlarını görmek için şu yollar denenebilir:

- Firebase Console → `ipo_items` collection filtresi: `status == "upcoming"` veya `status == "pending_listing"`
- Uygulama açık durumdayken Firestore listener logları incelenebilir (debug mode)
- GitHub feed URL'i ziyaret edilebilir: `https://raw.githubusercontent.com/01Alikose01/teknik_bakis/main/data/ipo_feed.json`

---

## Sonuçlar

| Soru | Cevap |
|------|-------|
| "Yaklaşan" hisseler BIST'te işlem görüyor mu? | **Hayır** — tanım gereği requestStart henüz gelmemiş, dolayısıyla listeye alınmamışlardır. |
| "Listeleme Bekliyor" hisseler BIST'te işlem görüyor mu? | **Hayır** — talep toplama bitti ama listingDate gelmedi; kBistStocks'a eklenmezler. |
| Bu ayrım nasıl belirleniyor? | Yalnızca `requestStart`, `requestEnd`, `listingDate` tarihleriyle otomatik türetme. Ayrı bir `isListed` alanı yoktur. |
| Canlı "yaklaşan"/"listeleme bekliyor" verileri nerede? | Firestore `ipo_items` collection'ında; yerel JSON dosyalarında bu statüde kayıt bulunmuyor. |

---

## Öneriler

1. **Veri Eksikliği Değil, Tasarım Gereği:** "Yaklaşan" ve "Listeleme Bekliyor" kategorilerinde hiçbir hissenin BIST'te işlem görmemesi, sistemin tasarım amacına uygun bir davranıştır. Bir hata veya eksik değildir.

2. **Canlı Veri İçin:** Gerçek "yaklaşan" ve "listeleme bekliyor" hisse listesini görmek için Firestore `ipo_items` collection'ından `status` alanı `upcoming` veya `pending_listing` olan kayıtlar sorgulanmalıdır.

3. **Potansiyel Sorun – Eksik `listingDate`:** `_deriveStatus()` içinde `requestEnd` geçmişte ve `listingDate` null ise hisse `pendingListing`'e düşer, ancak `fallbackStatus == IpoStatus.trading` ise `trading` döner. Bu durum Senaryo F'de test edilmiştir. Eğer Firestore'da `listingDate` girilmemiş `trading` kayıtları varsa bunlar `pendingListing`'de takılabilir.

4. **`kBistStocks` Güncelliği:** `syncBistStocksWithIpoItems()` yalnızca uygulama çalışırken ve veri yenilendiğinde çalışır. Firestore'dan gelen `trading` hisselerin `kBistStocks`'a girmesi için `Bist100Service.init()` veya `IpoService.refresh()` çağrısı tamamlanmış olmalıdır.
