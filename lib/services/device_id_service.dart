import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Cihaza özgü kalıcı kimlik üretir ve saklar.
/// Android: Settings.Secure.ANDROID_ID
/// iOS    : identifierForVendor
/// Kimlik SecureStorage'a da yazılır — yeniden yükleme koruması için.
class DeviceIdService {
  static const _storageKey = 'device_unique_id';
  static const _storage = FlutterSecureStorage();

  static String? _cached;

  static Future<String> getDeviceId() async {
    if (_cached != null) return _cached!;

    // Önce SecureStorage'a bak
    try {
      final stored = await _storage.read(key: _storageKey);
      if (stored != null && stored.isNotEmpty) {
        _cached = stored;
        return _cached!;
      }
    } catch (_) {}

    // Cihaz bilgisinden üret
    final info = DeviceInfoPlugin();
    String id;

    try {
      if (Platform.isAndroid) {
        final android = await info.androidInfo;
        id = android.id; // Settings.Secure.ANDROID_ID
      } else if (Platform.isIOS) {
        final ios = await info.iosInfo;
        id = ios.identifierForVendor ?? _fallback();
      } else {
        id = _fallback();
      }
    } catch (_) {
      id = _fallback();
    }

    // SecureStorage'a kaydet
    try {
      await _storage.write(key: _storageKey, value: id);
    } catch (_) {}

    _cached = id;
    return _cached!;
  }

  static String _fallback() =>
      'fallback_${DateTime.now().millisecondsSinceEpoch}';
}
