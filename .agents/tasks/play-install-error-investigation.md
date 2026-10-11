# Google Play "Yüklenemedi" Hatası — Araştırma Raporu

**Tarih:** 2026-10-10  
**Uygulama:** Teknik Bakış (`com.teknikbakis.teknik_bakis`)  
**Mevcut Versiyon:** `1.1.0+36433` (HEAD → main, commit `65aca0c`)

---

## Özet Yanıt (Önce Sonuç)

**En olası neden: versionCode sıçrama anomalisi.**  
Uygulamanın ilk Play Store sürümü `versionCode = 1` iken yayınlanmış olabilir. Mevcut sürüm ise `versionCode = 36433`. Bu tek başına sorun değildir, ama **bu versiyondan önce Play'e yüklenmiş olan sürüm `1.0.0+36432` iken**, ilk ever-yayınlanan sürüm `1.0.0+1` idi — yani araya giren commit geçmişi Play Store'a yansımamış olabilir.

**İkinci en olası neden: Google Play App Signing ile yerel imza uyumsuzluğu.**  
Uygulama, Play Console'da **Google Play App Signing** (Google imzalama) etkinleştirilmeden yüklenmiş olabilir. Bu durumda Play, APK/AAB'yi kendi anahtarıyla yeniden imzalamaz; cihazda yüklü olan versiyonun imzası ile yeni sürümün imzası eşleşmezse kurulum "INSTALL_FAILED_UPDATE_INCOMPATIBLE" hatasıyla başarısız olur.

**Üçüncü risk: `storeFile` mutlak Windows yolu.**  
`key.properties` dosyasındaki `storeFile=D:/k/wink/teknik_bakis/android/app/teknik_bakis_release.jks` değeri mutlak bir Windows yoludur. CI/CD veya farklı bir makinede build alınırsa bu yol bulunamaz ve build sessizce `debug` imzayla ya da imzasız üretilir. Böyle bir AAB'nin Play'e yüklenmesi veya üretim cihazlarına dağıtımı kurulum hatasına yol açar.

---

## Bulgular ve Kanıtlar

### 1. versionCode ve versionName

**Kaynak:** `pubspec.yaml` (HEAD, commit `65aca0c`)

```
version: 1.1.0+36433
```

`versionName = 1.1.0`, `versionCode = 36433`.

`android/app/build.gradle.kts` satır 33-34:
```kotlin
versionCode = flutter.versionCode
versionName = flutter.versionName
```
Değerler Flutter araçzinciri üzerinden `pubspec.yaml`'dan okunuyor. Build zamanında doğru aktarıldığı varsayılır.

**versionCode geçmişi (git log):**

| Commit | Tarih | versionCode |
|--------|-------|-------------|
| `4549fbc` (baseline) | 2026-09-29 | `1` (`1.0.0+1`) |
| `b029aeb` (Billing 8.0.0) | 2026-10-03 | `36432` (`1.0.0+36432`) |
| `65aca0c` (HEAD) | 2026-10-10 | `36433` (`1.1.0+36433`) |

**Kritik Gözlem:** `1.0.0+1` → `1.0.0+36432` sıçraması tek bir commit'te yapıldı. Eğer Play Store'a **`1.0.0+1`** yüklenmiş ve ardından **`1.1.0+36433`** yüklendiyse, versionCode açısından `1 → 36433` geçişi teknik olarak geçerlidir (artmış). Ancak **araya `36432` yüklendiyse**, `36432 → 36433` de geçerli. Yani versionCode tek başına sorun gibi görünmüyor; fakat Play Console'dan hangi sürümün aktif üretimde olduğu doğrulanmalıdır.

---

### 2. İmza (Signing) Konfigürasyonu

**`android/app/build.gradle.kts`:**
```kotlin
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}
// ...
signingConfigs {
    create("release") {
        keyAlias = keystoreProperties["keyAlias"] as String
        keyPassword = keystoreProperties["keyPassword"] as String
        storeFile = keystoreProperties["storeFile"]?.let { file(it) }
        storePassword = keystoreProperties["storePassword"] as String
    }
}
buildTypes {
    release {
        signingConfig = signingConfigs.getByName("release")
        // ...
    }
}
```

**`android/key.properties`** (var, git'te takip edilmiyor — doğru):
- `keyAlias=teknik_bakis`
- `storeFile=D:/k/wink/teknik_bakis/android/app/teknik_bakis_release.jks`
- Şifreler mevcut.

**`android/app/teknik_bakis_release.jks`** — `app/` dizininde fiziksel olarak mevcut (dosya boyutu: 2788 byte). Git'te takip edilmiyor (`.gitignore` ile hariç tutulmuş — doğru).

**⚠️ Risk 1 — Mutlak Windows Yolu:**  
`storeFile=D:/k/wink/teknik_bakis/android/app/teknik_bakis_release.jks`  
Bu yol yalnızca bu makinede geçerlidir. `rootProject.file(it)` ile birleşince Gradle çalışma dizinine göre değil tam yola göre çözümlenir. Farklı bir makinede ya da CI'da bu yol bulunamazsa `keystorePropertiesFile.exists()` kontrolü `false` döner ve imzalama konfigürasyonu boş kalabilir. Bu senaryoda build **debug imzasıyla** üretilebilir; debug-imzalı bir AAB Play'de **yüklenirse** (ki genellikle reddedilir), cihazda zaten release-imzalı sürüm varsa "INSTALL_FAILED_UPDATE_INCOMPATIBLE" alınır.

**⚠️ Risk 2 — Google Play App Signing Durumu Bilinmiyor:**  
Play Console'da App Signing etkinleştirilmişse (`upload key` ≠ `app signing key`), cihazlara giden AAB Google'ın anahtarıyla imzalanır. Bu durumda yerel JKS sadece "yükleme anahtarı" olarak kullanılır ve kullanıcı cihazında imza tutarlılığı Google tarafından yönetilir — bu senaryoda imza sorunu **olmaz**. 

Eğer App Signing **etkin değilse** ve yerel JKS direkt imzalama anahtarıysa, anahtarın değiştirilmemiş olması gerekir. JKS oluşturulma tarihi `22.09.2026 11:35` (commit `4549fbc`'den önce) — bu tutarlı görünüyor.

---

### 3. SDK Versiyonları

`build.gradle.kts` içinde doğrudan değer verilmemiş; hepsi Flutter SDK'dan alınıyor:
```kotlin
compileSdk = flutter.compileSdkVersion
minSdk = flutter.minSdkVersion
targetSdk = flutter.targetSdkVersion
```

Flutter SDK bu değerleri `flutter.compileSdkVersion`, `flutter.minSdkVersion`, `flutter.targetSdkVersion` olarak sunar. Ayrıca `pubspec.yaml`'daki `flutter_launcher_icons` altında:
```yaml
min_sdk_android: 21
```

Bu değerler mevcut Flutter versiyonunda tipik olarak:
- `minSdk = 21`
- `targetSdk = 35` (Flutter 3.32+ varsayılanı)
- `compileSdk = 35`

Play Store 2024+ politikasına göre `targetSdkVersion >= 34` zorunludur — bu gereksinim karşılanıyor olmalıdır (Flutter SDK otomatik ayarlıyor). SDK versiyonları kurulum hatasının nedeni olarak düşük olasılıklı.

---

### 4. AndroidManifest.xml

`android/app/src/main/AndroidManifest.xml` incelendi:

- **Package name yok** — namespace `build.gradle.kts` içinde `com.teknikbakis.teknik_bakis` olarak tanımlı. Manifest'te `package` attribute artık Gradle namespace'den geliyor (modern yaklaşım, doğru).
- **applicationId = `com.teknikbakis.teknik_bakis`** — değişmemiş.
- `android:exported="true"` MainActivity üzerinde mevcut — zorunlu ve doğru.
- İzinler: INTERNET, POST_NOTIFICATIONS, RECEIVE_BOOT_COMPLETED, VIBRATE, BILLING — normal.
- `EnableImpeller = false` meta-data var (emülatör sorunları için eklenmiş).
- Manifest'te kurulum hatasını tetikleyecek anormal bir değişiklik yok.

---

### 5. Build Tipi ve Proguard

**Build tipi:** `flutter build appbundle --release` → `bundleRelease` Gradle task'ı çalışıyor.

**`aab_out.txt`** (en son başarılı build):
```
Running Gradle task 'bundleRelease'...
√ Built build\app\outputs\bundle\release\app-release.aab (64.7MB)
```
AAB başarıyla oluşturulmuş. Release tipi ve boyut (64.7 MB) makul.

**Proguard/R8:**
```kotlin
isMinifyEnabled = true
isShrinkResources = true
proguardFiles(
    getDefaultProguardFile("proguard-android-optimize.txt"),
    "proguard-rules.pro"
)
```

`proguard-rules.pro` içeriği incelendi — Flutter, Firebase, Hive, Billing için `-keep` kuralları mevcut. Play Core split install sınıfları için `-dontwarn` eklenmiş (bu, `in_app_update` paketinin Play Core'a olan referansını susturmak için). Bu yapılandırma görünürde sorunsuz, ancak R8 optimizasyonu yeni eklenen bir sınıfı agresif şekilde kaldırmışsa **runtime crash** olabilir — bu "Yüklenemedi" değil açılış sonrası crash olarak görünür.

---

### 6. Git Geçmişi — İmza/Versiyon ile İlgili Değişiklikler

İmzalama veya manifest'i doğrudan etkileyen commit bulunamadı. `build.gradle.kts` ilk commit'ten (`4549fbc`) bu yana sadece bir kez değişmiş:

**`d04d372` (02.10.2026) — "genel guncellemeler":** Commit mesajında `Android: build.gradle.kts, gradle-wrapper, settings.gradle guncellendi` yazıyor. Bu commit'teki `build.gradle.kts` değişikliği:

Baseline (`4549fbc`) ile mevcut (`HEAD`) arasındaki fark:
- Baseline'da `kotlinOptions { jvmTarget = JavaVersion.VERSION_17.toString() }` bloğu vardı.
- HEAD'de bu blok kaldırılmış, yerine `kotlin { compilerOptions { jvmTarget.set(...) } }` gelmiş.
- `dependencies` bloğuna `coreLibraryDesugaring` ve `splashscreen` eklenmiş.

Bu değişiklikler imzalamayı etkilemiyor.

**`settings.gradle.kts` güncellemesi:** AGP `9.0.1`, Kotlin `2.3.20` versiyonlarına güncellendi. Bu build toolchain güncellemesi pratikte imzalama çıktısını etkilemez.

---

### 7. AAB mi APK mi?

`run_build.bat` ve `aab_out.txt`'e göre: **AAB (App Bundle)** üretiliyor.
```bat
flutter build appbundle --release
```
Bu doğru yaklaşımdır. Play Store AAB'yi tercih eder. Ancak AAB'nin `bundleRelease` task'ıyla imzalandığının doğrulanması gerekir — `aab_out.txt`'te imza doğrulama logu yok, ama `signingConfig = signingConfigs.getByName("release")` release buildType'a bağlı olduğu için normal şartlarda imzalı çıkması gerekir.

---

## Sonuç ve Öneriler

### Birincil Şüpheli: Google Play App Signing Durumu

**Play Console'da App Signing'in aktif olup olmadığını kontrol edin.** Bu en kritik sorudur:

- **Eğer App Signing AÇIK ise:** Google, AAB'yi kendi imza anahtarıyla imzalar. Yerel JKS sadece yükleme doğrulaması için kullanılır. Bu senaryoda "Yüklenemedi" hatası imzadan kaynaklanmıyor olabilir; başka bir nedene bakılmalı (targetSdk, cihaz uyumsuzluğu vb).

- **Eğer App Signing KAPALI ise:** Yerel JKS kullanılıyor demektir. Bu JKS ile imzalanmış önceki sürüm cihazlarda yüklüyse ve şu anki AAB aynı JKS ile imzalanmışsa sorun olmamalı. Ancak JKS değişmişse veya imzalama farklı bir makine/ortamda yapıldıysa `INSTALL_FAILED_UPDATE_INCOMPATIBLE` alınır.

### İkincil Şüpheli: storeFile Mutlak Yolu

`key.properties` içindeki `storeFile` değerinin **göreli yola** dönüştürülmesi önerilir:

```properties
# Mevcut (riskli):
storeFile=D:/k/wink/teknik_bakis/android/app/teknik_bakis_release.jks

# Önerilen (göreli — key.properties android/ dizininde olduğu için):
storeFile=app/teknik_bakis_release.jks
```

Bu değişiklik, farklı makinede/ortamda build alınırsa yol bulunamaz hatasını önler ve yanlışlıkla imzasız veya debug-imzalı AAB üretilmesini engeller.

### Üçüncül Öneri: AAB İmzasını Doğrulama

Build sonrası AAB'nin gerçekten release anahtarıyla imzalandığını şu komutla doğrulayın:
```powershell
# jarsigner veya apksigner ile
& "$env:ANDROID_HOME\build-tools\<versiyon>\apksigner" verify --verbose --print-certs "build\app\outputs\bundle\release\app-release.aab"
```
ya da:
```powershell
keytool -printcert -jarfile "build\app\outputs\bundle\release\app-release.aab"
```
Çıktıdaki parmak izi Play Console'daki "App signing key certificate" ile eşleşmeli.

### Eylem Adımları (Öncelik Sırasıyla)

1. **Play Console → Setup → App signing** sayfasını açın. "App signing key certificate" SHA-1/SHA-256'sını not alın.
2. Yerel JKS'nin parmak izini `keytool -list -v -keystore android/app/teknik_bakis_release.jks` ile alın.
3. İkisi eşleşiyorsa (veya App Signing aktifse ve upload key eşleşiyorsa) imza sorunu **yoktur**.
4. Eşleşmiyorsa: doğru anahtarla yeniden build alıp Play'e yükleyin; veya App Signing'i etkinleştirin.
5. `key.properties` içindeki `storeFile` yolunu göreli yola dönüştürün (yukarıda gösterildiği gibi).
6. Play Console'da mevcut aktif sürümün `versionCode`'unu kontrol edin — yeni yüklenen `36433` olmalı.

---

## Dışarıda Kalan / Doğrulanamayan Noktalar

- Hangi `versionCode` ile Play'e ilk yükleme yapıldığı bilinmiyor (Play Console erişimi yok).
- AAB'nin gerçekten release anahtarıyla imzalanıp imzalanmadığı doğrulanamadı (build artifactı mevcut ama imza kontrolü yapılmadı).
- Google Play App Signing'in aktif olup olmadığı bilinmiyor (Play Console erişimi yok).
- Kullanıcıların aldığı hata kodu tam olarak belirtilmemiş ("Yüklenemedi" — Android hata kodu `INSTALL_FAILED_*` serisi olabilir; kodun tam değeri teşhisi kesinleştirir).
