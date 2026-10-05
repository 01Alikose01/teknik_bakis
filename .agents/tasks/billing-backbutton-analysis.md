# Billing & Geri Tuşu Analiz Raporu

## KONU 1: in_app_purchase_android Billing Library Versiyonu

### Özet Sonuç

`in_app_purchase_android` **0.5.3** paketi, Google Play Billing Library'nin **8.0.0** versiyonunu kullanıyor. Bu bilgi doğrudan kaynak dosyadan okunmuştur, tahmin değildir.

---

### Kanıt — Kaynak Dosyalar

#### 1. pubspec.yaml (proje bağımlılığı)

```
Dosya: d:\k\wink\teknik_bakis\pubspec.yaml
  in_app_purchase_android: ^0.5.3
```

#### 2. pubspec.lock (çözümlenmiş exact versiyon)

```
Dosya: d:\k\wink\teknik_bakis\pubspec.lock
  in_app_purchase_android:
    version: "0.5.3"
```

#### 3. Pub Cache — build.gradle.kts (asıl Gradle bağımlılığı)

```
Dosya: C:\Users\k\AppData\Local\Pub\Cache\hosted\pub.dev\in_app_purchase_android-0.5.3\android\build.gradle.kts
```

İlgili `dependencies` bloğu (dosyadan aynen okundu):

```kotlin
dependencies {
    implementation("androidx.annotation:annotation:1.10.0")
    implementation("com.android.billingclient:billing:8.0.0")      // <-- BİLLİNG VERSİYONU
    testImplementation("junit:junit:4.13.2")
    testImplementation("org.json:json:20251224")
    testImplementation("org.mockito:mockito-core:5.23.0")
    testImplementation("androidx.test:core:1.7.0")
    testImplementation("org.robolectric:robolectric:4.16")
    androidTestImplementation("androidx.test:runner:1.7.0")
    androidTestImplementation("androidx.test.espresso:espresso-core:3.7.0")
}
```

**Sonuç: `com.android.billingclient:billing:8.0.0` — doğrulandı.**

---

### Projenin Android Gradle Dosyaları

Projenin kendi `android/` dizininde ayrıca billing ile ilgili bir override veya `implementation` satırı **yok**.

| Dosya | İçerik özeti |
|---|---|
| `android/build.gradle.kts` | Sadece repo tanımları ve build dir ayarı; billing bağımlılığı yok |
| `android/app/build.gradle.kts` | AGP 9.0.1, Kotlin 2.3.20, desugar_jdk_libs:2.1.4, core-splashscreen:1.0.1; billing yok |
| `android/settings.gradle.kts` | Plugin loader, AGP 9.0.1, Kotlin 2.3.20 |

Dolayısıyla projenin kendi build.gradle dosyaları billing bağımlılığını override etmiyor; 8.0.0 sürümü tamamen plugin cache'inden geliyor.

---

## KONU 2: Geri Tuşu Navigasyon Analizi

### Özet Sonuç

Proje saf Flutter `Navigator` (no go_router, no auto_route) kullanıyor. Geri tuşu yönetimi **tek merkezde**: `lib/main.dart` içindeki `MainNavigationState.build()` → `PopScope` widget'ı. Kullanıcının istediği davranışı uygulamak için yalnızca `main.dart` dosyasındaki `_onPopInvoked()` metodu ve `_tabHistory` listesi değiştirilmeli.

---

### 1. Hangi navigasyon paketi kullanılıyor?

**Saf Flutter `Navigator` + `MaterialPageRoute`.**

- `pubspec.yaml`'da `go_router`, `auto_route`, `beamer` gibi bir paket yok.
- Tüm ekran geçişleri `Navigator.of(context).push(MaterialPageRoute(...))` ile yapılıyor.
- `MaterialApp`'ta `navigatorKey: appNavigatorKey` tanımlanmış (overlay/alarm için); route tablosu yok.

---

### 2. Mevcut PopScope/WillPopScope/BackButtonDispatcher yapısı

Dosya: `lib/main.dart` — `MainNavigationState.build()` metodu (satır ~223)

```dart
return PopScope(
  canPop: false,
  onPopInvokedWithResult: (didPop, _) {
    if (!didPop) {
      _onPopInvoked();
    }
  },
  child: Scaffold(...)
);
```

`_onPopInvoked()` metodu (satır ~178):

```dart
bool _onPopInvoked() {
  if (_tabHistory.isNotEmpty) {
    setState(() {
      _currentIndex = _tabHistory.removeLast();
    });
    return false; // pop yapma, biz hallettik
  }
  if (_currentIndex != 0) {
    setState(() => _currentIndex = 0);
    return false; // ana sayfaya git
  }
  return true; // ana sayfadayız, uygulamayı kapat
}
```

`_tabHistory` listesi (satır ~148):

```dart
final List<int> _tabHistory = [];
```

**WillPopScope yok** — modern `PopScope`+`canPop: false` yaklaşımı kullanılmış. Bu Flutter 3.16+ ile uyumlu.

---

### 3. Alt sekmeler (BottomNavigationBar) nerede?

`MainNavigationState` içinde, `build()` metodunun `Scaffold.bottomNavigationBar` parametresi olarak tanımlanmış (`lib/main.dart`).

6 sekme: Anasayfa (0), Tarama (1), Analiz (2), Haberler (3), Halka Arz (4), Ayarlar (5).

Sekme değişimi iki yerden tetikleniyor:
1. `BottomNavigationBar.onTap` — doğrudan `_pushTab(i)` + `setState`
2. `AppNavigation.goToTab(index)` servisi — `initState`'de kayıt edilen `_setTab` callback'i üzerinden

Her iki yol da `_pushTab()` metodunu çağırıyor ve sekme geçmişine mevcut sekmeyi ekliyor.

---

### 4. Geri tuşu şu an nerede/nasıl handle ediliyor?

Tek nokta: `lib/main.dart`, `MainNavigationState`, `_onPopInvoked()`.

**Mevcut davranış:**
- `_tabHistory` doluysa → son sekmeye geri dön (sınırsız geçmiş)
- `_tabHistory` boşsa ve `_currentIndex != 0` → index 0'a git (Anasayfa)
- `_currentIndex == 0` ise → `return true` (uygulamayı kapat — sistem pop'una izin verir, dialog yok)

**Eksikler mevcut yapıda:**
1. `_tabHistory` için **maksimum 5 sınırı yok** — sınırsız büyüyor
2. **"Uygulamadan çıkmak istiyor musunuz?" dialog'u yok** — 6. geri basışta veya ana sayfada geri basışta direk kapanıyor
3. `return true` dönüşü pop'a izin verirken `PopScope.canPop: false` ile çelişiyor — bu bug değil, Flutter mekanizması gereği: `_onPopInvoked()` `true` döndürmeli ama `canPop: false` olduğundan pop gerçekleşmeyecek. Yani şu an ana sayfada geri basınca dialog yerine hiçbir şey olmuyor gibi görünüyor (ya da sistem uygulamayı arka plana alıyor). Bu kesin olarak test edilmeli.

---

### 5. Hangi dosyaya müdahale edilmeli?

**Tek dosya: `lib/main.dart`** — `MainNavigationState` sınıfı.

Başka hiçbir dosyaya dokunmak gerekmez:
- `MainActivity.kt`: Back tuşunu override etmiyor, saf Flutter'a bırakıyor. Değişiklik gerekmez.
- Alt sekmeler zaten `main.dart`'ta yönetiliyor.
- Diğer ekranlar modal push/pop yapıyor (`Navigator.push` / `Navigator.pop`), bunlar `PopScope`'u etkilemiyor — `canPop: false` olan `MainNavigation`'ın pop stack'i; modal ekranlar kendi navigator stack entry'lerini pop ediyor.

---

### 6. Önerilen Yaklaşım

**Değiştirilecek dosya:** `lib/main.dart`  
**Değiştirilecek alan:** `MainNavigationState` sınıfı

#### Yapılacak değişiklikler:

**a) `_tabHistory` için 5 limit:**

`_pushTab()` metoduna `_tabHistory.length >= 5` olunca baştan bir eleman at:

```dart
void _pushTab(int index) {
  if (_currentIndex != index) {
    if (_tabHistory.length >= 5) {
      _tabHistory.removeAt(0); // en eski geçmişi at
    }
    _tabHistory.add(_currentIndex);
  }
}
```

**b) `_onPopInvoked()` — dialog + geçmiş sıfırlama:**

`_tabHistory` boşken (6. geri basış veya ana sayfadan geri basış) dialog göster:

```dart
Future<void> _onPopInvoked() async {
  // Önce sekme geçmişini tüket
  if (_tabHistory.isNotEmpty) {
    setState(() {
      _currentIndex = _tabHistory.removeLast();
    });
    return;
  }
  // Ana sayfada değilsek ana sayfaya dön
  if (_currentIndex != 0) {
    setState(() => _currentIndex = 0);
    return;
  }
  // Ana sayfadayız ve geçmiş bitti — çıkış dialog'u
  _showExitDialog();
}

void _showExitDialog() {
  showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Çıkış'),
      content: const Text('Uygulamadan çıkmak istiyor musunuz?'),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(ctx).pop();
            // Geçmişi sıfırla — "Hayır" durumu
            setState(() => _tabHistory.clear());
          },
          child: const Text('Hayır'),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(ctx).pop();
            // Uygulamayı kapat
            SystemNavigator.pop();
          },
          child: const Text('Evet'),
        ),
      ],
    ),
  );
}
```

**c) `onPopInvokedWithResult` return type uyarlaması:**

Mevcut `bool _onPopInvoked()` → `Future<void> _onPopInvoked()` olarak değiştirilmeli (dialog async). `onPopInvokedWithResult` callback'i zaten `void` döndürüyor, `await` gerekmiyor.

**d) `PopScope`'ta değişiklik yok:**  
`canPop: false` kalmalı. `SystemNavigator.pop()` Android sistem seviyesinde uygulamayı kapatır.

**e) Import ekle:**  
`import 'package:flutter/services.dart';` zaten `main.dart`'ta mevcut (satır 2).

---

### Neden başka dosya değiştirilmiyor?

- Modal ekranlar (`BacktestScreen`, `TradingViewScreen`, `NewsDetailScreen` vb.) kendi stack entry'lerini pop ediyorlar. `MainNavigation`'ın `PopScope`'u sadece kök route kapandığında tetikleniyor, modal ekranlar önce kendi pop'larını tüketiyor.
- `AppNavigation` servisi yalnızca tab setter callback'i tutuyor; `_pushTab` mekanizması değişmeden bu servis çalışmaya devam eder.
- Android tarafında `onBackPressed()` override'ı yok, `MainActivity.kt` tamamen Flutter'a devredilmiş — Kotlin değişikliği gerekmez.

---

### Özet Tablo

| Konu | Dosya | Değişiklik |
|---|---|---|
| 5 sekme limiti | `lib/main.dart` → `_pushTab()` | `_tabHistory` 5'i aşınca baştan sil |
| Çıkış dialog'u | `lib/main.dart` → `_onPopInvoked()` | `_showExitDialog()` ekle |
| Hayır → sıfırla | `lib/main.dart` → `_showExitDialog()` | `_tabHistory.clear()` |
| Evet → kapat | `lib/main.dart` → `_showExitDialog()` | `SystemNavigator.pop()` |
| MainActivity.kt | Değişiklik yok | — |
| Diğer screen'ler | Değişiklik yok | — |
