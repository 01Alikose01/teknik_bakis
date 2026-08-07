import 'package:hive_flutter/hive_flutter.dart';

/// Abonelik durumunu ve deneme süresini yöneten servis.
/// Hive box'ı kullanır — kalıcı depolama.
class SubscriptionService {
  static const String _boxName = 'subscription';
  static const int freeAlarmLimit = 5;

  // Box key'leri
  static const String _kPlan = 'plan'; // 'monthly'|'yearly'|'guest'|'none'
  static const String _kTrialStart =
      'trialStart'; // ISO8601 — 10 günlük deneme başlangıcı
  static const String _kOnboarded = 'onboarded'; // bool

  static late Box<dynamic> _box;
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    _box = await Hive.openBox<dynamic>(_boxName);
    _initialized = true;
  }

  // ─── Onboarding ───────────────────────────────────────────────────────────

  static bool get isOnboarded => _initialized
      ? (_box.get(_kOnboarded, defaultValue: false) as bool)
      : false;

  static Future<void> markOnboarded() => _box.put(_kOnboarded, true);

  // ─── Plan başlatma ────────────────────────────────────────────────────────

  /// Ücretli plan seçimi — 10 günlük trial + plan kaydeder.
  static Future<void> startPaidSubscription(String planKey) async {
    await _box.put(_kPlan, planKey);
    await _box.put(_kTrialStart, DateTime.now().toIso8601String());
    await markOnboarded();
  }

  /// Ayarlar'dan aylık plan seçildi
  static Future<void> selectMonthlyPlan() => startPaidSubscription('monthly');

  /// Ayarlar'dan yıllık plan seçildi
  static Future<void> selectYearlyPlan() => startPaidSubscription('yearly');

  /// Misafir olarak devam — 10 günlük ücretsiz deneme başlar.
  /// Trial başlangıcı kaydedilmişse güncellenmez (uygulama silinip kurulmadıkça).
  static Future<void> startGuestTrial() async {
    await _box.put(_kPlan, 'guest');
    // Daha önce başlatılmamışsa şimdi başlat
    if (_box.get(_kTrialStart) == null) {
      await _box.put(_kTrialStart, DateTime.now().toIso8601String());
    }
    await markOnboarded();
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

  /// Deneme süresi aktif mi? (plan başlamış ve 10 gün dolmamış)
  static bool get isInFreeTrial {
    if (plan == 'none') return false;
    if (trialStart == null) return false;
    return daysSinceTrial < 10;
  }

  /// Ücretli abone mi?
  static bool get isPaidSubscriber => plan == 'monthly' || plan == 'yearly';

  /// Deneme süresi bitmiş misafir mi?
  static bool get isExpiredGuest => plan == 'guest' && !isInFreeTrial;

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

  static bool canCreateAlarm(int currentAlarmCount) =>
      hasPremiumAccess || currentAlarmCount < freeAlarmLimit;

  // ─── Sıfırlama ────────────────────────────────────────────────────────────

  /// Deneme hakkı kullanılmış, ücretsiz modda devam et
  static Future<void> selectFreePlan() async {
    await _box.put(_kPlan, 'guest'); // plan 'guest' kalır, trial bitmiş sayılır
    await markOnboarded();
  }

  static Future<void> reset() async {
    if (!_initialized) return;
    await _box.clear();
  }
}
