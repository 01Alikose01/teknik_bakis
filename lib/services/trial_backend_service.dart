import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'device_id_service.dart';

/// Firestore'dan dönen trial senkronizasyon sonucu.
///
/// [backendReachable] false ise diğer alanlar anlamsızdır — backend'e
/// ulaşılamadığından trial kararı verilemez.
class TrialSyncResult {
  final bool backendReachable;
  final String? trialStart;
  final bool trialConsumed;

  const TrialSyncResult({
    required this.backendReachable,
    this.trialStart,
    this.trialConsumed = false,
  });

  /// Backend'e ulaşılamadı — trial başlatılmamalı.
  static const TrialSyncResult offline = TrialSyncResult(backendReachable: false);
}

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
  ///
  /// Dönüş değerleri:
  /// - [TrialSyncResult.backendReachable] == false: offline/hata — trial başlatma
  /// - [TrialSyncResult.trialConsumed] == true: trial daha önce kullanılmış — başlatma
  /// - [TrialSyncResult.trialConsumed] == false: trial henüz kullanılmamış — başlatılabilir
  static Future<TrialSyncResult> syncTrial() async {
    try {
      final deviceId = await DeviceIdService.getDeviceId();
      final ref = _db.collection(_col).doc(deviceId);

      final doc = await ref.get().timeout(const Duration(seconds: 6));

      if (doc.exists) {
        // Kayıt mevcut → trialStart ve trialConsumed döndür
        final data = doc.data();
        final trialStart = data?['trialStart'] as String?;
        final trialConsumed = (data?['trialConsumed'] as bool?) ?? false;
        return TrialSyncResult(
          backendReachable: true,
          trialStart: trialStart,
          trialConsumed: trialConsumed,
        );
      } else {
        // Yeni cihaz → kayıt oluştur (consumed=false, yeni trial hakkı)
        final trialStart = DateTime.now().toUtc().toIso8601String();
        await ref.set({
          'trialStart': trialStart,
          'trialConsumed': false,
          'platform': _platform(),
          'createdAt': FieldValue.serverTimestamp(),
        });
        return TrialSyncResult(
          backendReachable: true,
          trialStart: trialStart,
          trialConsumed: false,
        );
      }
    } catch (_) {
      // Offline veya hata → backend erişilemez, trial başlatılamaz
      return TrialSyncResult.offline;
    }
  }

  /// Trial tüketildi olarak işaretle (10 gün bitti).
  /// Hata durumunda sessizce geçer — bir sonraki açılışta tekrar denenecek.
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
