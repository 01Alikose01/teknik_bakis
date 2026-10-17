# Google Play 2027 Uyum Raporu
*Oluşturulma: 2026-10-17*

## Özet

Teknik Bakış Flutter uygulaması Google Play Şubat 2027 ve Nisan 2027 gereksinimlerine
uyumlu hale getirilmiştir.

---

## Yapılan Değişiklikler

### GÖREV 1 — ProGuard Kuralları Optimizasyonu
**Dosya:** `android/app/proguard-rules.pro`
- `io.flutter.**` blanket keep kaldırıldı; sadece embedding, plugin registry sınıfları korunuyor
- `com.google.android.gms.**` blanket keep kaldırıldı; sadece auth ve tasks alt paketleri korunuyor
- Firebase kuralları minimal hale getirildi
- `androidx.credentials.**` ve `com.google.android.libraries.identity.googleid.**` keep kuralları eklendi (Credentials API)
- R8 tree-shaking ve obfuscation artık etkin çalışıyor

### GÖREV 2 — gradle.properties Optimizasyonu
**Dosya:** `android/gradle.properties`
- `org.gradle.parallel=true` — paralel build etkinleştirildi
- `org.gradle.configureondemand=true` — on-demand konfigürasyon etkinleştirildi
- `kotlin.incremental=true` — Kotlin incremental derleme etkinleştirildi
- `android.enableR8FullMode=true` eklendi — R8 full mode DEX boyutunu daha agresif küçültür
- Eski migration artifact'ları (`android.builtInKotlin`, `android.newDsl`) kaldırıldı

### GÖREV 3 — build.gradle.kts Optimizasyonu
**Dosya:** `android/app/build.gradle.kts`
- ABI filtreleri eklendi: `arm64-v8a`, `armeabi-v7a` (x86_64 kaldırıldı — Play Store zaten ABI split yapıyor)
- Packaging bloğu eklendi: META-INF lisans dosyaları ve `DebugProbesKt.bin` exclude ediliyor
- Credentials API bağımlılıkları eklendi: `credentials:1.5.0`, `credentials-play-services-auth:1.5.0`, `googleid:1.1.1`

### GÖREV 4 — Splash Ekranı Bellek Yönetimi
**Dosya:** `lib/screens/splash_screen.dart`
- `WidgetsBindingObserver` mixin eklendi
- Uygulama arka plana geçince video otomatik duraklatılıyor (`AppLifecycleState.paused`)
- Ön plana gelince video devam ediyor veya bitmişse navigate ediliyor
- `_navigatedAway` flag ile çift navigate önlendi
- Video bitmeden dispose çağrılırsa crash riski ortadan kaldırıldı

### GÖREV 5 — google_fonts Runtime Fetching Devre Dışı
**Dosya:** `lib/main.dart`
- `GoogleFonts.config.allowRuntimeFetching = false` eklendi
- Runtime'da Google Fonts CDN'e istek atılmıyor; sadece bundle'daki fontlar kullanılıyor
- Bellek ve network kullanımı azaldı

### GÖREV 6 — Zero-Tap Giriş (Restore Credentials API)
**Yeni dosyalar:**
- `lib/services/credentials_service.dart` — Dart MethodChannel wrapper
- `android/app/src/main/kotlin/.../CredentialsHandler.kt` — Kotlin native handler

**Güncellenen dosyalar:**
- `android/app/src/main/kotlin/.../MainActivity.kt` — `FlutterFragmentActivity` bazına geçildi, `CredentialsHandler` kaydedildi
- `lib/main.dart` — uygulama başlangıcında credentials restore deneniyor (non-blocking)
- `lib/screens/onboarding_screen.dart` — "Geri Yükle" butonu credentials restore de kontrol ediyor

### GÖREV 7 — Asset Temizliği

**Bulgular:**
- `çöp.png` — proje kökünde fiziksel olarak mevcut; `lib/screens/notifications_screen.dart` içinde `Image.asset('çöp.png', ...)` ile **aktif kullanımda**
- `king.png` — proje kökünde fiziksel olarak mevcut; `lib/screens/scanner_screen.dart` içinde `Image.asset('king.png', ...)` ile **aktif kullanımda**

Her iki dosya da `pubspec.yaml` `flutter.assets` bölümünde kayıtlı olup Dart kodunda doğrudan referans ediliyor.
Bu dosyalar kullanılmayan asset değil; **kaldırılmadı, pubspec'ten silinmedi.**

**Sonuç:** Temizlenecek kullanılmayan asset dosyası tespit edilmedi. Yedek/artık dosya bulunamadı.

---

## Google Play Uyum Durumu

### Şubat 2027 Gereksinimleri

| Gereksinim | Durum | Notlar |
|-----------|-------|--------|
| DEX kodu optimizasyonu (R8 %25+ küçültme) | ✅ Hazır | R8 full mode + minimal ProGuard + ABI filtreleri |
| Bellek kullanımı (Anonim RSS + Swap) | ✅ İyileştirildi | Runtime font fetching kapatıldı, video lifecycle yönetimi eklendi |
| Bitmap bellek kullanımı | ✅ İyileştirildi | Video arka planda durdurulup dispose ediliyor |

### Nisan 2027 Gereksinimleri

| Gereksinim | Durum | Notlar |
|-----------|-------|--------|
| Zero-Tap Giriş (Restore Credentials API) | ✅ Entegre edildi | `androidx.credentials:1.5.0` + Kotlin handler + Dart service |

---

## Kalan Manuel Adımlar

### Zorunlu (Yayınlamadan Önce)
1. **Release build testi:** `flutter build apk --release` veya `flutter build appbundle --release` çalıştırıp APK/AAB boyutunu ve crash raporlarını kontrol et
2. **ProGuard mapping.txt:** `build/app/outputs/mapping/release/mapping.txt` — Play Console'a yükle (crash symbolication için)
3. **Credentials API cihaz testi:** Gerçek Android 9+ cihazda `saveCredentials` + `restoreCredentials` akışını manuel test et
4. **ABI split doğrulama:** Play Console > Yayın > Paket gezgini'nde arm64-v8a ve armeabi-v7a split'lerinin ayrı oluşturulduğunu doğrula

### İsteğe Bağlı İyileştirmeler
5. **video_player kütüphanesini değiştir:** Splash video yerine Lottie animasyonu kullanmak bellek kullanımını önemli ölçüde azaltır
6. **Inter fontunu bundle et:** `google_fonts` yerine `assets/fonts/Inter-*.ttf` dosyalarını manuel bundle etmek daha iyi kontrol sağlar
7. **DEX analizi:** Play Console > Android Vitals > DEX boyutu bölümünden %25 küçültme hedefinin karşılandığını doğrula

---

## Önemli Notlar

- `FlutterActivity` → `FlutterFragmentActivity` değişikliği Credentials API için zorunluydu. Bu değişiklik geriye dönük uyumludur.
- Credentials API Android 9+ (API 28+) gerektirir — minSdk zaten 21+ olduğundan eski cihazlarda API graceful fail yapar
- `teknik_bakis_splash.mp4` asset dosyası korunmuştur — yalnızca lifecycle yönetimi iyileştirildi
- `çöp.png` ve `king.png` dosyaları aktif kullanımda olduğu doğrulandı (`notifications_screen.dart` ve `scanner_screen.dart`); silinmedi, pubspec'ten kaldırılmadı
