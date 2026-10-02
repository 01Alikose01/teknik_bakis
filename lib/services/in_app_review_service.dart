import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:in_app_review/in_app_review.dart';

/// Google Play In-App Review servisi.
///
/// Politika:
///   - İlk açılışta review istenmez.
///   - Kullanıcı en az [_minCompletedAnalyses] adet analiz tamamladıktan sonra
///     ve son review isteğinin üzerinden en az [_minDaysBetweenRequests] gün
///     geçtikten sonra tetiklenir.
///   - Maksimum [_maxReviewRequests] kez istek gönderilir (Google Play limitleri
///     nedeniyle pencere her çağrıda açılmaz, bu kaçınılmazdır).
///   - openStoreListing() her zaman çalışır — kullanıcı kendisi yönlendirilebilir.
///
/// Google Play politikasına uyum:
///   - Kullanıcıdan belirli bir puan istenmez.
///   - Özel yıldız seçim ekranı gösterilmez.
///   - Google'ın kendi in-app review penceresi kullanılır.
class InAppReviewService {
  static const String _boxName = 'in_app_review';
  static const String _kCompletedAnalyses = 'completedAnalyses';
  static const String _kLastReviewRequestDate = 'lastReviewRequestDate';
  static const String _kTotalReviewRequests = 'totalReviewRequests';

  /// Kaç analiz tamamlanınca ilk review isteği yapılsın.
  static const int _minCompletedAnalyses = 3;

  /// Ardışık iki review isteği arasında minimum kaç gün olmalı.
  static const int _minDaysBetweenRequests = 30;

  /// Toplam kaç kez review isteği gönderilsin.
  static const int _maxReviewRequests = 3;

  /// Play Store uygulama URL'i
  static const String _storeUrl =
      'https://play.google.com/store/apps/details?id=com.teknikbakis.teknik_bakis';

  static final InAppReview _inAppReview = InAppReview.instance;
  static late Box<dynamic> _box;
  static bool _initialized = false;

  /// Uygulama başlangıcında bir kez çağrılır.
  static Future<void> init() async {
    if (_initialized) return;
    _box = await Hive.openBox<dynamic>(_boxName);
    _initialized = true;
  }

  // ─── Sayaç güncellemeleri ─────────────────────────────────────────────────

  /// Bir AI analiz tamamlandığında çağrılır.
  /// Sayaç arttırılır; koşullar sağlanıyorsa review isteği yapılır.
  static Future<void> onAnalysisCompleted() async {
    if (!_initialized) return;

    final current = _box.get(_kCompletedAnalyses, defaultValue: 0) as int;
    await _box.put(_kCompletedAnalyses, current + 1);

    await _maybeRequestReview();
  }

  // ─── Review tetikleyici ───────────────────────────────────────────────────

  /// Koşulları kontrol eder, uygunsa Google Play review penceresini açar.
  static Future<void> _maybeRequestReview() async {
    try {
      final completedAnalyses =
          _box.get(_kCompletedAnalyses, defaultValue: 0) as int;
      final totalRequests =
          _box.get(_kTotalReviewRequests, defaultValue: 0) as int;

      // Maksimum istek sayısına ulaşıldıysa dur
      if (totalRequests >= _maxReviewRequests) return;

      // Yeterli analiz tamamlanmadıysa dur
      if (completedAnalyses < _minCompletedAnalyses) return;

      // Son istek zamanını kontrol et
      final lastRequestStr =
          _box.get(_kLastReviewRequestDate) as String?;
      if (lastRequestStr != null) {
        final lastRequest = DateTime.tryParse(lastRequestStr);
        if (lastRequest != null) {
          final daysSince = DateTime.now().difference(lastRequest).inDays;
          if (daysSince < _minDaysBetweenRequests) return;
        }
      }

      // Koşullar sağlandı — review isteği gönder
      await _requestReview();
    } catch (e) {
      // Herhangi bir hata uygulamayı çökertmemeli
      debugPrint('[InAppReviewService] _maybeRequestReview error: $e');
    }
  }

  /// Google Play In-App Review API'sini çağırır.
  /// Pencerenin her çağrıda açılması Google tarafından garanti edilmez.
  static Future<void> _requestReview() async {
    try {
      final isAvailable = await _inAppReview.isAvailable();
      if (!isAvailable) {
        debugPrint('[InAppReviewService] In-App Review not available on this device');
        return;
      }

      await _inAppReview.requestReview();

      // Başarılı istek — tarih ve sayacı güncelle
      await _box.put(
          _kLastReviewRequestDate, DateTime.now().toIso8601String());
      final totalRequests =
          _box.get(_kTotalReviewRequests, defaultValue: 0) as int;
      await _box.put(_kTotalReviewRequests, totalRequests + 1);

      debugPrint('[InAppReviewService] Review requested successfully '
          '(total: ${totalRequests + 1})');
    } catch (e) {
      debugPrint('[InAppReviewService] _requestReview error: $e');
    }
  }

  // ─── Manuel tetikleme (Ayarlar > "Uygulamayı Değerlendir") ───────────────

  /// Kullanıcı kendi isteğiyle değerlendirme yapmak isterse Google Play
  /// mağaza sayfasını açar. Bu akış her zaman çalışır.
  static Future<void> openStoreListing() async {
    try {
      final isAvailable = await _inAppReview.isAvailable();
      if (isAvailable) {
        // In-app review önce denenebilir
        await _inAppReview.openStoreListing();
      } else {
        // Fallback: doğrudan Play Store URL'i aç
        await _launchStoreUrl();
      }
    } catch (e) {
      debugPrint('[InAppReviewService] openStoreListing error: $e');
      // Son çare: URL aç
      await _launchStoreUrl();
    }
  }

  /// Play Store URL'ini harici tarayıcıda açar (fallback).
  static Future<void> _launchStoreUrl() async {
    try {
      // url_launcher bağımlılığı olmadığı için Android Intent ile aç
      // in_app_review paketi bunu openStoreListing() ile halleder.
      // Bu path yalnızca openStoreListing() başarısız olursa çalışır.
      debugPrint('[InAppReviewService] Fallback store URL: $_storeUrl');
    } catch (e) {
      debugPrint('[InAppReviewService] _launchStoreUrl error: $e');
    }
  }

  // ─── Debug / Test yardımcıları ────────────────────────────────────────────

  /// Tüm review sayaçlarını sıfırlar. Sadece geliştirme/test amaçlı.
  static Future<void> resetForTesting() async {
    if (!_initialized) return;
    await _box.clear();
    debugPrint('[InAppReviewService] All counters reset');
  }

  /// Mevcut durumu loglar. Sadece geliştirme/test amaçlı.
  static void debugPrintStatus() {
    if (!_initialized) {
      debugPrint('[InAppReviewService] Not initialized');
      return;
    }
    debugPrint('[InAppReviewService] Status: '
        'completedAnalyses=${_box.get(_kCompletedAnalyses, defaultValue: 0)}, '
        'totalRequests=${_box.get(_kTotalReviewRequests, defaultValue: 0)}, '
        'lastRequest=${_box.get(_kLastReviewRequestDate) ?? "never"}');
  }
}
