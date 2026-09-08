// Bu dosya `flutterfire configure` komutuyla otomatik oluşturulur.
// Aşağıdaki adımları çalıştır:
//
//   dart pub global activate flutterfire_cli
//   flutterfire configure
//
// Komut firebase_options.dart'ı gerçek değerlerle doldurur.
// Şu an derleme hatasını engellemek için boş placeholder.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) throw UnsupportedError('Web desteklenmiyor');
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError('Bu platform desteklenmiyor');
    }
  }

  // ── Gerçek değerleri `flutterfire configure` doldurur ──────────────────

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyA1eB1Z0ut0QFtTvXdTi0NqGGdhG9eBaJg',
    appId: '1:68388088590:android:f9ea8947bd58ba7a31c55f',
    messagingSenderId: '68388088590',
    projectId: 'teknik-bakis',
    storageBucket: 'teknik-bakis.firebasestorage.app',
  );
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey:            'REPLACE_WITH_REAL_VALUE',
    appId:             'REPLACE_WITH_REAL_VALUE',
    messagingSenderId: 'REPLACE_WITH_REAL_VALUE',
    projectId:         'REPLACE_WITH_REAL_VALUE',
    storageBucket:     'REPLACE_WITH_REAL_VALUE',
    iosBundleId:       'REPLACE_WITH_REAL_VALUE',
  );
}
