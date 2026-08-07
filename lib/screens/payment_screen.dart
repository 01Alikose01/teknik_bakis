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

  String get _planLabel =>
      widget.plan == 'monthly' ? 'Aylık Plan' : 'Yıllık Plan';
  String get _priceLabel =>
      widget.plan == 'monthly' ? '₺299/ay' : '₺2499/yıl';
  String get _trialNote =>
      'İlk 10 gün ücretsiz. Sonra $_priceLabel';
  Color get _accent => const Color(0xFF34C759);

  Future<void> _processPurchase() async {
    if (_processing) return;
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
    await showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => _SuccessSheet(
        plan: widget.plan,
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
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F5F7),
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 6)
              ],
            ),
            child: const Icon(Icons.arrow_back_ios,
                size: 16, color: Colors.black87),
          ),
        ),
        title: Text(
          _planLabel,
          style: const TextStyle(
              color: Colors.black87,
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
              accent: _accent,
            ),
            const SizedBox(height: 24),

            // ── Güven rozetleri ───────────────────────────────────────────
            _TrustBadges(accent: _accent),
            const SizedBox(height: 24),

            // ── Dahil olanlar ─────────────────────────────────────────────
            const Text(
              'Planınıza Dahil Olanlar',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87),
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
  final Color accent;

  const _PlanSummaryCard({
    required this.plan,
    required this.priceLabel,
    required this.trialNote,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
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
                  style:
                      const TextStyle(color: Colors.grey, fontSize: 14)),
              ),
              if (isYearly) ...[
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Ayda sadece',
                        style: TextStyle(color: Colors.grey, fontSize: 11)),
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
              Text(
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
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 6)
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(b.$1, style: const TextStyle(fontSize: 20)),
                      const SizedBox(height: 4),
                      Text(
                        b.$2,
                        style: const TextStyle(
                            fontSize: 10,
                            color: Colors.black54,
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
    final features = [
      ('🎯', 'Gelişmiş Filtreler & Taramalar', 'MACD, RSI, Bollinger, Supertrend ve daha fazlası'),
      ('📊', 'Sinyal & Radar Özelliği', 'Hisseleri otomatik olarak bulur ve listeler'),
      ('🤖', 'AI KAP ve Haberleri', 'Yapay zeka destekli KAP analizi ve haberler'),
      ('🔔', 'Gerçek Zamanlı Alarmlar', 'Fiyat alarmları, anında push bildirimi'),
      ('💼', 'Portföy Kâr/Zarar Takibi', 'Hedef kâra ulaşınca otomatik bildirim'),
      ('⚡', 'Teknik Sinyal Bildirimleri', 'MACD, Supertrend dönüşlerinde anlık uyarı'),
      ('🧩', 'Özel Portföy Analizi', 'Risk dağılımı, sektör ağırlıkları, performans'),
      ('🚀', 'Halka Arz Alarmları', 'Başvuru süreleri dolmadan hatırlatma'),
    ];

    return Column(
      children: features
          .map((f) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
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
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87)),
                          Text(f.$3,
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.grey)),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.grey, size: 16),
              SizedBox(width: 6),
              Text(
                'İptal & İade Politikası',
                style: TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '• 10 günlük deneme süresinde 1₺ bile çekilmez.\n'
            '• Deneme süresi içinde istediğiniz zaman iptal edebilirsiniz.\n'
            '• İptal sonrası dönem sonuna kadar erişim devam eder.\n'
            '• Bu uygulama yatırım tavsiyesi niteliği taşımaz.',
            style: TextStyle(
                color: Colors.grey, fontSize: 12, height: 1.6),
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
  final bool processing;
  final Color accent;
  final VoidCallback onTap;

  const _PaymentBottomBar({
    required this.priceLabel,
    required this.trialNote,
    required this.processing,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
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
                      'Ücretsiz Denemeyi Başlat · $priceLabel',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            trialNote,
            style: const TextStyle(color: Colors.grey, fontSize: 12),
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
  final VoidCallback onContinue;

  const _SuccessSheet({required this.plan, required this.onContinue});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Başarı animasyonu yerine emoji
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
          const Text(
            'Premium\'a Hoş Geldiniz!',
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black87),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            plan == 'monthly'
                ? '10 günlük ücretsiz denemeniz başladı.\nSonra aylık ₺299 üzerinden devam eder.'
                : '10 günlük ücretsiz denemeniz başladı.\nSonra yıllık ₺2499 üzerinden devam eder.',
            style: const TextStyle(
                color: Colors.grey, fontSize: 14, height: 1.5),
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
                style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
