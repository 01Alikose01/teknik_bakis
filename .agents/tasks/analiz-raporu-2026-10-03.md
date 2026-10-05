# Teknik Bakış — Analiz Raporu (2026-10-03)

Analiz tarihi: 2026-10-03  
Analiz edilen branch: mevcut workspace (`d:\k\wink\teknik_bakis`)  
Değiştirilen dosya: **YOK** (read-only inceleme)

---

## SORU 1: ZORUNLU GÜNCELLEME

### DURUM
❌ **KRİTİK — `UpdateService.checkForUpdate()` hiçbir zaman çağrılmıyor.**

### SORUNUN NEDENİ
`UpdateService` sınıfı tam ve çalışır durumda yazılmış, ancak hiçbir ekran veya başlatma noktasında çağrılmıyor. Servis yalnızca kendi dosyasında tanımlı; `import` bile edilmiyor.

Kanıt — tüm `.dart` dosyaları taranıldı, `checkForUpdate` yalnızca şurada bulundu:
```
lib/services/update_service.dart   ← tanım (sadece burada)
```
`main.dart`, `splash_screen.dart`, `home_screen.dart` veya başka hiçbir yerde çağrı yok.

### İLGİLİ DOSYA
- `lib/services/update_service.dart` — servisin tanımı
- `lib/main.dart` — çağrılması gereken yer (şu an çağrılmıyor)
- `lib/screens/splash_screen.dart` — alternatif tetikleme noktası (şu an kullanılmıyor)

### İLGİLİ FONKSİYON
```dart
// lib/services/update_service.dart
static Future<void> checkForUpdate(BuildContext context) async { ... }
```

### MEVCUT KOD ÇALIŞIR DURUMDA MI?
Evet. Kod mantıksal olarak doğru:
- `Platform.isAndroid` guard var (iOS'ta atlar)
- `InAppUpdate.checkForUpdate()` → `updateAvailability` kontrol ediyor
- `immediateUpdateAllowed` → `performImmediateUpdate()` (zorunlu)
- `flexibleUpdateAllowed` → `_showFlexibleUpdateDialog()` (isteğe bağlı, Türkçe dialog var)
- Tüm hatalar `try/catch` ile sessizce geçiliyor
- `context.mounted` kontrolü var

**Tek sorun: hiç çağrılmaması.**

### ÖNERİLEN ÇÖZÜM
`MainNavigationState.initState()` içine, `WidgetsBinding.instance.addPostFrameCallback` ile ekle:

```dart
// lib/main.dart — MainNavigationState.initState() içine eklenecek
import 'package:teknik_bakis/services/update_service.dart'; // ← import ekle

WidgetsBinding.instance.addPostFrameCallback((_) {
  UpdateService.checkForUpdate(context);
});
```

`initState`'e eklemek, uygulama her açıldığında splash bittikten hemen sonra kontrol yapmasını sağlar. `SplashScreen` yerine `MainNavigation` tercih edilmeli — `SplashScreen`'de `context` henüz mount olmamış olabilir ve splash süresi sınırlı.

---

## SORU 2: GERİ TUŞU

### DURUM
❌ **KRİTİK — "Uygulamadan çıkmak istiyor musunuz?" dialogu kodda hiç yok.**

### SORUNUN NEDENİ
İki iç içe sorun var:

**Sorun A — Çıkış dialogu implement edilmemiş**

`_onPopInvoked()` fonksiyonu `return true` döndürüyor (son satır), ama bu dönüş değeri `onPopInvokedWithResult` callback'i tarafından **kullanılmıyor**:

```dart
// lib/main.dart — satır 225-230
return PopScope(
  canPop: false,                               // ← POP ASLA OLMAZ
  onPopInvokedWithResult: (didPop, _) {
    if (!didPop) {
      _onPopInvoked();                         // ← dönüş değeri yok sayılıyor
    }
  },
```

`_onPopInvoked()` bir `bool` döndürüyor (`return true` → "uygulamayı kapat"), ama çağıran kod bu değeri okumuyorsa hiçbir etkisi yok. `canPop: false` sabit olduğundan sistem hiçbir zaman gerçek pop yapmıyor.

**Sorun B — Çıkış dialogu çağrısı yok**

Tüm kaynak kodu tarandı; `SystemNavigator.pop()`, `exit(0)` veya "Uygulamadan çıkmak" içeren bir dialog çağrısı **kodun hiçbir yerinde bulunmuyor**. Bu özellik daha önce eklenmiş gibi görünse de (`_onPopInvoked`'un `return true` satırı ipucu veriyor), dialog kodu ya hiç yazılmamış ya da silinmiş.

**Sorun C — `_tabHistory` birikimi ile "geri bastıkça history tükeniyor" yanılsaması**

Kullanıcı 6-7 kez geri basıyor ve uygulama tab geçişleri yapıyor (history'den sekme değiştiriyor). Tüm history bitince `_onPopInvoked` `return true` veriyor — ama bu değer okunmadığından dialog yerine hiçbir şey olmayı beklememek gerekir; davranış şu:

| Durum | Kod | Sonuç |
|---|---|---|
| `_tabHistory` dolu | `_currentIndex = _tabHistory.removeLast()` | Tab değişir |
| `_tabHistory` boş, aktif tab ≠ 0 | `_currentIndex = 0` | Ana sayfaya döner |
| `_tabHistory` boş, aktif tab = 0 | `return true` (değer OKUNMUYOR) | Hiçbir şey olmaz |

Son durumda `canPop: false` olduğundan sistem pop yapmaz, dönüş değeri ignore edildiğinden dialog gösterilmez → **uygulama askıda kalır, ne geri gider ne çıkar.**

### İLGİLİ DOSYA
- `lib/main.dart`

### İLGİLİ FONKSİYONLAR
```dart
// lib/main.dart

bool _onPopInvoked() {   // ← return değeri çağrıdan okunmuyor
  if (_tabHistory.isNotEmpty) { ... return false; }
  if (_currentIndex != 0)     { ... return false; }
  return true;  // ← buraya gelince hiçbir şey olmuyor
}

// PopScope — canPop: false hardcoded
onPopInvokedWithResult: (didPop, _) {
  if (!didPop) {
    _onPopInvoked();  // ← return değeri kullanılmıyor
  }
},
```

### ÖNERİLEN ÇÖZÜM
`_onPopInvoked`'un `return true` koluna bir çıkış dialogu ekle. `canPop` dinamik hale getirilmesine gerek yok — sadece dialog göster:

```dart
bool _onPopInvoked() {
  if (_tabHistory.isNotEmpty) {
    setState(() => _currentIndex = _tabHistory.removeLast());
    return false;
  }
  if (_currentIndex != 0) {
    setState(() => _currentIndex = 0);
    return false;
  }
  // Ana sayfadayız — çıkış dialogu göster
  _showExitDialog();
  return false;
}

void _showExitDialog() {
  showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Çıkış'),
      content: const Text('Uygulamadan çıkmak istiyor musunuz?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Hayır'),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(ctx).pop(true);
            SystemNavigator.pop(); // veya exit(0)
          },
          child: const Text('Evet'),
        ),
      ],
    ),
  );
}
```

`import 'dart:io';` (`exit`) veya `import 'package:flutter/services.dart';` (`SystemNavigator`) gerekli — `SystemNavigator.pop()` tercih edilir, Android back-stack'i doğru kapatır.

---

## SORU 3: YILDIZ / UYGULAMA DEĞERLENDİRME

### DURUM
⚠️ **KISMI — Servis tam ve doğru yazılmış, tetiklenme koşulları kısıtlayıcı. Testte görünmüyor çünkü koşullar sağlanmıyor.**

### SORUNUN NEDENİ

`InAppReviewService` (`lib/services/in_app_review_service.dart`) Google Play In-App Review API kullanıyor, custom dialog yok. Ancak tetiklenme için 3 koşulun aynı anda sağlanması gerekiyor:

| Koşul | Değer | Açıklama |
|---|---|---|
| `_minCompletedAnalyses` | **3** | En az 3 AI analiz tamamlanmalı |
| `_minDaysBetweenRequests` | **30** | Son requestten bu yana 30 gün geçmeli |
| `_maxReviewRequests` | **3** | Toplam en fazla 3 kez istenir |

**Tetiklenme akışı:**
1. `analiz_screen.dart` → AI analiz başarıyla tamamlanınca `InAppReviewService.onAnalysisCompleted()` çağrılıyor ✅
2. Sayaç artar → `_maybeRequestReview()` koşulları kontrol eder
3. Koşullar sağlanırsa `_requestReview()` → `InAppReview.instance.requestReview()` çağrılır

**Neden testte görünmüyor?**

1. **Sayaç 3'e ulaşmadı** — test sırasında 3'ten az AI analiz yapıldı.
2. **Google Play politikası** — `requestReview()` çağrılsa bile Google, dialog penceresinin açılıp açılmayacağına karar verir. Geliştirici modunda (`debug build`, `internal testing track` dışı) hiçbir zaman açılmaz.
3. **`isAvailable()` false dönüyor** — emulatörde veya Play Store'a bağlı olmayan cihazda her zaman false döner.
4. **30 gün koşulu** — eğer daha önce bir kez tetiklendiyse, 30 gün dolmadan tekrar tetiklenmez.

**İkili çağrı sorunu (analiz_screen.dart):**
Grep çıktısında satır 1124'te `onAnalysisCompleted()` iki kez göründü — kod incelemesinde gerçekte **tek çağrı** olduğu doğrulandı (grep context overlap'i yanıltıcıydı). Tek çağrı var, bug yok.

**Manuel tetikleme (Ayarlar ekranı):**
`settings_screen.dart` → "Uygulamayı Değerlendir" butonu → `InAppReviewService.openStoreListing()` çağırıyor ✅  
Bu akış her zaman Play Store sayfasını açar (in-app review penceresine bağlı değil).

### İLGİLİ DOSYA
- `lib/services/in_app_review_service.dart` — servisin tamamı
- `lib/screens/analiz_screen.dart` — `onAnalysisCompleted()` tetikleyicisi (~satır 1124)
- `lib/screens/settings_screen.dart` — "Uygulamayı Değerlendir" (~satır 115)
- `lib/main.dart` — `InAppReviewService.init()` çağrısı (satır 37)

### İLGİLİ FONKSİYONLAR
```dart
// Otomatik tetikleyici — analiz_screen.dart ~1124
InAppReviewService.onAnalysisCompleted();

// Koşul kontrolü — in_app_review_service.dart
static Future<void> _maybeRequestReview() async { ... }

// Google Play çağrısı
await _inAppReview.requestReview();

// Manuel tetikleyici — settings_screen.dart ~115
onTap: () => InAppReviewService.openStoreListing()
```

### ÖNERİLEN ÇÖZÜM

**Test için:**
- `InAppReviewService.resetForTesting()` çağır, ardından 3 AI analiz yap.
- Gerçek cihazda, **Google Play Internal Testing** kanalında test yap — emülatör ve debug build'de `isAvailable()` her zaman false döner.
- `debugPrintStatus()` ile mevcut sayaçları kontrol et.

**Üretim iyileştirmesi (isteğe bağlı):**
Eğer ilk tetiklenmenin daha hızlı gerçekleşmesi isteniyorsa:
- `_minCompletedAnalyses` değerini 3'ten 1'e indir (ilk analizden sonra tetiklensin).
- `_minDaysBetweenRequests` değerini 7 güne indir.
Bu değişiklikler Google Play politikasıyla çelişmez.

**Mevcut kod üretim için yeterli mi?**  
Evet, kod doğru ve politikaya uygun. Sadece koşulların bilinçli olarak yüksek tutulduğunu anlamak gerekiyor.

---

## ÖZET TABLO

| # | Konu | Durum | Aciliyet |
|---|---|---|---|
| 1 | Zorunlu Güncelleme (`checkForUpdate`) | ❌ Hiç çağrılmıyor | YÜKSEK |
| 2 | Geri Tuşu çıkış dialogu | ❌ Dialog kodu yok, `canPop` sabit false | YÜKSEK |
| 3 | Yıldız / Değerlendirme | ⚠️ Çalışıyor, test koşulları sağlanmıyor | DÜŞÜK |

**En kritik sorun:** 1 ve 2 numaralı maddeler kullanıcı deneyimini doğrudan etkiliyor — güncelleme sessizce atlanıyor, uygulama geri tuşuyla kapatılamıyor.
