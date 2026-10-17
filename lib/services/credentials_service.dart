import 'package:flutter/services.dart';

/// Google Credentials API (Restore Credentials / Zero-Tap) entegrasyonu.
/// Android 9+ (API 28+) destekler. Diğer platformlarda hiçbir şey yapmaz.
class CredentialsService {
  static const _channel =
      MethodChannel('com.teknikbakis.teknik_bakis/credentials');

  /// Kullanıcı adı + şifreyi Android Credentials API'ye kaydeder.
  /// Hata durumunda exception fırlatmak yerine false döner.
  static Future<bool> saveCredentials(
      String username, String password) async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'saveCredentials',
        {'username': username, 'password': password},
      );
      return result ?? false;
    } on PlatformException catch (_) {
      return false;
    }
  }

  /// Kayıtlı kimlik bilgilerini geri yükler.
  /// Başarısızlık veya kayıt yoksa null döner.
  static Future<Map<String, String>?> restoreCredentials() async {
    try {
      final result = await _channel
          .invokeMapMethod<String, String>('restoreCredentials');
      if (result == null ||
          result['username'] == null ||
          result['password'] == null) return null;
      return result;
    } on PlatformException catch (_) {
      return null;
    }
  }

  /// Kaydedilmiş kimlik bilgilerini siler.
  static Future<void> clearCredentials() async {
    try {
      await _channel.invokeMethod<void>('clearCredentials');
    } on PlatformException catch (_) {
      // Hata sessizce yutulur
    }
  }
}
