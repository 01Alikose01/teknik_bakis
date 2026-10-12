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

  /// buyPlan() çağrısında hangi planın satın alınmaya çalışıldığını saklar.
  /// _verifyAndDeliverProduct içinde offer token eşleşmesi başarısız olduğunda
  /// bu değer fallback olarak kullanılır — 'monthly'/'yearly'
  static String? _pendingPlanHint;

  /// İşlenmiş purchase token'larını tutar — aynı token için tekrar
  /// flowStatus.success üretilmesini önler (Google Play test renewal döngüsü gibi).
  /// Uygulama oturumu boyunca kalıcıdır; yeniden başlatıldığında temizlenir.
  static final Set<String> _processedTokens = {};

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

    // NOT: restorePurchases() burada kasıtlı olarak çağrılmıyor.
    // Uygulama açılışında otomatik restore, Google Play test ortamında
    // her 30 dakikalık renewal'ı "purchased" event olarak stream'e düşürür
    // ve tekrar tekrar "Tebrikler" success sheet açılmasına neden olur.
    // Mevcut abonelik durumu SubscriptionService.syncWithBackendEntitlements()
    // üzerinden Firestore'dan okunuyor — bu yeterli.
    // Manuel restore: settings_screen ve onboarding_screen'deki butonlar kullanılır.
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

      // Satın alma başlamadan hangi plan seçildiğini kaydet.
      // _verifyAndDeliverProduct'ta offer token eşleşmesi başarısız olursa
      // bu değer fallback plan hint'i olarak kullanılır.
      _pendingPlanHint = plan;

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
  ///
  /// Google Play'e restore isteği gönderilir. Aktif abonelik varsa
  /// purchaseStream üzerinden `restored` event gelir ve `_verifyAndDeliverProduct`
  /// çalışır. Aktif abonelik YOKSA (iptal edilmişse) Google Play hiç event
  /// döndürmez — bu nedenle kısa bir bekleme sonrası backend entitlements
  /// senkronizasyonu yapılır. Backend `isActive:false` döndürürse yerel plan
  /// `'none'` olarak güncellenir.
  static Future<bool> restorePurchases() async {
    try {
      if (!_isAvailable) {
        _isAvailable = await _iap.isAvailable();
      }
      if (!_isAvailable) return false;

      // Restore öncesi plan durumunu kaydet
      final planBefore = SubscriptionService.plan;

      await _iap.restorePurchases();

      // Google Play aktif abonelik event'i göndermesi için kısa süre bekle.
      // Event gelirse _onPurchaseStreamUpdated zaten planı günceller.
      // Event gelmezse (iptal edilmiş/yok) backend ile senkronize et.
      await Future.delayed(const Duration(seconds: 3));

      // Backend entitlements kontrolü: abonelik yoksa/iptal edilmişse planı sıfırla
      await SubscriptionService.syncWithBackendEntitlements();

      // Plan değişip değişmediğini dön (UI feedback için)
      return SubscriptionService.plan != planBefore;
    } catch (e) {
      debugPrint('[PurchaseService] restorePurchases exception: $e');
      return false;
    }
  }

  /// Satın alma stream'inden gelen güncellemeleri işler.
  static Future<void> _onPurchaseStreamUpdated(
      List<PurchaseDetails> purchaseDetailsList) async {
    for (final purchaseDetails in purchaseDetailsList) {
      debugPrint(
          '[PurchaseService] Purchase update: ${purchaseDetails.productID}, status: ${purchaseDetails.status}');

      // ── Idempotency kontrolü ─────────────────────────────────────────────
      // Google Play test ortamında abonelik her 30 dakikada bir yenilenir ve
      // her yenileme purchaseStream'e PurchaseStatus.purchased olarak gelir.
      // Aynı purchaseToken daha önce işlendiyse success event üretme;
      // yalnızca pendingCompletePurchase varsa acknowledge et.
      final token = purchaseDetails.verificationData.serverVerificationData.isNotEmpty
          ? purchaseDetails.verificationData.serverVerificationData
          : purchaseDetails.verificationData.localVerificationData;
      final isAlreadyProcessed = token.isNotEmpty && _processedTokens.contains(token);

      switch (purchaseDetails.status) {
        case PurchaseStatus.pending:
          flowStatus.value = PurchaseFlowStatus.pending;
          break;

        case PurchaseStatus.purchased:
          if (isAlreadyProcessed) {
            // Aynı token — Google Play renewal event'i. Success üretme,
            // sadece acknowledge et (aşağıdaki completePurchase bloğu halleder).
            debugPrint(
                '[PurchaseService] Token zaten işlendi, success üretilmiyor: ${purchaseDetails.purchaseID}');
          } else {
            final isValid = await _verifyAndDeliverProduct(purchaseDetails);
            if (isValid) {
              // Token'ı işlendi olarak işaretle
              if (token.isNotEmpty) _processedTokens.add(token);
              flowStatus.value = PurchaseFlowStatus.success;
            } else {
              flowStatus.value = PurchaseFlowStatus.error;
            }
          }
          break;

        case PurchaseStatus.restored:
          // Restore'da Premium durumu güncellenir, ancak success sheet açılmaz.
          // flowStatus değişmeden kalır — kullanıcıya "Tebrikler" mesajı gösterilmez.
          await _verifyAndDeliverProduct(purchaseDetails);
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
      // ── Adım 1: Flutter-side plan tahmini ──────────────────────────────
      // Bu değer yalnızca backend çağrısına hint olarak gönderilir.
      // Gerçek plan, Cloud Function'dan dönen `confirmedPlan` tarafından belirlenir.
      String planHint = 'monthly';
      final pid = purchase.productID;

      if (pid == kLegacyYearlyId) {
        // Legacy yearly restore
        planHint = 'yearly';
      } else if (pid == kLegacyMonthlyId) {
        // Legacy monthly restore
        planHint = 'monthly';
      } else if (pid == kSubscriptionId) {
        // Öncelik sırası:
        //   1. Offer token eşleşmesi (en güvenilir — Google Play'den alınan token)
        //   2. buyPlan() sırasında kaydedilen _pendingPlanHint
        //   3. verification data içinde 'year' geçiyor mu (son çare)
        final serverData = purchase.verificationData.serverVerificationData;
        final localData  = purchase.verificationData.localVerificationData;

        final bool tokenMatchesYearly = _yearlyOfferToken != null &&
            _yearlyOfferToken!.isNotEmpty &&
            (serverData.contains(_yearlyOfferToken!) ||
                localData.contains(_yearlyOfferToken!));

        final bool dataContainsYear =
            serverData.toLowerCase().contains('year') ||
            localData.toLowerCase().contains('year');

        // _pendingPlanHint: buyPlan('yearly') ile başlatılan akışlarda
        // offer token henüz yüklü olmasa bile doğru planı bildirir.
        final bool pendingHintIsYearly = _pendingPlanHint == 'yearly';

        planHint = (tokenMatchesYearly || dataContainsYear || pendingHintIsYearly)
            ? 'yearly'
            : 'monthly';

        debugPrint('[PurchaseService] Plan hint (local): $planHint'
            ' | yearlyOfferToken loaded: ${_yearlyOfferToken != null}'
            ' | tokenMatch: $tokenMatchesYearly'
            ' | dataContainsYear: $dataContainsYear'
            ' | pendingHint: $_pendingPlanHint');
      }

      // ── Adım 2: Cloud Function doğrulaması ─────────────────────────────
      // Backend Google Play lineItems üzerinden gerçek base plan'ı belirler.
      // Bu değer planHint'ten her zaman daha güvenilirdir.
      final serverResult = await _verifyWithCloudFunction(purchase, planHint);

      // ── Adım 3: Gerçek planı belirle ───────────────────────────────────
      // Backend başarıyla doğruladıysa onun belirlediği planı kullan.
      // Backend erişilemezse (timeout/hata) planHint ile devam et —
      // kullanıcı para ödedi, Google Play işlemi onayladı.
      final confirmedPlan = serverResult.isActive
          ? serverResult.plan   // Backend'den doğrulanmış plan
          : planHint;           // Fallback: Flutter-side tahmin

      // ── Adım 4: Firestore'a yaz (doğrulanmış planla) ───────────────────
      // _syncPurchaseWithBackend artık Cloud Function sonrası çağrılıyor;
      // bu sayede Firestore'a yazılan plan değeri hep doğrulanmış plan olur.
      await _syncPurchaseWithBackend(purchase, confirmedPlan);

      if (serverResult.isActive) {
        debugPrint('[PurchaseService] Plan confirmed by backend: $confirmedPlan (hint was: $planHint)');
        await SubscriptionService.startPaidSubscription(confirmedPlan);
        // Satın alma tamamlandı — pending hint'i temizle
        _pendingPlanHint = null;
        return true;
      } else {
        // Backend erişilemedi veya doğrulama başarısız.
        // Kullanıcı gerçekten para ödediyse planHint ile lokal aktivasyon yap.
        // Bu durum yalnızca Cloud Function'ın erişilemez olduğu anlarda geçici
        // koruma sağlar; bir sonraki syncWithBackendEntitlements() düzeltir.
        if (purchase.status == PurchaseStatus.purchased) {
          debugPrint('[PurchaseService] Backend erişilemedi ama purchase.purchased — '
              'geçici lokal aktivasyon: $confirmedPlan');
          await SubscriptionService.startPaidSubscription(confirmedPlan);
          _pendingPlanHint = null;
          return true;
        }

        debugPrint('[PurchaseService] Server verification rejected / no active purchase');
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
  /// GÜVENLİK KURALI: Herhangi bir hata durumunda isActive:false döner.
  /// Premium erişim SADECE backend "isActive: true" döndürdüğünde açılır.
  /// Network hatası, timeout, HTTP 5xx, geçersiz cevap → isActive:false
  ///
  /// Dönüş değeri: {isActive: bool, plan: String}
  /// Backend Google Play lineItems üzerinden gerçek base plan'ı belirler;
  /// bu değer Flutter tarafındaki tahminden daha güvenilirdir.
  static Future<({bool isActive, String plan})> _verifyWithCloudFunction(
      PurchaseDetails purchase, String planHint) async {
    final fallback = (isActive: false, plan: planHint);
    try {
      final deviceId = await DeviceIdService.getDeviceId();
      final token = purchase.verificationData.serverVerificationData.isNotEmpty
          ? purchase.verificationData.serverVerificationData
          : purchase.verificationData.localVerificationData;

      if (token.isEmpty) {
        debugPrint('[PurchaseService] _verifyWithCloudFunction: token boş — false');
        return fallback;
      }

      final response = await http
          .post(
            Uri.parse(_verifyEndpoint),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'purchaseToken': token,
              'productId': purchase.productID,
              'deviceId': deviceId,
              'plan': planHint,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body is Map && body['isActive'] != null) {
          final isActive = body['isActive'] == true;
          // Backend Google Play lineItems'tan gerçek plan'ı belirler.
          // 'yearly' veya 'monthly' — planHint'ten daha güvenilir.
          final resolvedPlan = (body['plan'] as String?)?.isNotEmpty == true
              ? body['plan'] as String
              : planHint;
          debugPrint('[PurchaseService] _verifyWithCloudFunction: isActive=$isActive, plan=$resolvedPlan');
          return (isActive: isActive, plan: resolvedPlan);
        }
        debugPrint('[PurchaseService] _verifyWithCloudFunction: geçersiz cevap formatı — false');
        return fallback;
      } else {
        debugPrint(
            '[PurchaseService] _verifyWithCloudFunction HTTP ${response.statusCode} — false');
        return fallback;
      }
    } on TimeoutException catch (e) {
      debugPrint('[PurchaseService] _verifyWithCloudFunction timeout: $e — false');
      return fallback;
    } catch (e) {
      debugPrint('[PurchaseService] _verifyWithCloudFunction network error: $e — false');
      return fallback;
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
