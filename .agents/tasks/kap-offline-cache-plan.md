# Implementation Plan — KAP Bildirimleri Offline Cache

## Keşif Notları

- `shared_preferences: ^2.3.5` pubspec.yaml'da zaten mevcut — yeni paket eklenmez.
- `KapNewsItem` modeli `toJson`/`fromJson` içermiyor — eklenmesi gerekiyor.
- Fetch zinciri: `KapDisclosureService.fetchLatest()` (Firestore) → fallback olarak `KapNewsService.fetch()` (GitHub/KAP). Her ikisi de `news_screen.dart` içindeki `_loadKap()` tarafından çağrılıyor.
- In-memory cache `KapDisclosureService._cache` (Map) zaten var; kalıcı cache bu servise ek bir katman olarak ekleniyor.
- `KapNewsService.dedupe()` tüm item listelerine `_buildDeduplicationKey` uygulayarak deduplication yapıyor. Cache'den yüklenen veriye de aynı `dedupe()` uygulanacak.
- State yönetimi tamamen `_NewsScreenState` içinde `setState` ile yapılıyor — provider/bloc/cubit yok, mevcut mimari korunacak.

---

## Plan

- [ ] 1. **KapNewsItem'a toJson/fromJson ekle**
      `KapNewsItem` sınıfına `toJson()` metodu ve `fromJson(Map<String,dynamic>)` factory constructor ekle.
      Alanlar: `title`, `summary`, `source`, `time`, `url`, `isWithin72h`, `disclosureIndex`, `disclosureType`.
      `cleanTitle` ve `analysisText` getter olduğu için JSON'a dahil edilmez.
      Files: `lib/models/kap_news_item.dart`
      Verify: `flutter analyze` — 0 hata.

- [ ] 2. **KapDisclosureService'e kalıcı cache katmanı ekle**
      `dart:convert` ve `package:shared_preferences/shared_preferences.dart` importlarını ekle.
      `static const String _kPrefKey = 'kap_disclosures_cache';` sabiti ekle.
      `static Future<void> _persistCache(List<KapNewsItem> items) async` metodu: `SharedPreferences.getInstance()` → `items.map(e => jsonEncode(e.toJson())).toList()` → `prefs.setStringList(_kPrefKey, ...)`.
      `static Future<List<KapNewsItem>> loadCached() async` metodu: `SharedPreferences.getInstance()` → `getStringList(_kPrefKey)` → `jsonDecode` + `KapNewsItem.fromJson()` → hata durumunda `[]`.
      `fetchLatest()` içinde başarılı fetch sonrası (items dolduğunda) `unawaited(_persistCache(items))` çağır — ana akışı bloklamaz.
      Files: `lib/services/kap_disclosure_service.dart`
      Verify: `flutter analyze` — 0 hata.

- [ ] 3. **news_screen.dart'a offline state ve Çevrimdışı etiketi ekle**
      `_NewsScreenState`'e iki field ekle: `bool _isOffline = false;` ve `bool _loadedFromCache = false;`.
      `_loadKap()` catch bloğunu güncelle: exception yakalandığında `KapDisclosureService.loadCached()` çağır;
      cache doluysa `KapNewsService.dedupe(cachedItems)` uygula, `_kapNews`'e ata, `_isOffline = true` ata;
      cache boşsa `_kapNews` değişmez (önceki liste korunur), `_isOffline = true` ata.
      Başarılı fetch'te `_isOffline = false` ata.
      `_buildKapList()` içinde `_isOffline == true` iken mevcut bildirim sayısı satırının üstüne
      `Row(Icon(Icons.wifi_off, size:13, color:Colors.orange), Text('Çevrimdışı • Önbellek', ...orange, size:11))` ekle.
      Borsa ve KAP AI sekmeleri tamamen dokunulmadan kalır.
      Files: `lib/screens/news_screen.dart`
      Verify: `flutter analyze` — 0 hata; `flutter build apk --debug` başarılı.

---

## Mimari Kararlar

- **Cache nerede?** `KapDisclosureService` içinde — fetch'i yapan servis, cache'i de yönetir. Screen'e shared_preferences import eklemek gerekmez.
- **Ne zaman yaz?** Başarılı `fetchLatest()` sonrası `unawaited(_persistCache(...))` ile async olarak — yükleme süresini etkilemez.
- **Ne zaman oku?** `_loadKap()` catch bloğunda — sadece network/Firestore hatası olduğunda devreye girer. Fallback `_buildSampleNews` / `_fallback()` metodlarına hiç ulaşılmaz çünkü cache yüklemesi bu noktada durumu doldurur.
- **Dedupe?** Cache'den gelen items da `KapNewsService.dedupe()` üzerinden geçirilir — `_buildDeduplicationKey` mantığı bozulmaz.
