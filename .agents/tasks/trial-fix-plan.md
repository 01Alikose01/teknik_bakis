# Implementation Plan: Trial Yeniden Kurulum Sorunu

## Mevcut Kodun Sorun Analizi

### Sorun 1 — Firebase `initializeApp` hiç çağrılmıyor (KRİTİK)

**Dosya:** `lib/main.dart` — `main()` fonksiyonu

`main()` içinde `Firebase.initializeApp()` çağrısı yoktur. `main.dart` `firebase_options.dart`'ı import etmiyor; `DefaultFirebaseOptions` hiçbir yerde kullanılmıyor. Ancak `SubscriptionService.init()` çağrıldığında `_syncTrialFromBackend()` → `TrialBackendService.syncTrial()` → `FirebaseFirestore.instance` erişimi yapılıyor. Firebase init edilmeden `FirebaseFirestore.instance` kullanılırsa exception fırlatır; bu exception `syncTrial()` içindeki `catch (_)` bloğuna düşer ve `null` döner. Bunun sonucu: `_syncTrialFromBackend()` da `null` alır, `trialStart` Hive'da yoksa `startGuestTrial()` çağrılır ve yeni bir yerel trial başlar.

**Sonuç:** Firebase Firestore hiçbir zaman kullanılamadığı için `trials` koleksiyonuna hiç yazılmıyor/okunmuyor. Her uygulama kurulumu "offline ilk kurulum fallback" yolunu izliyor.

### Sorun 2 — `_syncTrialFromBackend()` offline/hata durumunda yeni trial başlatıyor

**Dosya:** `lib/services/subscription_service.dart`, satır 60–68

```dart
// catch bloğu:
if (_box.get(_kTrialStart) == null) {
  await startGuestTrial();
}
```

Firebase init olmadığından (Sorun 1) `syncTrial()` her zaman `null` döner. `_syncTrialFromBackend()` bunu "offline" olarak yorumlar. Hive'da `trialStart` yoksa (uygulama silinip yeniden kurulduysa Hive silinmiştir) `startGuestTrial()` çağrılır. Böylece her yeni kurulumda yeni bir trial başlar.

**Gerçek hedef davranış:** Backend'e ulaşılamazsa ya da backend `trialConsumed: true` dönüyorsa trial başlatılmamalı. Sadece `eligible: true, trialConsumed: false` durumunda trial başlatılmalı.

### Sorun 3 — `trialConsumed` bayrağı hiç okunmuyor

**Dosya:** `lib/services/trial_backend_service.dart`

`syncTrial()` Firestore'dan `trialStart` döndürüyor, ancak `trialConsumed` alanını **döndürmüyor**. `SubscriptionService` `trialConsumed` değerini hiç okumadığından, bir cihazda trial dolmuş olsa bile Firestore'daki kayıt tekrar bulunduğunda sadece `trialStart` geri yükleniyor. `markConsumed()` metodu yazılmış ama **hiçbir yerde çağrılmıyor** — trial 10 günü doldurduğunda Firestore'a `trialConsumed: true` yazılmıyor.

**Sonuç:** Backend'de `trialConsumed: true` olan cihazlar yeniden kurulumda tekrar `startGuestTrial()` alıyor çünkü consumed flag ne yazılıyor ne de okunuyor.

### Sorun 4 — `startGuestTrial()` backend doğrulaması olmadan çağrılıyor

**Dosya:** `lib/screens/onboarding_screen.dart` satır 51, `lib/screens/premium_gate_screen.dart` satır 143

Bu ekranlar, Firestore kayıt kontrolü yapmadan doğrudan `SubscriptionService.startGuestTrial()` çağırıyor. `TrialBackendService.syncTrial()` yalnızca `init()` sırasında çağrılıyor; kullanıcı onboarding'de "Misafir Olarak Devam Et" tıkladığında hiçbir backend kontrolü olmaksızın trial başlıyor.

Tasarım niyeti: `_syncTrialFromBackend()` zaten `init()` sırasında çağrıldığı için o noktada backend yazılmış olmalı. Ama Sorun 1 nedeniyle bu hiç çalışmadığından bu güvence fiilen işlevsiz.

### Sorun 5 — `DeviceIdService`: `FlutterSecureStorage` Android'de uygulama silinince sıfırlanıyor

**Dosya:** `lib/services/device_id_service.dart`

Android'de `FlutterSecureStorage`, EncryptedSharedPreferences kullanır ve bu depolama **uygulama silindiğinde temizlenir**. Fallback zinciri şu şekilde çalışıyor:

1. SecureStorage'da kayıt yoksa (silinme sonrası) → `android.id` (ANDROID_ID) okunuyor
2. `android.id` başarılı olursa → SecureStorage'a yazılıyor

Bu mantık **doğru** — `android.id` (`Settings.Secure.ANDROID_ID`) Android 8.0+ cihazlarda fabrika sıfırlaması veya tamamen farklı kullanıcı profili olmadıkça değişmez, uygulama yeniden kurulumunda değişmez. `device_info_plus` paketi zaten `pubspec.yaml`'da mevcut (`^12.0.0`).

**Ancak kritik bir risk:** `_fallback()` `DateTime.now().millisecondsSinceEpoch` kullanıyor. SecureStorage okuması başarısız olursa VE `androidInfo.id` da exception fırlatırsa, fallback her seferinde farklı bir ID üretir. Bu durumda her kurulumda farklı Firestore belgesi oluşur.

---

## Düzeltme Planı

### Değiştirilecek Dosyalar

1. `lib/main.dart` — Firebase init ekleme
2. `lib/services/trial_backend_service.dart` — `syncTrial()` eligible/consumed döndürecek şekilde genişletme
3. `lib/services/subscription_service.dart` — backend kontrolü olmadan trial başlatmama, `markConsumed` çağrısı ekleme
4. `lib/services/device_id_service.dart` — fallback'i daha güvenli hale getirme (SharedPreferences ikinci katman)

---

## Uygulama Adımları

- [ ] 1. **Firebase'i `main.dart`'ta başlat**

  `main()` içinde `SubscriptionService.init()` çağrısından önce `Firebase.initializeApp()` çağır. Eksik import'ları ekle.

  **Yapılacaklar:**
  - `lib/main.dart`'a `firebase_core` ve `firebase_options.dart` import'u ekle
  - `WidgetsFlutterBinding.ensureInitialized();` satırından hemen sonra `await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);` ekle

  **Dosyalar:** `lib/main.dart`

  **Doğrulama:** `flutter analyze` — hata olmadığını doğrula. Emülatörde çalıştırıp logcat'te "Firebase initialized" veya Firestore bağlantısı gören satırları kontrol et.

- [ ] 2. **`TrialBackendService.syncTrial()` metodunu `TrialStatus` döndürecek şekilde yeniden yaz**

  Şu anki `String?` dönüş tipi yetersiz — `trialConsumed` bilgisini taşımıyor. Yeni bir `TrialSyncResult` sınıfı oluştur (aynı dosyada, dosya dışına taşıma). Bu sınıf şunları içersin: `trialStart` (String?), `trialConsumed` (bool), `backendReachable` (bool).

  **`syncTrial()` yeni akışı:**
  - Firestore'dan belge al
  - Belge varsa: `trialStart`, `trialConsumed` değerlerini döndür, `backendReachable: true`
  - Belge yoksa: yeni kayıt oluştur (`trialConsumed: false`), `trialStart` döndür, `backendReachable: true`
  - Network/timeout hatası: `backendReachable: false` döndür (null `trialStart`)

  **Dikkat:** Mevcut Firestore koleksiyon/belge yapısı (`trials/{deviceId}`) değişmiyor. Sadece dönüş tipi ve içeriği genişliyor.

  **Dosyalar:** `lib/services/trial_backend_service.dart`

  **Doğrulama:** `flutter analyze` — tip uyumsuzluğu yok (adım 3 bağımlı).

- [ ] 3. **`SubscriptionService._syncTrialFromBackend()` — backend zorunlu hale getir**

  `TrialBackendService.syncTrial()` artık `TrialSyncResult` döndürüyor. `_syncTrialFromBackend()` bu sonucu şu kuralla işlesin:

  - `backendReachable: false` → **trial başlatma**, mevcut Hive değeri korunur. Hive'da trialStart yoksa da trial başlatma — kullanıcıyı premium ekranına yönlendir (flag ile).
  - `backendReachable: true, trialConsumed: true` → **trial başlatma**. Hive'daki trialStart'ı `_kTrialConsumedSentinel` (özel sabit bir tarih, ör. `'consumed'`) ile işaretle ki kullanıcı bir daha trial başlatamaz.
  - `backendReachable: true, trialConsumed: false` → `trialStart` Hive'a yaz (değişmişse). Bu yol `startGuestTrial()` çağrısını da kapsar.

  **`startGuestTrial()` düzenlemesi:**
  - `startGuestTrial()` artık doğrudan Hive'a yazmamalı. Hive'da zaten `trialStart` yoksa ve backend'den `eligible` onayı gelmişse çalışmalı. Backend onayı olmadan (onboarding'den doğrudan çağrı) çalışmaması için: `startGuestTrial()` çağrısını kaldır, yerine `_syncTrialFromBackend()`'in backend'den dönen `trialStart` değerini Hive'a yazması yeterli.
  - Onboarding/premium_gate ekranlarından yapılan `startGuestTrial()` çağrıları korunabilir ama içeride "Hive'da değer varsa çıkış" kontrolü zaten var. Bu çağrılar zararsızdır çünkü asıl trial yönetimi artık `_syncTrialFromBackend()` tarafında.

  **`daysSinceTrial` / `trialConsumed` sentinel kontrolü:**
  - `trialStart` değeri `'consumed'` ise `isInFreeTrial = false`, `hasUsedTrialBefore = true` dönmeli.
  - `_kTrialStart` box key'ine `'consumed'` string'i yazılırsa `DateTime.tryParse` null döner, bu zaten `trialStart = null` → `isInFreeTrial = false` sonucunu verir. Bu yeterli — ek sentinel gerekmeyebilir. Kontrol et.

  **`markConsumed()` çağrısı:**
  - `isInFreeTrial` getter'ı değerlendirildiğinde ya da `daysSinceTrial >= 10` ilk kez tespit edildiğinde `TrialBackendService.markConsumed()` çağrılmalı. En güvenli yer: `SubscriptionService.init()` sonunda, `syncWithBackendEntitlements()` çağrısından önce, `_checkAndMarkConsumed()` adlı bir private metot ekle. Bu metot: `trialStart != null && daysSinceTrial >= 10 && !isPaidSubscriber` koşulunu kontrol etsin ve eğer Firestore'a henüz yazılmamışsa `TrialBackendService.markConsumed()` çağırsın. Lokal bir `_kConsumedSent` bool key'ini Hive'a yazarak tekrar tekrar çağrılmasını önle.

  **Dosyalar:** `lib/services/subscription_service.dart`

  **Doğrulama:** `flutter analyze` — hata yok. Birim testleri: `flutter test test/widget_test.dart`.

- [ ] 4. **`DeviceIdService` fallback güvenliğini artır**

  Mevcut fallback `_fallback()` her çağrıda farklı bir string üretiyor (milisaniye bazlı). Bu yalnızca `androidInfo.id` exception fırlatırsa devreye giriyor. Daha güvenli olması için:

  - `FlutterSecureStorage` başarısız VE `android.id` başarısız durumunda: `SharedPreferences`'tan `device_unique_id` key'ini oku. Orada da yoksa UUID üret ve hem SecureStorage hem SharedPreferences'a yaz.
  - Bu sayede SecureStorage'ın şifreleme hatası verdiği edge case'lerde bile aynı ID korunur.
  - `pubspec.yaml`'da `shared_preferences` paketi **zaten var** (`hive_flutter` transitively getirir; eğer direkt import yoksa `shared_preferences: ^2.2.0` ekle). Kontrol et: `pubspec.yaml`'da arama yap.

  **Not:** Bu değişiklik, uygulama silinip yeniden kurulunca SharedPreferences de silindiğinden ana garantiyi vermiyor. Ana garanti `android.id`'den geliyor. Bu adım yalnızca `android.id`'nin exception verdiği nadir edge case'ler için savunma katmanı.

  **Dosyalar:** `lib/services/device_id_service.dart`

  **Doğrulama:** `flutter analyze` — hata yok.

- [ ] 5. **`flutter analyze` çalıştır ve tüm hataları düzelt**

  Tüm değişiklikler tamamlandıktan sonra projeyi analiz et. Tip uyumsuzlukları, unused import, deprecated API uyarılarını gider.

  **Dosyalar:** — (tüm değiştirilen dosyalar)

  **Doğrulama:** `flutter analyze` sıfır hata (warning tolere edilir).

---

## Neden Trial Yeniden Kurulumdan Sonra Tekrar Başlamayacak

Düzeltmeler uygulandıktan sonra akış şöyle çalışacak:

1. **Firebase başlatılır** — `main.dart`'ta `Firebase.initializeApp()` çağrısı var, artık Firestore erişilebilir.
2. **`_syncTrialFromBackend()` çağrılır** — backend'e ulaşılıyor.
3. **Backend'de `trials/{androidId}` belgesi bulunur** — daha önceki kurulumdan mevcut. `trialConsumed: true` ise trial başlatılmaz; `trialConsumed: false` ise eski `trialStart` döndürülür (10 gün geçmişse `isInFreeTrial = false`).
4. **Backend'e ulaşılamazsa** — `startGuestTrial()` artık çağrılmaz. Kullanıcı premium ekranına yönlendirilir.
5. **Android ID kalıcı** — `device_info_plus` ile `ANDROID_ID` okunduğundan Firestore belge anahtarı uygulama silinip yeniden kurulsa bile aynı kalır. `FlutterSecureStorage` silinse bile `android.id` tekrar okunarak aynı değer elde edilir.
6. **Trial dolunca `markConsumed()` çağrılır** — Firestore'a `trialConsumed: true` yazılır; bir sonraki kurulumda bu flag okunur ve trial başlatılmaz.

---

## Önemli Kısıtlamalar Korunuyor

- Google Play Billing / `PurchaseService` — dokunulmadı
- Favori, alarm, haber özellikleri — dokunulmadı
- UI değişikliği — yok
- `TrialBackendService` Firestore koleksiyon yapısı — korunuyor (`trials/{deviceId}`)
- `SubscriptionService` public API'si (`hasPremiumAccess`, `isPaidSubscriber`, `isInFreeTrial`, `trialStart`, vb.) — korunuyor
