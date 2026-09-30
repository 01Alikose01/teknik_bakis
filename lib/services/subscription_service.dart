import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'device_id_service.dart';

/// Abonelik durumunu ve deneme süresini yöneten servis.
/// Hive box'ı kullanır — kalıcı depolama.
class SubscriptionService {
  static const String _boxName = 'subscription';
  static const int freeAlarmLimit = 5;

  // Box key'leri
  // `plan` yalnızca ücretli plan bilgisidir. Trial, trialStart ile bağımsız
  // olarak takip edilir.
  static const String _kPlan = 'plan'; // 'monthly'|'yearly'|'guest'|'none'
  static const String _kTrialStart =
      'trialStart'; // ISO8601 — 10 günlük deneme başlangıcı
  static const String _kOnboarded = 'onboarded'; // bool

  static late Box<dynamic> _box;
  static bool _initialized = false;

  static Future<void> init() async {
    if (!_initialized) {
      _box = await Hive.openBox<dynamic>(_boxName);
      _initialized = true;
    }

    await _startTrialForNewUserIfNeeded();
    // Google Play Developer API ile doğrulanmış hakları arka planda senkronize et
    syncWithBackendEntitlements();
  }

  /// Cloud Firestore `entitlements/{deviceId}` kaydı ile cihazın yerel abonelik
  /// durumunu senkronize eder. Google Play Developer API tarafından onaylanmış haklar
  /// geçerli kabul edilir.
  static Future<void> syncWithBackendEntitlements() async {
    try {
      final deviceId = await DeviceIdService.getDeviceId();
      final doc = await FirebaseFirestore.instance
          .collection('entitlements')
          .doc(deviceId)
          .get()
          .timeout(const Duration(seconds: 5));

      if (doc.exists) {
        final data = doc.data();
        final isActive = data?['isActive'] == true;
        final planKey = (data?['plan'] as String?) ?? 'monthly';
        final expiryStr = data?['expiryTime'] as String?;

        bool isStillValid = isActive;
        if (expiryStr != null) {
          final expiry = DateTime.tryParse(expiryStr);
          if (expiry != null && DateTime.now().isAfter(expiry)) {
            isStillValid = false;
          }
        }

        if (isStillValid) {
          await _box.put(_kPlan, planKey);
        } else if (isPaidSubscriber) {
          await cancelPaidSubscription();
        }
      }
    } catch (_) {
      // Offline durumlarda yerel Hive durumu korunur
    }
  }

  // ─── Onboarding ───────────────────────────────────────────────────────────

  static bool get isOnboarded => _initialized
      ? (_box.get(_kOnboarded, defaultValue: false) as bool)
      : false;

  static Future<void> markOnboarded() => _box.put(_kOnboarded, true);

  // ─── Plan başlatma ────────────────────────────────────────────────────────

  /// Ücretli planı etkinleştirir (Google Play doğrulaması sonrası).
  /// Trial başlangıcına dokunmaz; trial ve paid entitlement bağımsızdır.
  static Future<void> startPaidSubscription(String planKey) async {
    await _box.put(_kPlan, planKey);
    await markOnboarded();
  }

  /// Abonelik sona erdiğinde çağrılır.
  static Future<void> cancelPaidSubscription() async {
    await _box.put(_kPlan, 'none');
  }

  /// Ayarlar'dan aylık plan seçildi
  static Future<void> selectMonthlyPlan() => startPaidSubscription('monthly');

  /// Ayarlar'dan yıllık plan seçildi
  static Future<void> selectYearlyPlan() => startPaidSubscription('yearly');

  /// 10 günlük ücretsiz denemeyi, daha önce başlamamışsa başlatır.
  /// Trial başlangıcı kaydedilmişse hiçbir zaman güncellenmez.
  static Future<void> startGuestTrial() async {
    if (_box.get(_kTrialStart) == null) {
      await _box.put(_kTrialStart, DateTime.now().toIso8601String());
    }
    await markOnboarded();
  }

  /// İlk kez uygulamayı kullanan kullanıcıya trial'ı otomatik tanımlar.
  /// Eski ücretsiz (`guest`) kayıtlar ile mevcut ücretli kayıtlar korunur.
  static Future<void> _startTrialForNewUserIfNeeded() async {
    if (_box.get(_kTrialStart) != null) return;
    if (plan != 'none') return;
    await startGuestTrial();
  }

  // ─── Durum sorguları ──────────────────────────────────────────────────────

  /// 'monthly' | 'yearly' | 'guest' | 'none'
  static String get plan => _initialized
      ? (_box.get(_kPlan, defaultValue: 'none') as String)
      : 'none';

  static DateTime? get trialStart {
    if (!_initialized) return null;
    final raw = _box.get(_kTrialStart) as String?;
    return raw != null ? DateTime.tryParse(raw) : null;
  }

  static int get daysSinceTrial {
    final start = trialStart;
    if (start == null) return 999;
    return DateTime.now().difference(start).inDays;
  }

  /// Deneme süresi aktif mi?
  static bool get isInFreeTrial {
    if (trialStart == null) return false;
    return daysSinceTrial < 10;
  }

  /// Ücretli abone mi?
  static bool get isPaidSubscriber => plan == 'monthly' || plan == 'yearly';

  /// Deneme süresi bitmiş ve ücretli erişimi olmayan kullanıcı mı?
  static bool get isExpiredGuest =>
      trialStart != null && !isInFreeTrial && !isPaidSubscriber;

  /// Ücretsiz plana geçilmiş mi?
  static bool get isFreePlanSelected => !hasPremiumAccess && !isPaidSubscriber;

  /// Kaç gün kaldı?
  static int get trialDaysLeft {
    final left = 10 - daysSinceTrial;
    return left < 0 ? 0 : left;
  }

  /// Tüm premium özelliklere erişim var mı?
  /// Koşul: Ücretli abone VEYA 10 günlük deneme süresi içinde
  static bool get hasPremiumAccess => isPaidSubscriber || isInFreeTrial;

  static bool get isInTrial => isInFreeTrial && !isPaidSubscriber;

  /// Daha önce deneme başlatılmış mı? (onboarding'de "Misafir" seçeneğini gizlemek için)
  static bool get hasUsedTrialBefore => trialStart != null;

  // ─── Özellik erişim kontrolü ──────────────────────────────────────────────

  static const String kProductMonthly = 'premium_monthly';
  static const String kProductYearly = 'premium_yearly';

  /// Her zaman ücretsiz olan özellikler (deneme bittikten sonra da erişilebilir)
  static const List<String> freeFeatures = [
    'home', // Anasayfa
    'analiz', // Teknik analiz grafiği (temel)
  ];

  /// Premium gerektiren özellikler
  static const List<String> premiumFeatures = [
    'scanner', // Tarama (tüm filtreler)
    'news', // Haberler & KAP
    'alarms', // Sınırsız alarm
    'kap', // KAP AI
    'signals', // Sinyaller
  ];

  static bool canAccess(String feature) {
    if (hasPremiumAccess) return true;
    return freeFeatures.contains(feature);
  }

  /// Deneme/paid erişimi yokken açık kalan mevcut Scanner filtreleri.
  /// Filtre hesaplaması değil, yalnızca erişim kararı burada merkezileştirilir.
  static const Set<String> freeScannerFilters = {
    'MACD Bullish',
    'Golden Cross',
    'Death Cross',
  };

  static bool canUseScannerFilter(String filterId) =>
      hasPremiumAccess || freeScannerFilters.contains(filterId);

  static bool canCreateAlarm(int currentAlarmCount) =>
      hasPremiumAccess || currentAlarmCount < freeAlarmLimit;

  // ─── Sıfırlama ────────────────────────────────────────────────────────────

  /// Ücretsiz plan seçimi trial kaydını değiştirmez. Aktif trial, kendi 10
  /// günlük süresi dolana kadar erişim vermeye devam eder.
  static Future<void> selectFreePlan() async {
    await _box.put(_kPlan, 'guest');
    await markOnboarded();
  }

  static Future<void> reset() async {
    if (!_initialized) return;
    await _box.clear();
  }
}
