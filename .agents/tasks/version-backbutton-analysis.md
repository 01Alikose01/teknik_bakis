# Teknik Bakış — Version & Geri Tuşu Analiz Raporu

**Tarih:** 2025-07-11  
**Durum:** Salt-okunur analiz — hiçbir dosya değiştirilmedi.

---

## 1. Version Bilgileri

### pubspec.yaml

| Alan | Değer |
|------|-------|
| `version:` | `1.0.0+1` |
| Flutter version string | `1.0.0` |
| Build number (versionCode) | `1` |

**Dosya:** `pubspec.yaml`, satır 4:
```yaml
version: 1.0.0+1
```

### Android build.gradle.kts

**Dosya:** `android/app/build.gradle.kts`

`versionCode` ve `versionName` doğrudan gradle'da yazılı **değil** — Flutter plugin'inin değerlerine yönlendiriliyor:

```kotlin
defaultConfig {
    versionCode = flutter.versionCode   // pubspec.yaml'daki build number → 1
    versionName = flutter.versionName   // pubspec.yaml'daki version → "1.0.0"
}
```

Bu demek oluyor ki projenin her yerinde tek kaynak `pubspec.yaml`'daki `version: 1.0.0+1` satırıdır.

### pubspec.lock — Resolved Sürümler

`pubspec.lock` içinde doğrulanan gerçek resolved sürümler:

| Paket | pubspec.yaml (istenen) | pubspec.lock (gerçek) |
|-------|------------------------|------------------------|
| `in_app_purchase` | `^3.2.0` | **3.3.1** |
| `in_app_purchase_android` | `^0.5.3` | **0.5.3** |
| `in_app_purchase_platform_interface` | (transitive) | **1.4.1** |
| `in_app_purchase_storekit` | (transitive) | **0.4.13** |

---

## 2. In-App Purchase & Billing Library

### pubspec.yaml'daki IAP paketleri

```yaml
in_app_purchase: ^3.2.0          # resolved → 3.3.1
in_app_purchase_android: ^0.5.3   # resolved → 0.5.3
```

### Gerçek Kullanılan Billing Library Sürümü

`android/app/build.gradle.kts` içinde `billingclient` bağımlılığı **yok**. Tüm gradle dosyaları tarandı:

- `android/app/build.gradle.kts` — billingclient yok
- `android/build.gradle.kts` — billingclient yok
- `android/settings.gradle.kts` — billingclient yok
- `android/gradle.properties` — billingclient yok

**`com.android.billingclient:billing:8.0.0` gradle'da doğrudan tanımlanmamış.**

Billing Library bağımlılığı, `in_app_purchase_android` Flutter paketinin kendi içinde (Maven/pub üzerinden) transitif olarak taşınıyor. `pubspec.lock`'ta resolve edilen `in_app_purchase_android: 0.5.3`, [pub.dev'e göre](https://pub.dev/packages/in_app_purchase_android/versions/0.5.3) Google Play Billing Library **7.x** serisini kullanır — 8.0.0 değil.

> **Özet:** `com.android.billingclient:billing:8.0.0` bu projede doğrudan kullanılmıyor. Kullanılan IAP paketi (`in_app_purchase_android 0.5.3`) büyük ihtimalle Billing Library 7.x'e bağımlı.

---

## 3. Play Console Karşılaştırma & Öneri

### Mevcut Durum

| Kaynak | version | versionCode |
|--------|---------|-------------|
| **Play Console Alpha** | `1.0.0` | `24+36431` (çok yüksek) |
| **pubspec.yaml** | `1.0.0` | `1` |
| **Gradle** | `flutter.versionName` → `1.0.0` | `flutter.versionCode` → `1` |

### Sorun

Play Console'daki `versionCode` **24+36431** çok yüksek. Bu, eski bir build sisteminden veya CI/CD'den gelen bir sayı olabilir. Google Play'e yüklenen her yeni AAB'nin `versionCode`'u mevcut en yüksek değerden **büyük** olması gerekir.

### Öneri (dosyaya yazmadan, sadece öneri)

Mevcut `versionCode = 1` olan `pubspec.yaml`'ı doğrudan güncellemek yanlış olur çünkü Play'deki mevcut `versionCode` çok daha yüksek (≈ 24+36431 = bu notasyon alışılmadık; muhtemelen 36455 veya benzeri).

**Önerilen pubspec.yaml değişikliği:**

```yaml
# ESKİ:
version: 1.0.0+1

# YENİ (önerim):
version: 1.0.1+36456    # versionCode Play'deki değerden 1 fazla olmalı
```

- `versionName`: `1.0.1` — kullanıcıya yansıyan sürüm; küçük bir artış yeterli
- `versionCode (build number)`: Play Console'daki mevcut `versionCode`'u bul (AAB yönetiminde görünür), ona +1 ekle
- Play Console'daki `24+36431` ifadesi standart değil; kontrol edin, gerçek `versionCode` 36432 veya benzeri olabilir

> **Not:** Bu değerleri pubspec.yaml'a yazmadım. Yeni AAB oluşturmadan önce Play Console'dan kesin `versionCode`'u doğrulayın ve `pubspec.yaml`'daki `+` sonrasındaki sayıyı o değerin 1 fazlası yapın.

---

## 4. Navigation Yapısı

### Routing Paketi

`pubspec.yaml` ve tüm `.dart` dosyaları tarandı:

- **GoRouter / AutoRoute / go_router kullanılmıyor.**
- Proje **Flutter'ın kendi Navigator + MaterialPageRoute** yapısını kullanıyor.
- `navigatorKey: appNavigatorKey` ile global bir `NavigatorState` tutuluyor.

### Uygulama Akışı

```
SplashScreen (video)
  └─→ pushReplacement
        └─→ MainNavigation (PopScope ile sarılmış)
              ├─ HomeScreen       (index 0) ← ana ekran
              ├─ ScannerScreen    (index 1)
              ├─ AnalizScreen     (index 2)
              ├─ NewsScreen       (index 3)
              ├─ IpoScreen        (index 4)
              └─ SettingsScreen   (index 5)
```

### Bottom Navigation

`MainNavigation` widget'ında 6 sekmeli `BottomNavigationBar` var. Sekmeler `IndexedStack` ile gösteriliyor (widget'lar dispose olmaz, bellekte yaşar).

### Sekme Geçiş Geçmişi

`_tabHistory: List<int>` ile gezilen sekme geçmişi tutuluyor. Geri tuşuna basıldığında son ziyaret edilen sekmeye dönüyor.

### Modal/Overlay Navigasyon

Alt ekranlar (PaymentScreen, PremiumGateScreen, NotificationsScreen, WatchlistScreen vb.) standart `MaterialPageRoute` ile `Navigator.push` / `Navigator.pop` üzerinden açılıyor.

---

## 5. Geri Tuşu Mevcut Durum

### Mevcut `PopScope` Kullanımı

**Tek yer:** `lib/main.dart` içindeki `MainNavigationState.build()`:

```dart
return PopScope(
  canPop: false,                        // Her koşulda pop engelleniyor
  onPopInvokedWithResult: (didPop, _) {
    if (!didPop) {
      _onPopInvoked();
    }
  },
  child: Scaffold( ... ),
);
```

`_onPopInvoked()` metodu:

```dart
bool _onPopInvoked() {
  if (_tabHistory.isNotEmpty) {
    setState(() {
      _currentIndex = _tabHistory.removeLast();
    });
    return false; // sekme geçmişinde geri git
  }
  if (_currentIndex != 0) {
    setState(() => _currentIndex = 0);
    return false; // ana sekmeye git
  }
  return true; // ana sayfadayız — uygulamayı kapat
}
```

**Sorun:** `_onPopInvoked()` `true` döndürdüğünde (ana sekmede + geçmiş boş) `canPop: false` nedeniyle uygulama **kapatılmıyor** — `true` dönüşü yalnızca mantıksal, gerçek pop gerçekleşmiyor. Başka bir deyişle, şu an ana sekmede geri tuşuna basıldığında **hiçbir şey olmuyor** (uygulamadan çıkılmıyor).

### Diğer Dosyalarda PopScope / WillPopScope Kullanımı

- Diğer hiçbir screen dosyasında `PopScope` veya `WillPopScope` yok.
- Alt ekranlar standart `Navigator.pop(context)` ile kapanıyor (beklenen davranış).

### Mevcut Davranışın Özeti

| Durum | Mevcut Davranış |
|-------|-----------------|
| Alt sekme açıkken geri | Önceki sekmeye döner ✓ |
| Ana sekmede geri | Hiçbir şey olmaz (hatalı) ✗ |
| Uygulama kapanma | Asla olmuyor ✗ |
| Dialog / confirm | Yok ✗ |

---

## 6. Geri Tuşu Uygulama Noktaları

İstenen davranış:
- Normal sayfalarda geri tuşu normal çalışsın (mevcut alt ekranlarda zaten çalışıyor)
- **Ana/son ekranda** (MainNavigation, index 0, geçmiş boş) ilk 5 geri basışta uygulama kapanmasın
- 6. basışta "Uygulamadan çıkmak istiyor musunuz?" dialog göster
- Evet → kapat, Hayır → açık kal + sayaç sıfırla

### Tek Değiştirilmesi Gereken Dosya

**`lib/main.dart`** — `MainNavigationState` sınıfı.

### Yapılacak Değişiklikler (kod yok, sadece açıklama)

#### 1. Sayaç değişkeni ekle

`MainNavigationState` içine bir `int _backPressCount = 0;` değişkeni ekle.

#### 2. Zamanlayıcı ekle (opsiyonel ama önerilen)

`Timer? _backPressTimer;` — Belirli bir süre (ör. 10 saniye) sonra sayacı sıfırlamak için. Kullanıcı 6 geri tuşuna basma girişimini tek seferde yaparsa mantıklı, dağınık basmalar sayılmasın.

#### 3. `_onPopInvoked()` metodunu güncelle

Mevcut `return true;` olan dalı değiştir:

- `_backPressCount` artır
- `_backPressCount < 6` ise: hiçbir şey yapma (engelle), isteğe bağlı `SnackBar` göster (ör. "5 defa daha geri basın")
- `_backPressCount >= 6` ise: `showDialog` ile "Uygulamadan çıkmak istiyor musunuz?" göster
  - **Evet:** `SystemNavigator.pop()` veya `exit(0)` çağır
  - **Hayır:** `_backPressCount = 0` sıfırla

#### 4. `canPop: false` korunmalı

`PopScope(canPop: false, ...)` değişmemeli — mevcut sekme geçmişi mantığı bozulmamalı.

#### 5. Import eklenmeli

`dart:async` (Timer için) ve `dart:io` veya `package:flutter/services.dart` (`SystemNavigator.pop()` için).

### Değişecek Satır Aralığı

`lib/main.dart` → `MainNavigationState` sınıfı:
- Alan: yaklaşık satır 150–235 (sınıf değişkenleri + `_onPopInvoked` + `build`)
- Eklenti minimal: ~20-30 satır

### Diğer Dosyalar

**Hiçbir diğer dosyanın değiştirilmesi gerekmez.** Tüm mantık `MainNavigationState` içine sığar.

### Dikkat Edilmesi Gerekenler

1. `SplashScreen → MainNavigation` geçişi `pushReplacement` ile yapılıyor; Navigator stack'inde `SplashScreen` yok. Dolayısıyla `MainNavigation`'dan bir üst route'a pop yapılması beklenmiyor — `canPop: false` doğru.
2. `_tabHistory` zaten geçmişi yönetiyor; yeni sayaç sadece "tüm sekme geçmişi boş + index 0" durumunda devreye girecek.
3. `SystemNavigator.pop()` Android'de uygulamayı sonlandırmak için en temiz yol. `exit(0)` alternatif ama Flutter'ın lifecycle yönetimine uymaz.

---

*Rapor sonu. Hiçbir kaynak dosya değiştirilmedi.*
