# Halka Arz Ekranı Durum Mantığı Düzeltme Raporu

**Tarih:** 2026-10-04  
**Durum:** ✅ TAMAMLANDI — Semantic review APPROVED

---

## Gerçek Tarih Alanları (`IpoItem`)

| Alan | Tip | Açıklama |
|------|-----|----------|
| `requestStart` | `DateTime?` | Talep toplama başlangıç tarihi |
| `requestEnd` | `DateTime?` | Talep toplama bitiş tarihi |
| `listingDate` | `DateTime?` | Borsada ilk işlem/listelenme tarihi |
| `publishedAt` | `DateTime?` | KAP'ta yayın tarihi (yedek sıralama) |

`sortDate` getter: `listingDate ?? requestEnd ?? requestStart ?? publishedAt`

---

## Durum Hesaplama Mantığı

Tüm durum hesaplamaları `_nowInTurkey()` (UTC+3) ile yapılır:

```dart
static DateTime _nowInTurkey() =>
    DateTime.now().toUtc().add(const Duration(hours: 3));
```

| Durum | Kural |
|-------|-------|
| **YAKLAŞAN** | `requestStart > now` |
| **TALEP TOPLUYOR** | `requestStart <= now <= requestEnd` |
| **LİSTELEME BEKLİYOR** | `requestEnd < now` ve `listingDate > now` |
| **BORSADA** | `listingDate <= now` |

Tarih alanı eksikse → yanlışlıkla Borsada gösterilmez.  
Aynı hisse yalnızca tek sekmede bulunur.

---

## Borsada Neden Sadece 10 Kayıt

`_groupedItems()` içinde:

1. `status == IpoStatus.trading` filtresi uygulanır
2. `listingDate` alanına göre **descending** (en yeniden eskiye) sıralanır — `null` olanlar `DateTime(1970)` fallback ile en sona düşer
3. `.take(10)` ile ilk 10 kayıt alınır → `latestTrading`
4. Ekranda `latestTrading` gösterilir
5. Chip sayacı `latestTrading.length` kullanır (max 10)
6. 11. ve daha eski kayıtlar veritabanında durur, sadece UI listesinden çıkar

---

## Sıralama Özeti

| Sekme | Sıralama Alanı | Yön |
|-------|---------------|-----|
| Yaklaşan | `requestStart` | Yakın → uzak (ascending) |
| Talep Topluyor | `requestStart` | En yeni → en eski (descending) ← **DÜZELTİLDİ** |
| Listeleme Bekliyor | `listingDate` | En yakın → en uzak (ascending) |
| Borsada | `listingDate` | En yeni → en eski (descending), max 10 |

---

## Değiştirilen Dosyalar

| Dosya | Değişiklik |
|-------|-----------|
| `lib/models/ipo_item.dart` | `_nowInTurkey()` UTC+3 yardımcısı eklendi; `_deriveStatus()` içinde `DateTime.now()` yerine kullanıldı |
| `lib/screens/ipo_screen.dart` | UTC+3 now; collecting sort düzeltildi (descending); upcoming'deki `requestStart.isBefore(today)` guard kaldırıldı; Borsada chip sayacı `latestTrading.length`; trading sort `listingDate ?? DateTime(1970)` ile doğrudan sıralama |
| `test/ipo_logic_test.dart` | Satır 61 yanlış beklenti düzeltildi; 9 yeni senaryo testi eklendi |

**Dokunulmayan dosyalar:** `tools/update_ipo_feed.mjs`, `lib/services/ipo_service.dart`, KAP Haberleri, Borsa Haberleri, Trial, Premium, Billing, AI, UpdateService, back button sistemleri.

---

## Test Sonuçları

```
flutter test test/ipo_logic_test.dart
+11: All tests passed!
```

11 test geçti (3 mevcut + 9 yeni senaryo).

---

## flutter analyze Sonucu

IPO dosyalarında sıfır hata/uyarı.  
Proje genelinde 266 info/warning — hepsi IPO dışı dosyalarda, önceden var olan sorunlar.

---

## Commit'ler

- `5e0d68a` — FEAT-001: UTC+3, collecting sort, upcoming guard, Borsada sayaç, 9 test
- `bed1913` — Fix: trading sort listingDate doğrudan kullanım (null → DateTime(1970))
