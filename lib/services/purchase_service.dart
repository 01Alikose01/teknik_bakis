import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'device_id_service.dart';
import 'subscription_service.dart';

/// Google Play Aboneliklerini yöneten merkezi servis.
///
/// Google Play Console Yapılandırması:
/// 1. Tavsiye Edilen Yeni Model (Subscription + Base Plans):
///    - Subscription ID: `teknik_bakis_premium`
///      - Base Plan ID: `monthly` (Aylık Yenilenen)
///      - Base Plan ID: `yearly`  (Yıllık Yenilenen)
///
/// 2. Alternatif Klasik Model (İki ayrı Subscription):
///    - Subscription ID: `premium_monthly`
///    - Subscription ID: `premium_yearly`
///
/// Bu servis her iki Google Play Console modelini de otomatik olarak algılar ve destekler.
class PurchaseService {
  static final InAppPurchase _iap = InAppPurchase.instance;

  // Google Play Console Product / Subscription ID'leri
  // Yeni sistem: teknik_bakis_premium / monthly + yearly base planları ANA SİSTEM
  static const String kSubscriptionId = 'teknik_bakis_premium';
  static const String kLegacyMonthlyId = 'premium_monthly';
  static const String kLegacyYearlyId = 'premium_yearly';

  // Base Plan ID'leri
  static const String kBasePlanMonthly = 'monthly';
  static const String kBasePlanYearly = 'yearly';

  // Yeni satın alma akışı SADECE yeni sistemi sorgular.
  // Legacy ürünler yalnızca restore için ayrı alanlar kullanır.
  static final Set<String> _kNewProductIds = {
    kSubscriptionId,
  };

  // Legacy restore için ek sorgu (ayrı, yeni sistemle karışmaz)
  static final Set<String> _kLegacyProductIds = {
    kLegacyMonthlyId,
    kLegacyYearlyId,
  };

  static StreamSubscription<List<PurchaseDetails>>? _subscription;
  static bool _isAvailable = false;
  static bool _isLoading = false;

  // YENİ sistem: teknik_bakis_premium ürünü ve offer token'ları
  static ProductDetails? _monthlyProduct;
  static ProductDetails? _yearlyProduct;
  static String? _monthlyOfferToken;
  static String? _yearlyOfferToken;

  // LEGACY ürünler: yalnızca restore işlemleri için ayrı tutulur,
  // yeni satın alma akışında ASLA kullanılmaz.
  // ignore: unused_field
  static ProductDetails? _legacyMonthlyProduct;
  // ignore: unused_field
  static ProductDetails? _legacyYearlyProduct;

  // Dinamik fiyat bilgileri (Google Play'den dönen yerelleştirilmiş fiyatlar)
  static String _monthlyPriceText = '₺299/ay';
  static String _yearlyPriceText = '₺2499/yıl';
  static String _monthlyRawPriceText = '₺299';
  static String _yearlyRawPriceText = '₺2499';
  static String _yearlyPerMonthText = '₺208';

  // Satın alma akışı dinleyicileri için durum notifier'ı
  static final ValueNotifier<PurchaseFlowStatus> flowStatus =
      ValueNotifier<PurchaseFlowStatus>(PurchaseFlowStatus.idle);
  static final ValueNotifier<String?> lastErrorMessage =
      ValueNotifier<String?>(null);

  // Getter'lar
  static bool get isAvailable => _isAvailable;
  static bool get isLoading => _isLoading;
  static String get monthlyPriceText => _monthlyPriceText;
  static String get yearlyPriceText => _yearlyPriceText;
  static String get monthlyRawPriceText => _monthlyRawPriceText;
  static String get yearlyRawPriceText => _yearlyRawPriceText;
  static String get yearlyPerMonthText => _yearlyPerMonthText;

  /// Servisi başlatır, dinleyiciyi bağlar ve Google Play ürünlerini çeker.
  static Future<void> init() async {
    _subscription?.cancel();
    _subscription = _iap.purchaseStream.listen(
      _onPurchaseStreamUpdated,
      onDone: () => _subscription?.cancel(),
      onError: (dynamic error) {
        debugPrint('[PurchaseService] purchaseStream error: $error');
      },
    );

    await loadProducts();

    // Kullanıcı uygulamayı yeniden yüklediyse veya başka cihazda aynı
    // Google hesabıyla açtıysa aktif aboneliği otomatik geri yükle
    if (_isAvailable) {
      restorePurchases();
    }
  }

  /// Google Play Store'dan ürün detaylarını ve fiyatlarını sorgular.
  /// SADECE yeni teknik_bakis_premium ürününü sorgular.
  /// Legacy ürünler yeni satın alma akışına dahil edilmez.
  static Future<void> loadProducts() async {
    try {
      _isLoading = true;
      _isAvailable = await _iap.isAvailable();

      if (!_isAvailable) {
        debugPrint('[PurchaseService] Store is not available');
        _isLoading = false;
        return;
      }

      // Yalnızca yeni sistem ürününü sorgula — legacy ürünler buraya dahil edilmez
      final ProductDetailsResponse response =
          await _iap.queryProductDetails(_kNewProductIds);

      if (response.error != null) {
        debugPrint(
            '[PurchaseService] queryProductDetails error: ${response.error!.message}');
      }

      for (final product in response.productDetails) {
        debugPrint(
            '[PurchaseService] Found product: ${product.id}, price: ${product.price}');

        // Yeni Sistem: teknik_bakis_premium / monthly + yearly base plans
        if (product.id == kSubscriptionId &&
            product is GooglePlayProductDetails) {
          final offers =
              product.productDetails.subscriptionOfferDetails ?? [];
          for (final offer in offers) {
            final basePlanId = offer.basePlanId.toLowerCase();
            final phases = offer.pricingPhases;
            final priceFormatted =
                phases.isNotEmpty ? phases.first.formattedPrice : product.price;
            final rawPrice = priceFormatted
                .replaceAll('/ay', '')
                .replaceAll('/yıl', '')
                .trim();

            if (basePlanId.contains('month') || basePlanId == kBasePlanMonthly) {
              // Yeni sistem monthly → _monthlyProduct
              _monthlyProduct = product;
              _monthlyOfferToken = offer.offerIdToken;
              _monthlyPriceText = '$priceFormatted/ay';
              _monthlyRawPriceText = rawPrice;
              debugPrint('[PurchaseService] New monthly plan loaded: offerToken=${offer.offerIdToken}');
            } else if (basePlanId.contains('year') ||
                basePlanId == kBasePlanYearly) {
              // Yeni sistem yearly → _yearlyProduct
              _yearlyProduct = product;
              _yearlyOfferToken = offer.offerIdToken;
              _yearlyPriceText = '$priceFormatted/yıl';
              _yearlyRawPriceText = rawPrice;
              _calculateMonthlyEquivalent(
                  phases.isNotEmpty ? phases.first.priceAmountMicros : 0);
              debugPrint('[PurchaseService] New yearly plan loaded: offerToken=${offer.offerIdToken}');
            }
          }
        }

        // Legacy ürünler yalnızca ayrı alanlarına kaydedilir, ana akışa dahil edilmez
        if (product.id == kLegacyMonthlyId) {
          _legacyMonthlyProduct = product;
          debugPrint('[PurchaseService] Legacy monthly product found (restore only): ${product.id}');
        } else if (product.id == kLegacyYearlyId) {
          _legacyYearlyProduct = product;
          debugPrint('[PurchaseService] Legacy yearly product found (restore only): ${product.id}');
        }
      }

      // Legacy ürünleri de ayrı bir sorguda yükle (restore için)
      _loadLegacyProductsForRestoreOnly();
    } catch (e, st) {
      debugPrint('[PurchaseService] loadProducts exception: $e\n$st');
    } finally {
      _isLoading = false;
    }
  }

  /// Legacy ürünleri yalnızca restore akışı için arka planda yükler.
  /// Bu ürünler yeni satın alma akışında ASLA kullanılamaz.
  static Future<void> _loadLegacyProductsForRestoreOnly() async {
    try {
      final ProductDetailsResponse legacyResponse =
          await _iap.queryProductDetails(_kLegacyProductIds);
      for (final product in legacyResponse.productDetails) {
        if (product.id == kLegacyMonthlyId) {
          _legacyMonthlyProduct = product;
        } else if (product.id == kLegacyYearlyId) {
          _legacyYearlyProduct = product;
        }
        debugPrint('[PurchaseService] Legacy product loaded for restore: ${product.id}');
      }
    } catch (e) {
      debugPrint('[PurchaseService] _loadLegacyProductsForRestoreOnly error (non-critical): $e');
    }
  }

  static void _calculateMonthlyEquivalent(int micros) {
    if (micros <= 0) return;
    try {
      final yearlyAmount = micros / 1000000.0;
      final monthlyAmount = yearlyAmount / 12.0;
      _yearlyPerMonthText = '₺${monthlyAmount.round()}';
    } catch (_) {}
  }

  /// Kullanıcı Aylık veya Yıllık plan seçtiğinde Google Play satın alma ekranını açar.
  /// [plan] : 'monthly' | 'yearly'
  /// SADECE yeni teknik_bakis_premium ürünü kullanılır; legacy ürünler bu akışta yasak.
  static Future<bool> buyPlan(String plan) async {
    lastErrorMessage.value = null;
    flowStatus.value = PurchaseFlowStatus.inProgress;

    if (!_isAvailable) {
      // Bir kez daha kontrol et
      _isAvailable = await _iap.isAvailable();
      if (!_isAvailable) {
        lastErrorMessage.value =
            'Google Play Store ile bağlantı kurulamadı. Lütfen internet bağlantınızı ve Google Play hesabınızı kontrol edin.';
        flowStatus.value = PurchaseFlowStatus.error;
        return false;
      }
    }

    // Yeni sistem ürünlerini kullan — legacy ürünler ASLA kullanılmaz
    ProductDetails? targetProduct =
        (plan == 'monthly') ? _monthlyProduct : _yearlyProduct;
    String? targetOfferToken =
        (plan == 'monthly') ? _monthlyOfferToken : _yearlyOfferToken;

    // Yeni sistem ürünleri henüz yüklenmemişse tekrar yüklemeyi dene
    if (targetProduct == null) {
      await loadProducts();
      targetProduct = (plan == 'monthly') ? _monthlyProduct : _yearlyProduct;
      targetOfferToken =
          (plan == 'monthly') ? _monthlyOfferToken : _yearlyOfferToken;
    }

    // Güvenlik: legacy ürün yanlışlıkla seçildiyse engelle
    if (targetProduct != null &&
        (targetProduct.id == kLegacyMonthlyId ||
            targetProduct.id == kLegacyYearlyId)) {
      debugPrint('[PurchaseService] HATA: buyPlan legacy ürün seçmeye çalıştı — engellendi.');
      lastErrorMessage.value =
          'Google Play abonelik ürünü yapılandırması geçersiz. Lütfen uygulamayı güncelleyin.';
      flowStatus.value = PurchaseFlowStatus.error;
      return false;
    }

    if (targetProduct == null) {
      lastErrorMessage.value =
          'Google Play abonelik ürünü bulunamadı. Lütfen daha sonra tekrar deneyiniz.';
      flowStatus.value = PurchaseFlowStatus.error;
      return false;
    }

    try {
      late PurchaseParam purchaseParam;

      if (Platform.isAndroid && targetProduct is GooglePlayProductDetails) {
        purchaseParam = GooglePlayPurchaseParam(
          productDetails: targetProduct,
          offerToken: targetOfferToken,
        );
      } else {
        purchaseParam = PurchaseParam(productDetails: targetProduct);
      }

      // Abonelikler non-consumable olarak satın alınır
      final started = await _iap.buyNonConsumable(purchaseParam: purchaseParam);
      if (!started) {
        lastErrorMessage.value = 'Satın alma işlemi başlatılamadı.';
        flowStatus.value = PurchaseFlowStatus.error;
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('[PurchaseService] buyPlan exception: $e');
      lastErrorMessage.value = 'Hata oluştu: $e';
      flowStatus.value = PurchaseFlowStatus.error;
      return false;
    }
  }

  /// Satın alımları geri yükler (Uygulama yeniden yüklendiğinde veya cihaz değişiminde)
  static Future<void> restorePurchases() async {
    try {
      if (!_isAvailable) {
        _isAvailable = await _iap.isAvailable();
      }
      if (_isAvailable) {
        await _iap.restorePurchases();
      }
    } catch (e) {
      debugPrint('[PurchaseService] restorePurchases exception: $e');
    }
  }

  /// Satın alma stream'inden gelen güncellemeleri işler.
  static Future<void> _onPurchaseStreamUpdated(
      List<PurchaseDetails> purchaseDetailsList) async {
    for (final purchaseDetails in purchaseDetailsList) {
      debugPrint(
          '[PurchaseService] Purchase update: ${purchaseDetails.productID}, status: ${purchaseDetails.status}');

      switch (purchaseDetails.status) {
        case PurchaseStatus.pending:
          flowStatus.value = PurchaseFlowStatus.pending;
          break;

        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          final isValid = await _verifyAndDeliverProduct(purchaseDetails);
          if (isValid) {
            flowStatus.value = PurchaseFlowStatus.success;
          } else {
            flowStatus.value = PurchaseFlowStatus.error;
          }
          break;

        case PurchaseStatus.error:
          flowStatus.value = PurchaseFlowStatus.error;
          lastErrorMessage.value = purchaseDetails.error?.message ??
              'Ödeme işlemi sırasında bir hata oluştu.';
          break;

        case PurchaseStatus.canceled:
          flowStatus.value = PurchaseFlowStatus.canceled;
          break;
      }

      // Satın almayı Google Play'e bildirme (Acknowledge)
      // Bu adım yapılmazsa Google Play 3 gün sonra ödemeyi otomatik iade eder!
      if (purchaseDetails.pendingCompletePurchase) {
        try {
          await _iap.completePurchase(purchaseDetails);
          debugPrint(
              '[PurchaseService] completePurchase called successfully for ${purchaseDetails.purchaseID}');
        } catch (e) {
          debugPrint('[PurchaseService] completePurchase error: $e');
        }
      }
    }
  }

  /// Satın almayı doğrular, yerel ve backend durumunu günceller.
  static Future<bool> _verifyAndDeliverProduct(
      PurchaseDetails purchase) async {
    try {
      // Satın alınan planı belirle
      String planKey = 'monthly';
      final pid = purchase.productID;

      if (pid == kLegacyYearlyId) {
        // Legacy yearly restore
        planKey = 'yearly';
      } else if (pid == kLegacyMonthlyId) {
        // Legacy monthly restore
        planKey = 'monthly';
      } else if (pid == kSubscriptionId) {
        // Yeni sistem: offer token üzerinden base plan belirle
        final serverData = purchase.verificationData.serverVerificationData;
        final localData = purchase.verificationData.localVerificationData;
        // Offer token veya local verification data'da 'yearly' / 'year' geçiyorsa yearly
        if (_yearlyOfferToken != null && _yearlyOfferToken!.isNotEmpty &&
            (serverData.contains(_yearlyOfferToken!) ||
                localData.contains('year') ||
                localData.toLowerCase().contains('yearly'))) {
          planKey = 'yearly';
        } else if (serverData.contains('year') ||
            serverData.toLowerCase().contains('yearly')) {
          planKey = 'yearly';
        } else {
          planKey = 'monthly';
        }
      }

      // 1. Firebase Firestore backend doğrulaması için satın alma kaydını sakla
      // (Arka planda Cloud Function Firestore Trigger onPurchaseWritten tetiklenir)
      await _syncPurchaseWithBackend(purchase, planKey);

      // 2. Doğrudan Cloud Function Google Play Developer API doğrulaması
      final isValidOnServer = await _verifyWithCloudFunction(purchase, planKey);

      if (isValidOnServer) {
        // Sunucu doğrulaması başarılı → Premium erişimini aç
        await SubscriptionService.startPaidSubscription(planKey);
        return true;
      } else {
        debugPrint('[PurchaseService] Server verification rejected the purchase');
        lastErrorMessage.value =
            'Satın alma doğrulanıyor, lütfen tekrar deneyin. Ödemeniz Google Play\'de kaydedildi.';
        return false;
      }
    } catch (e) {
      debugPrint('[PurchaseService] _verifyAndDeliverProduct error: $e');
      return false;
    }
  }

  static const String _verifyEndpoint =
      'https://europe-west1-teknik-bakis.cloudfunctions.net/verifySubscription';

  /// Cloud Functions HTTPS endpoint'i üzerinden Google Play Developer API doğrulaması yapar.
  ///
  /// GÜVENLİK KURALI: Herhangi bir hata durumunda false döner.
  /// Premium erişim SADECE backend "isActive: true" döndürdüğünde açılır.
  /// Network hatası, timeout, HTTP 5xx, geçersiz cevap → false
  static Future<bool> _verifyWithCloudFunction(
      PurchaseDetails purchase, String planKey) async {
    try {
      final deviceId = await DeviceIdService.getDeviceId();
      final token = purchase.verificationData.serverVerificationData.isNotEmpty
          ? purchase.verificationData.serverVerificationData
          : purchase.verificationData.localVerificationData;

      if (token.isEmpty) {
        debugPrint('[PurchaseService] _verifyWithCloudFunction: token boş — false');
        return false;
      }

      final response = await http
          .post(
            Uri.parse(_verifyEndpoint),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'purchaseToken': token,
              'productId': purchase.productID,
              'deviceId': deviceId,
              'plan': planKey,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body is Map && body['isActive'] != null) {
          final result = body['isActive'] == true;
          debugPrint('[PurchaseService] _verifyWithCloudFunction: isActive=$result');
          return result;
        }
        // Geçersiz cevap formatı → false
        debugPrint('[PurchaseService] _verifyWithCloudFunction: geçersiz cevap formatı — false');
        return false;
      } else {
        // HTTP 4xx, 5xx → doğrulama başarısız
        debugPrint(
            '[PurchaseService] _verifyWithCloudFunction HTTP ${response.statusCode} — false');
        return false;
      }
    } on TimeoutException catch (e) {
      debugPrint('[PurchaseService] _verifyWithCloudFunction timeout: $e — false');
      return false;
    } catch (e) {
      debugPrint('[PurchaseService] _verifyWithCloudFunction network error: $e — false');
      return false;
    }
  }

  /// Satın alma kaydını güvenli şekilde Firestore `purchases/{deviceId}` koleksiyonuna yazar.
  /// Backend (Cloud Functions) bu kayıt üzerinden Google Play Developer API ile
  /// periyodik doğrulama (token doğrulaması) yapabilir.
  static Future<void> _syncPurchaseWithBackend(
      PurchaseDetails purchase, String planKey) async {
    try {
      final deviceId = await DeviceIdService.getDeviceId();
      final firestore = FirebaseFirestore.instance;

      await firestore.collection('purchases').doc(deviceId).set({
        'deviceId': deviceId,
        'productId': purchase.productID,
        'purchaseId': purchase.purchaseID,
        'plan': planKey,
        'status': purchase.status.name,
        'purchaseTime': purchase.transactionDate != null
            ? DateTime.fromMillisecondsSinceEpoch(
                    int.tryParse(purchase.transactionDate!) ??
                        DateTime.now().millisecondsSinceEpoch)
                .toIso8601String()
            : DateTime.now().toIso8601String(),
        'platform': Platform.isAndroid ? 'android' : 'ios',
        'localVerificationData': purchase.verificationData.localVerificationData,
        'serverVerificationData': purchase.verificationData.serverVerificationData,
        'source': purchase.verificationData.source,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('[PurchaseService] Purchase synced to backend for device $deviceId');
    } catch (e) {
      debugPrint('[PurchaseService] _syncPurchaseWithBackend non-blocking error: $e');
    }
  }

  static void dispose() {
    _subscription?.cancel();
  }
}

enum PurchaseFlowStatus {
  idle,
  inProgress,
  pending,
  success,
  error,
  canceled,
}
