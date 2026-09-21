import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart';
import '../services/subscription_service.dart';

/// Ödeme ekranı — seçilen plana göre gösterilir.
/// Gerçek ödeme entegrasyonu (RevenueCat, İyzico vb.) için
/// [_processPurchase] metoduna entegre edilecek.
class PaymentScreen extends StatefulWidget {
  final String plan; // 'monthly' | 'yearly'
  final Widget nextScreen;

  const PaymentScreen({
    super.key,
    required this.plan,
    required this.nextScreen,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  bool _processing = false;

  // Ödeme başlamadan önce anlık değer saklanır — startPaidSubscription sonrası
  // isExpiredGuest false döneceğinden getter kullanmak hatalı sonuç verir.
  late bool _trialWasUsed = SubscriptionService.isExpiredGuest;

  String get _planLabel =>
      widget.plan == 'monthly' ? 'Aylık Plan' : 'Yıllık Plan';
  String get _priceLabel =>
      widget.plan == 'monthly' ? '₺299/ay' : '₺2499/yıl';

  /// Deneme daha önce kullanılmışsa trialNote farklı gösterilir
  bool get _trialUsed => _trialWasUsed;

  String get _trialNote =>
      _trialUsed ? 'İlk 10 gün ücretsiz (Kullanıldı)' : 'İlk 10 gün ücretsiz. Sonra $_priceLabel';
  Color get _accent => const Color(0xFF34C759);

  Future<void> _processPurchase() async {
    if (_processing) return;
    // Ödeme başlamadan önce deneme durumunu yakala
    _trialWasUsed = SubscriptionService.isExpiredGuest;
    setState(() => _processing = true);
    HapticFeedback.mediumImpact();

    // ── Gerçek ödeme burada yapılır ──────────────────────────────────────
    // Örnek: RevenueCat, İyzico, Stripe entegrasyonu buraya eklenir.
    // Şimdilik 1.5 sn simüle edip başarılı kabul ediyoruz.
    await Future.delayed(const Duration(milliseconds: 1500));
    // ─────────────────────────────────────────────────────────────────────

    if (!mounted) return;

    await SubscriptionService.startPaidSubscription(widget.plan);

    if (!mounted) return;
    setState(() => _processing = false);

    // Başarı göster, sonra ana uygulamaya geç
    await _showSuccessSheet();
  }

  Future<void> _showSuccessSheet() async {
    final theme = Theme.of(context);
    await showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => _SuccessSheet(
        plan: widget.plan,
        trialUsed: _trialUsed,
        onContinue: () {
          Navigator.of(ctx).pop();
          _goToApp();
        },
      ),
    );
  }

  void _goToApp() {
    // Abonelik değişti — tüm sekmeleri rebuild et
    MainNavigation.refreshSubscription();
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            widget.nextScreen,
        transitionsBuilder: (context, anim, secondaryAnimation, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final scaffoldBg = isDark ? theme.scaffoldBackgroundColor : const Color(0xFFF5F5F7);

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: scaffoldBg,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                    blurRadius: 6)
              ],
            ),
            child: Icon(Icons.arrow_back_ios,
                size: 16, color: theme.colorScheme.onSurface),
          ),
        ),
        title: Text(
          _planLabel,
          style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 17,
              fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Plan özeti kartı ──────────────────────────────────────────
            _PlanSummaryCard(
              plan: widget.plan,
              priceLabel: _priceLabel,
              trialNote: _trialNote,
              trialUsed: _trialUsed,
              accent: _accent,
            ),
            const SizedBox(height: 24),

            // ── Güven rozetleri ───────────────────────────────────────────
            _TrustBadges(accent: _accent),
            const SizedBox(height: 24),

            // ── Dahil olanlar ─────────────────────────────────────────────
            Text(
              'Planınıza Dahil Olanlar',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface),
            ),
            const SizedBox(height: 12),
            _IncludedFeaturesList(accent: _accent),
            const SizedBox(height: 24),

            // ── İptal politikası ──────────────────────────────────────────
            _CancelPolicy(accent: _accent),
          ],
        ),
      ),

      // ── Sabit alt buton ───────────────────────────────────────────────
      bottomSheet: _PaymentBottomBar(
        priceLabel: _priceLabel,
        trialNote: _trialNote,
        trialUsed: _trialUsed,
        processing: _processing,
        accent: _accent,
        onTap: _processPurchase,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Plan Özeti Kartı
// ─────────────────────────────────────────────────────────────────────────────

class _PlanSummaryCard extends StatelessWidget {
  final String plan;
  final String priceLabel;
  final String trialNote;
  final bool trialUsed;
  final Color accent;

  const _PlanSummaryCard({
    required this.plan,
    required this.priceLabel,
    required this.trialNote,
    required this.trialUsed,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isYearly = plan == 'yearly';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accent.withValues(alpha: 0.12),
            accent.withValues(alpha: 0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isYearly ? 'Yıllık Plan · %30 İndirim' : 'Aylık Plan',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold),
                ),
              ),
              if (isYearly) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF9500).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'AVANTAJLI',
                    style: TextStyle(
                        color: Color(0xFFFF9500),
                        fontSize: 10,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                isYearly ? '₺2499' : '₺299',
                style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: accent),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  isYearly ? '/yıl' : '/ay',
                  style: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      fontSize: 14)),
              ),
              if (isYearly) ...[
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Ayda sadece',
                        style: TextStyle(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                            fontSize: 11)),
                    Text('₺208',
                        style: TextStyle(
                            color: accent,
                            fontWeight: FontWeight.bold,
                            fontSize: 16)),
                  ],
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('🎁', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              trialUsed
                  ? Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: 'İlk 10 gün ücretsiz',
                            style: TextStyle(
                                color: accent.withValues(alpha: 0.5),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.lineThrough,
                                decorationColor: accent.withValues(alpha: 0.5)),
                          ),
                          TextSpan(
                            text: '  (Kullanıldı)',
                            style: TextStyle(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                                fontSize: 11,
                                fontWeight: FontWeight.normal),
                          ),
                        ],
                      ),
                    )
                  : Text(
                      trialNote,
                      style: TextStyle(
                          color: accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Güven Rozetleri
// ─────────────────────────────────────────────────────────────────────────────

class _TrustBadges extends StatelessWidget {
  final Color accent;
  const _TrustBadges({required this.accent});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final badges = [
      ('🔒', 'Güvenli Ödeme'),
      ('↩️', 'Anında İptal'),
      ('✅', '1₺ Çekilmez'),
    ];
    return Row(
      children: badges
          .map((b) => Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
                          blurRadius: 6)
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(b.$1, style: const TextStyle(fontSize: 20)),
                      const SizedBox(height: 4),
                      Text(
                        b.$2,
                        style: TextStyle(
                            fontSize: 10,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                            fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ))
          .toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dahil Olanlar Listesi
// ─────────────────────────────────────────────────────────────────────────────

class _IncludedFeaturesList extends StatelessWidget {
  final Color accent;
  const _IncludedFeaturesList({required this.accent});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final features = [
      ('🎯', 'Gelişmiş Filtreler & Taramalar', 'MACD, RSI, Bollinger, Supertrend ve daha fazlası'),
      ('📊', 'SAT SİNYAL ve AL SİNYAL Özelliği', 'Hisseleri otomatik olarak bulur ve listeler'),
      ('🤖', 'AI KAP ve Haberleri', 'Yapay zeka destekli KAP analizi ve haberler'),
      ('🔔', 'Gerçek Zamanlı Alarmlar', 'Fiyat alarmları, anında push bildirimi'),
      ('💼', 'Portföy Kâr/Zarar Takibi', 'Hedef kâra ulaşınca otomatik bildirim'),
      ('⚡', 'Teknik Sinyal Bildirimleri', 'MACD, Supertrend dönüşlerinde anlık uyarı'),
      ('🧩', 'Özel Portföy Analizi', 'Risk dağılımı, sektör ağırlıkları, performans'),
      ('🚀', 'Halka Arz Alarmları', 'Başvuru süreleri dolmadan hatırlatma'),
      ('📈', 'Backtesting Test Et', 'Stratejileri geçmiş verilerle test et ve analiz et'),
    ];

    return Column(
      children: features
          .map((f) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
                        blurRadius: 6)
                  ],
                ),
                child: Row(
                  children: [
                    Text(f.$1, style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(f.$2,
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onSurface)),
                          Text(f.$3,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
                        ],
                      ),
                    ),
                    Icon(Icons.check_circle,
                        color: accent, size: 18),
                  ],
                ),
              ))
          .toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// İptal Politikası
// ─────────────────────────────────────────────────────────────────────────────

class _CancelPolicy extends StatelessWidget {
  final Color accent;
  const _CancelPolicy({required this.accent});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  size: 16),
              const SizedBox(width: 6),
              Text(
                'İptal & İade Politikası',
                style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                    fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '• 10 günlük deneme süresinde 1₺ bile çekilmez.\n'
            '• Deneme süresi içinde istediğiniz zaman iptal edebilirsiniz.\n'
            '• İptal sonrası dönem sonuna kadar erişim devam eder.\n'
            '• Bu uygulama yatırım tavsiyesi niteliği taşımaz.',
            style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                fontSize: 12,
                height: 1.6),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Alt Buton Barı
// ─────────────────────────────────────────────────────────────────────────────

class _PaymentBottomBar extends StatelessWidget {
  final String priceLabel;
  final String trialNote;
  final bool trialUsed;
  final bool processing;
  final Color accent;
  final VoidCallback onTap;

  const _PaymentBottomBar({
    required this.priceLabel,
    required this.trialNote,
    required this.trialUsed,
    required this.processing,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.07),
              blurRadius: 16,
              offset: const Offset(0, -4)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: processing ? null : onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                disabledBackgroundColor: accent.withValues(alpha: 0.5),
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: processing
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      trialUsed
                          ? 'Premium · $priceLabel'
                          : 'Ücretsiz Denemeyi Başlat · $priceLabel',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            trialNote,
            style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Başarı Bottom Sheet
// ─────────────────────────────────────────────────────────────────────────────

class _SuccessSheet extends StatelessWidget {
  final String plan;
  final bool trialUsed;
  final VoidCallback onContinue;

  const _SuccessSheet({
    required this.plan,
    required this.trialUsed,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFF34C759).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text('🎉', style: TextStyle(fontSize: 40)),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Premium\'a Hoş Geldiniz!',
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          if (!trialUsed)
            Text(
              plan == 'monthly'
                  ? '10 günlük ücretsiz denemeniz başladı.\nSonra aylık ₺299 üzerinden devam eder.'
                  : '10 günlük ücretsiz denemeniz başladı.\nSonra yıllık ₺2499 üzerinden devam eder.',
              style: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                  fontSize: 14,
                  height: 1.5),
              textAlign: TextAlign.center,
            ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onContinue,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF34C759),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text(
                'Uygulamayı Keşfet',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
