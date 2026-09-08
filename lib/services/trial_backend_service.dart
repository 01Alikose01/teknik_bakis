import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'device_id_service.dart';

/// Firestore tabanlı trial koruması.
/// Kullanıcı anonim — kayıt/giriş yok.
/// Her cihaz, deviceId ile bir Firestore dökümanına sahiptir.
///
/// Koleksiyon yapısı:
///   trials/{deviceId}
///     ├── trialStart    : ISO8601 String
///     ├── trialConsumed : bool
///     ├── platform      : 'android' | 'ios'
///     └── createdAt     : Timestamp
class TrialBackendService {
  static final _db = FirebaseFirestore.instance;
  static const _col = 'trials';

  /// Uygulama açılışında çağrılır (SubscriptionService.init içinden).
  /// - Firestore'da kayıt varsa → trialStart string döndürür
  /// - Kayıt yoksa → yeni oluşturur, trialStart döndürür
  /// - Offline/hata → null döndürür (local veri kullanılır)
  static Future<String?> syncTrial() async {
    try {
      final deviceId = await DeviceIdService.getDeviceId();
      final ref = _db.collection(_col).doc(deviceId);

      final doc = await ref.get().timeout(const Duration(seconds: 6));

      if (doc.exists) {
        // Kayıt mevcut → trialStart'ı döndür
        final data = doc.data();
        return data?['trialStart'] as String?;
      } else {
        // Yeni cihaz → kayıt oluştur
        final trialStart = DateTime.now().toUtc().toIso8601String();
        await ref.set({
          'trialStart': trialStart,
          'trialConsumed': false,
          'platform': _platform(),
          'createdAt': FieldValue.serverTimestamp(),
        });
        return trialStart;
      }
    } catch (_) {
      // Offline veya hata → null; local veri geçerli kalır
      return null;
    }
  }

  /// Trial tüketildi olarak işaretle (10 gün bitti)
  static Future<void> markConsumed() async {
    try {
      final deviceId = await DeviceIdService.getDeviceId();
      await _db.collection(_col).doc(deviceId).update({
        'trialConsumed': true,
      }).timeout(const Duration(seconds: 5));
    } catch (_) {}
  }

  static String _platform() {
    try {
      if (Platform.isAndroid) return 'android';
      if (Platform.isIOS) return 'ios';
    } catch (_) {}
    return 'unknown';
  }
}
