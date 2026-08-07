import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/subscription_service.dart';
import 'payment_screen.dart';

class OnboardingScreen extends StatefulWidget {
  final Widget nextScreen;
  const OnboardingScreen({super.key, required this.nextScreen});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  int _selectedPlan = 0; // 0 = Aylık, 1 = Yıllık
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _proceed() {
    HapticFeedback.lightImpact();
    // Ödeme ekranına geç — seçili planı gönder
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PaymentScreen(
          plan: _selectedPlan == 0 ? 'monthly' : 'yearly',
          nextScreen: widget.nextScreen,
        ),
      ),
    );
  }

  Future<void> _continueAsGuest() async {
    HapticFeedback.lightImpact();
    await SubscriptionService.startGuestTrial();
    if (!mounted) return;
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
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SafeArea(
          child: Column(
            children: [
              // ── Kaydırılabilir içerik ──
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        const SizedBox(height: 28),

                        // ── Hero görsel + başlık ──
                        _HeroSection(),

                        const SizedBox(height: 28),

                        // ── Fiyat kartları ──
                        _PricingRow(
                          selected: _selectedPlan,
                          onSelect: (i) => setState(() => _selectedPlan = i),
                        ),

                        const SizedBox(height: 28),

                        // ── "Premium'da Neler Var?" başlığı ──
                        const Text(
                          "Premium'da Neler Var?",
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 14),

                        // ── Özellik kartları ──
                        _FeatureCard(
                          emoji: '🎯',
                          color: const Color(0xFFFF6B35),
                          title: 'Gelişmiş Filtreler & Taramalar',
                          subtitle:
                              'MACD, RSI, Bollinger, Tilson ve fazlasıyla tek tıkla tara.',
                        ),
                        _FeatureCard(
                          emoji: '📊',
                          color: const Color(0xFF34C759),
                          title: 'Gelişmiş Sinyal ve Radar Özelliği',
                          subtitle:
                              'Özel Sinyal ve Tarama Sayesinde Hisseleri Otomatik bulur.',
                        ),
                        _FeatureCard(
                          emoji: '🤖',
                          color: const Color(0xFF5856D6),
                          title: 'Otomatik AI KAP ve Haberleri',
                          subtitle:
                              'Otomatik KAP haberleri ve AI destekli KAP analizi anında gör.',
                        ),
                        _FeatureCard(
                          emoji: '🔔',
                          color: const Color(0xFFFF9500),
                          title: 'Gerçek Zamanlı Alarmlar',
                          subtitle:
                              'Ekran izlemeye son. Fırsat oluştuğunda anında bildirim al.',
                        ),
                        _FeatureCard(
                          emoji: '💼',
                          color: const Color(0xFF007AFF),
                          title: 'Portföy Kâr/Zarar Takibi',
                          subtitle:
                              'Alış fiyatından ne kadar uzaklaştığını anlık görüntüle, hedef kâra ulaşınca bildirim al.',
                        ),
                        _FeatureCard(
                          emoji: '⚡',
                          color: const Color(0xFFFFB800),
                          title: 'Teknik Sinyal Bildirimleri',
                          subtitle:
                              'MACD kesişimi, Supertrend dönüşü gibi sinyaller oluştuğunda otomatik bildirim al.',
                        ),
                        _FeatureCard(
                          emoji: '🧩',
                          color: const Color(0xFFFF2D55),
                          title: 'Özel Portföy Analizi',
                          subtitle:
                              'Tüm portföyünün risk dağılımını, sektör ağırlıklarını ve toplam performansını tek ekranda gör.',
                        ),
                        _FeatureCard(
                          emoji: '🚀',
                          color: const Color(0xFF32ADE6),
                          title: 'Halka Arz Alarmları',
                          subtitle:
                              'Yeni halka arz tarihleri ve başvuru süreleri dolmadan önce hatırlatma al.',
                        ),

                        const SizedBox(height: 100), // buton için boşluk
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),

      // ── Sabit alt buton alanı ──
      bottomSheet: _BottomActions(
        selectedPlan: _selectedPlan,
        onStart: _proceed,
        onGuest: _continueAsGuest,
        onRestore: () {},
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hero Bölümü
// ─────────────────────────────────────────────────────────────────────────────

class _HeroSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Uygulama görseli — yuvarlak köşe, gölge
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF34C759).withValues(alpha: 0.22),
                blurRadius: 32,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Image.asset(
              'assets/teknik.jpg',
              width: 120,
              height: 120,
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(height: 18),

        // Hediye ikonu + "10 Gün Bedava" rozeti
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF34C759).withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: const Color(0xFF34C759).withValues(alpha: 0.25)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('🎁', style: TextStyle(fontSize: 16)),
              SizedBox(width: 6),
              Text(
                '10 Gün Tamamen Bedava',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF34C759),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        RichText(
          textAlign: TextAlign.center,
          text: const TextSpan(
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
                height: 1.3),
            children: [
              TextSpan(text: 'Teknik Bakış '),
              TextSpan(
                text: 'Premium',
                style: TextStyle(color: Color(0xFF34C759)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          "Premium'u 10 gün risksiz dene. Beğenmezsen anında iptal et, 1₺ bile çekilmesin.",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey, fontSize: 13, height: 1.45),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Fiyat Kartları Satırı
// ─────────────────────────────────────────────────────────────────────────────

class _PricingRow extends StatelessWidget {
  final int selected;
  final void Function(int) onSelect;

  const _PricingRow({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _PlanCard(
            title: 'Aylık',
            price: '₺299',
            sub: '/ay',
            note: 'Taahhütsüz',
            badge: null,
            discount: null,
            isSelected: selected == 0,
            onTap: () => onSelect(0),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _PlanCard(
            title: 'Yıllık',
            price: '₺2499',
            sub: '/yıl',
            note: 'Ayda ₺208',
            badge: 'AVANTAJLI',
            discount: '%30 İNDİRİM',
            isSelected: selected == 1,
            onTap: () => onSelect(1),
          ),
        ),
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  final String title;
  final String price;
  final String sub;
  final String note;
  final String? badge;
  final String? discount;
  final bool isSelected;
  final VoidCallback onTap;

  const _PlanCard({
    required this.title,
    required this.price,
    required this.sub,
    required this.note,
    required this.badge,
    required this.discount,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF34C759).withValues(alpha: 0.07)
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF34C759)
                : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF34C759).withValues(alpha: 0.12),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                  )
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Badge
            if (badge != null)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9500),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badge!,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5),
                ),
              )
            else
              const SizedBox(height: 22),

            Text(title,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87)),
            const SizedBox(height: 4),
            Text(
              price,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            Text(sub,
                style:
                    const TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 4),
            Text(note,
                style: const TextStyle(
                    color: Colors.black54, fontSize: 12)),

            if (discount != null) ...[
              const SizedBox(height: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9500).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  discount!,
                  style: const TextStyle(
                    color: Color(0xFFFF9500),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 12),

            // Radio
            Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF34C759)
                        : Colors.grey.shade400,
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? Center(
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF34C759),
                          ),
                        ),
                      )
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Özellik Kartı
// ─────────────────────────────────────────────────────────────────────────────

class _FeatureCard extends StatelessWidget {
  final String emoji;
  final Color color;
  final String title;
  final String subtitle;

  const _FeatureCard({
    required this.emoji,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Emoji ikon kutusu
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 22)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Alt Buton Alanı
// ─────────────────────────────────────────────────────────────────────────────

class _BottomActions extends StatelessWidget {
  final int selectedPlan;
  final VoidCallback onStart;
  final VoidCallback onGuest;
  final VoidCallback onRestore;

  const _BottomActions({
    required this.selectedPlan,
    required this.onStart,
    required this.onGuest,
    required this.onRestore,
  });

  @override
  Widget build(BuildContext context) {
    final planLabel = selectedPlan == 0 ? '₺299/ay' : '₺2499/yıl';
    final trialNote = selectedPlan == 0
        ? 'İlk 10 gün ücretsiz. Sonra $planLabel'
        : 'İlk 10 gün ücretsiz. Sonra $planLabel';

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Ana CTA butonu
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onStart,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF34C759),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text(
                'Ücretsiz Denemeye Başla',
                style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Alt not
          Text(
            trialNote,
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 12),

          // Misafir / Geri Yükle
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: onGuest,
                child: const Text(
                  'Misafir Olarak Devam Et',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 13,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Text('·',
                    style: TextStyle(color: Colors.grey, fontSize: 13)),
              ),
              GestureDetector(
                onTap: onRestore,
                child: const Text(
                  'Geri Yükle',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 13,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
