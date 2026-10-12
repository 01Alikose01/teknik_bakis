import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'device_id_service.dart';
import 'trial_backend_service.dart';

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
  // Firestore'a trialConsumed:true başarıyla yazıldıysa true — tekrar çağrımı önler
  static const String _kConsumedSent = 'consumedSent'; // bool

  static late Box<dynamic> _box;
  static bool _initialized = false;

  static Future<void> init() async {
    if (!_initialized) {
      _box = await Hive.openBox<dynamic>(_boxName);
      _initialized = true;
    }

    // Backend'den trial başlangıcını senkronize et.
    // ZORUNLU: Backend erişilemezse trial başlatılmaz.
    await _syncTrialFromBackend();

    // Trial 10 günü doldurduysa Firestore'a markConsumed yaz.
    await _checkAndMarkConsumed();

    // Google Play Developer API ile doğrulanmış hakları arka planda senkronize et
    syncWithBackendEntitlements();
  }

  /// Firestore trials/{deviceId} kaydından trial durumunu senkronize eder.
  ///
  /// Kurallar:
  ///   1. Backend erişilemezse (offline/hata) → trial başlatma, mevcut Hive korunur.
  ///   2. Backend trialConsumed:true dönüyorsa → trial başlatma.
  ///   3. Backend trialConsumed:false dönüyorsa → trialStart Hive'a yazılır.
  ///
  /// Hive yalnızca CACHE — gerçek kaynak backend'dir.
  static Future<void> _syncTrialFromBackend() async {
    final result = await TrialBackendService.syncTrial();

    if (!result.backendReachable) {
      // Backend'e ulaşılamadı — mevcut Hive değeri korunur, yeni trial başlatılmaz.
      // Hive'da trialStart yoksa kullanıcı premium ekranıyla karşılaşır.
      return;
    }

    if (result.trialConsumed) {
      // Bu cihazda trial daha önce kullanılmış — kesinlikle yeni trial başlatma.
      // Hive'daki trialStart silinmez (geçmiş kayıt korunur), ancak yeni yazmayız.
      return;
    }

    // Backend: eligible (trialConsumed:false) → trialStart Hive'a yaz
    if (result.trialStart != null) {
      final currentLocal = _box.get(_kTrialStart) as String?;
      if (currentLocal != result.trialStart) {
        await _box.put(_kTrialStart, result.trialStart);
      }
    }
  }

  /// Trial 10 günü doldurduysa ve henüz Firestore'a yazılmamışsa markConsumed çağırır.
  /// Lokal _kConsumedSent flag'i ile tekrar tekrar çağrılması önlenir.
  static Future<void> _checkAndMarkConsumed() async {
    if (isPaidSubscriber) return;
    if (_box.get(_kConsumedSent, defaultValue: false) as bool) return;
    if (trialStart == null) return;
    if (daysSinceTrial < 10) return;

    // Trial süresi dolmuş — backend'e yaz
    await TrialBackendService.markConsumed();
    await _box.put(_kConsumedSent, true);
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
        final subscriptionState = data?['subscriptionState'] as String?;

        bool isStillValid;

        if (subscriptionState != null) {
          // Google Play Developer API'den gelen subscription state'e göre karar ver.
          switch (subscriptionState) {
            case 'SUBSCRIPTION_STATE_ACTIVE':
              // Aktif abonelik — premium açık.
              isStillValid = true;
              break;
            case 'SUBSCRIPTION_STATE_IN_GRACE_PERIOD':
              // Ödeme gecikti ama Google Play 3–16 gün grace period tanıyor.
              // Bu sürede premium erişimi korunmalı, kullanıcı cezalandırılmaz.
              isStillValid = true;
              break;
            case 'SUBSCRIPTION_STATE_CANCELED':
              // İptal edildi ama dönem sonu henüz gelmemiş olabilir.
              // expiryTime geçmemişse premium devam eder.
              if (expiryStr != null) {
                final expiry = DateTime.tryParse(expiryStr);
                isStillValid =
                    expiry != null && DateTime.now().isBefore(expiry);
              } else {
                isStillValid = false;
              }
              break;
            case 'SUBSCRIPTION_STATE_ON_HOLD':
            case 'SUBSCRIPTION_STATE_PAUSED':
            case 'SUBSCRIPTION_STATE_EXPIRED':
              // Ödeme alınamadı (on-hold), kullanıcı durdurdu (paused),
              // veya süre doldu — premium kaldırılır.
              isStillValid = false;
              break;
            default:
              // Bilinmeyen state — isActive + expiryTime ile fallback.
              isStillValid = isActive;
              if (expiryStr != null) {
                final expiry = DateTime.tryParse(expiryStr);
                if (expiry != null && DateTime.now().isAfter(expiry)) {
                  isStillValid = false;
                }
              }
          }
        } else {
          // subscriptionState alanı yoksa (eski backend kaydı) —
          // mevcut isActive + expiryTime mantığıyla devam et.
          isStillValid = isActive;
          if (expiryStr != null) {
            final expiry = DateTime.tryParse(expiryStr);
            if (expiry != null && DateTime.now().isAfter(expiry)) {
              isStillValid = false;
            }
          }
        }

        if (isStillValid) {
          await _box.put(_kPlan, planKey);
        } else if (isPaidSubscriber) {
          await cancelPaidSubscription();
        }
      } else {
        // Firestore'da kayıt yok → aktif abonelik yok demektir.
        // Yerel plan ücretliyse ücretsize çek.
        if (isPaidSubscriber) {
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

  /// 10 günlük ücretsiz denemeyi başlatır.
  ///
  /// Bu metod yalnızca Hive'da trialStart yoksa ve _syncTrialFromBackend()
  /// backend'den eligible onayı aldıysa çalışır. Hive'da trialStart zaten
  /// varsa (backend tarafından yazılmışsa) hiçbir şey yapmaz.
  ///
  /// Onboarding/premium_gate ekranlarından çağrıldığında:
  /// - Backend init() sırasında zaten çalışmış ve Hive'a yazmışsa → no-op (doğru)
  /// - Backend offline idiyse Hive'da değer yok → no-op (trial başlatılmaz, doğru)
  /// - Backend consumed döndüyse Hive'da değer yok → no-op (trial başlatılmaz, doğru)
  static Future<void> startGuestTrial() async {
    // Backend zaten _syncTrialFromBackend() ile yönetiyor.
    // Bu metod yalnızca Hive'da değer varsa markOnboarded yapar; yoksa dokunmaz.
    if (_box.get(_kTrialStart) != null) {
      await markOnboarded();
    }
    // Hive'da trialStart yoksa backend onayı olmadan trial başlatılmaz.
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
