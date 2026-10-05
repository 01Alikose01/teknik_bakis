# Zorunlu Güncelleme Sistemi Araştırma Raporu

**Proje:** Teknik Bakış  
**Tarih:** 2025  
**Araştırma kapsamı:** Force update / zorunlu güncelleme mekanizması

---

## ÖZET CEVAP

**Zorunlu güncelleme sistemi YARI TAMAMLANMIŞ durumda.**

- `in_app_update: ^5.0.0` paketi `pubspec.yaml`'a eklenmiş ve `lib/services/update_service.dart` servis dosyası yazılmış.
- Ancak bu servis **hiçbir yerde çağrılmıyor** — `main.dart`, `splash_screen.dart` veya başka hiçbir dosya `UpdateService`'i import etmiyor.
- Sistem şu an **işlevsiz (dead code)** durumunda: paket yüklü, kod yazılmış, ama entegre edilmemiş.

---

## BULGULAR VE KANIT

### 1. pubspec.yaml — Paket Durumu

**Dosya:** `pubspec.yaml`

```yaml
in_app_update: ^5.0.0
```

Satır 21'de `in_app_update: ^5.0.0` mevcut. Bu, Google Play In-App Updates API'sini saran resmi Dart paketi. Paket `pubspec.lock`'ta da kayıtlı olduğundan bağımlılık indirilmiş durumda.

Diğer güncelleme/sürüm kontrol paketleri **bulunmadı:**
- ❌ `upgrader` — yok
- ❌ `firebase_remote_config` — yok
- ❌ `package_info_plus` — yok (sürüm karşılaştırması için kullanılabilecek paket)

### 2. update_service.dart — Servis Dosyası

**Dosya:** `lib/services/update_service.dart`

Tam içerik okundu. Servis şu mantıkla çalışıyor:

```dart
import 'package:in_app_update/in_app_update.dart';

class UpdateService {
  static Future<void> checkForUpdate(BuildContext context) async {
    if (!Platform.isAndroid) return;

    final info = await InAppUpdate.checkForUpdate();

    if (info.updateAvailability == UpdateAvailability.updateAvailable) {
      if (info.immediateUpdateAllowed) {
        // Zorunlu güncelleme — tam ekran indirme akışı
        await InAppUpdate.performImmediateUpdate();
      } else if (info.flexibleUpdateAllowed) {
        // İsteğe bağlı güncelleme — dialog göster
        _showFlexibleUpdateDialog(context);
      }
    }
  }
}
```

**Servisin özellikleri:**
- Sadece Android'de çalışır (`Platform.isAndroid` guard var).
- Google Play'in `immediateUpdateAllowed` bayrağına göre zorunlu/isteğe bağlı karar verir.
- Zorunlu modda (`immediateUpdate`): `InAppUpdate.performImmediateUpdate()` çağrılır — bu Google Play'in tam ekran zorunlu güncelleme akışını başlatır, kullanıcı bu ekranı kapatamazsa uygulama kapanır.
- İsteğe bağlı modda (`flexibleUpdate`): `barrierDismissible: false` olan bir AlertDialog gösterilir. Ancak "Sonra" butonu var — yani diyalog **kapatılabilir**, zorunlu değil.

**Flexible dialog'un içeriği:**
- Başlık: "Güncelleme Mevcut"
- İçerik: "Teknik Bakış'ın yeni bir sürümü yayınlandı. En iyi deneyim için lütfen uygulamayı güncelleyin."
- Butonlar: "Sonra" (kapatır) ve "Güncelle" (FlexibleUpdate başlatır)

### 3. Entegrasyon Durumu — KRİTİK BULGU

**Dosya:** `lib/main.dart`

`main()` fonksiyonu şu servisleri başlatıyor:
```dart
await PortfolioService.init();
await SettingsService.init();
await SubscriptionService.init();
PurchaseService.init();
await HomePriceCache.init();
await NotificationService.init();
await Bist100Service.init();
PriceSyncService.start();
await InAppReviewService.init();  // ← In-App Review başlatılıyor
// UpdateService.checkForUpdate() ← YOK
```

`UpdateService` ne `main.dart`'ta ne de başka herhangi bir dosyada import edilmiyor veya çağrılıyor.

Grep sonucu: `import.*update_service` için **sıfır eşleşme** (update_service.dart'ın kendi import satırı hariç).

**Dosya:** `lib/screens/splash_screen.dart`

Splash ekranında yalnızca video oynatma ve ana ekrana geçiş var. Sürüm kontrolü veya `UpdateService` çağrısı **bulunmuyor.**

### 4. Firebase Remote Config

Firebase Remote Config paketi **yok.** `pubspec.yaml`'da `firebase_remote_config` bağımlılığı bulunmuyor. Proje Firestore kullanıyor (`cloud_firestore: ^5.6.12`) ama Remote Config kullanmıyor.

Minimum sürüm bilgisinin uzaktan alınmasına dair hiçbir kod bulunamadı.

### 5. Google Play'e Yönlendirme

`update_service.dart`'ta doğrudan Play Store URL yönlendirmesi yok. Zorunlu güncelleme akışı Google Play'in kendi UI'ını (`performImmediateUpdate`) kullandığından ayrı bir `url_launcher` ihtiyacı doğmuyor.

`in_app_review_service.dart`'ta Play Store URL'i (`https://play.google.com/store/apps/details?id=com.teknikbakis.teknik_bakis`) mevcut, ancak bu yorum amaçlı ve update ile ilgisiz.

### 6. Minimum Sürüm Kontrolü

Sabit kodlanmış minimum sürüm veya versionCode karşılaştırması **yok.** `pubspec.yaml`'daki uygulama versiyonu `1.0.0+36432`, ama bu yalnızca uygulama kendi sürümü — bir minimum sürüm eşiği tanımlanmamış.

Güncelleme kararı tamamen Google Play'e bırakılmış: `immediateUpdateAllowed` ve `flexibleUpdateAllowed` bayrakları Play Console'dan yönetilir (developer console'da "Update priority" ayarı ile).

---

## SONUÇLAR

| Soru | Yanıt |
|------|-------|
| Zorunlu güncelleme sistemi VAR mı? | **YARI VAR** — Kod yazılmış ama entegre edilmemiş |
| Hangi dosyada çalışıyor? | `lib/services/update_service.dart` — ama çağrılmıyor |
| Hangi minimum version kontrol ediliyor? | Yok — sabit eşik tanımlanmamış, Play Console'a bırakılmış |
| Firebase Remote Config kullanılıyor mu? | **Hayır** |
| Google Play'e yönlendiriyor mu? | Google Play'in kendi UI'ı kullanılıyor (performImmediateUpdate) |
| Sistem gerçekten zorunlu mu? | ImmediateUpdate modu gerçekten zorunlu, ama şu an tetiklenmiyor |

---

## ÖNERİLER

### Acil: Servisi Entegre Et

`UpdateService.checkForUpdate(context)` çağrısı olmadığı için sistem şu an **hiç çalışmıyor.** İki seçenek:

**Seçenek A — Splash Screen Sonrası (Önerilen):**
`SplashScreen._navigateToHome()` içinde, ana ekrana geçmeden önce çağrılabilir. Ancak bu noktada context manipülasyonu dikkat gerektirir.

**Seçenek B — MainNavigation.initState() içinde:**
```dart
// lib/main.dart içindeki MainNavigationState.initState()
WidgetsBinding.instance.addPostFrameCallback((_) async {
  if (context.mounted) {
    await UpdateService.checkForUpdate(context);
  }
});
```

### Play Console Ayarı

`immediateUpdateAllowed` bayrağı Google Play Console'daki **"In-app update priority"** değerine bağlı (0–5 arası). Priority 4 veya 5 olduğunda immediate update zorunlu hale gelir. Bu ayar Play Console'dan yönetilir, kodda değil.

### Firebase Remote Config ile Minimum Sürüm (İsteğe Bağlı)

Eğer uzaktan minimum sürüm kontrolü isteniyorsa, `firebase_remote_config` paketi eklenip `min_version` gibi bir key ile sürüm karşılaştırması yapılabilir. Şu an bu mekanizma mevcut değil.
