import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cihaza özgü kalıcı kimlik üretir ve saklar.
///
/// Öncelik sırası:
///   1. Android: Settings.Secure.ANDROID_ID — uygulama silinse de değişmez
///   2. iOS    : identifierForVendor
///   3. FlutterSecureStorage — cihaz kimliği başarıyla alındıktan sonra cache
///   4. SharedPreferences — SecureStorage başarısız, cihaz kimliği exception
///      verdiğinde ikinci kalıcı katman (not: uygulama silinince kaybolur,
///      edge case koruması olarak kullanılır)
///   5. Yeni UUID — hiçbir kaynak çalışmazsa üretilir, her iki depoya yazılır
class DeviceIdService {
  static const _storageKey = 'device_unique_id';
  static const _storage = FlutterSecureStorage();

  static String? _cached;

  static Future<String> getDeviceId() async {
    if (_cached != null) return _cached!;

    // 1. SecureStorage'a bak (en hızlı yol — cihaz kimliği daha önce okunmuşsa)
    try {
      final stored = await _storage.read(key: _storageKey);
      if (stored != null && stored.isNotEmpty) {
        _cached = stored;
        return _cached!;
      }
    } catch (_) {}

    // 2. Cihaz kimliğini doğrudan oku (kalıcı kaynak)
    final info = DeviceInfoPlugin();
    String? id;

    try {
      if (Platform.isAndroid) {
        final android = await info.androidInfo;
        id = android.id; // Settings.Secure.ANDROID_ID — yeniden kurulumda değişmez
      } else if (Platform.isIOS) {
        final ios = await info.iosInfo;
        id = ios.identifierForVendor;
      }
    } catch (_) {
      // Cihaz kimliği okunamadı — aşağıdaki fallback katmanları devreye girer
    }

    // 3. Cihaz kimliği alınamazsa SharedPreferences'tan okumayı dene
    //    (SecureStorage şifresi bozulmuş ama uygulama silinmemişse bu çalışır)
    if (id == null || id.isEmpty) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final stored = prefs.getString(_storageKey);
        if (stored != null && stored.isNotEmpty) {
          id = stored;
        }
      } catch (_) {}
    }

    // 4. Hiçbir kaynaktan kimlik alınamadı — yeni UUID üret
    if (id == null || id.isEmpty) {
      id = _generateFallbackId();
    }

    // Üretilen/okunan kimliği her iki depoya kaydet
    try {
      await _storage.write(key: _storageKey, value: id);
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, id);
    } catch (_) {}

    _cached = id;
    return _cached!;
  }

  /// Deterministic olmayan UUID benzeri fallback — yalnızca tüm kaynaklar
  /// başarısız olduğunda kullanılır. SharedPreferences'a da yazıldığından
  /// uygulama silinmediği sürece aynı kalır.
  static String _generateFallbackId() {
    final ts = DateTime.now().millisecondsSinceEpoch;
    return 'fallback_$ts';
  }
}
