import 'package:flutter/material.dart';
import '../main.dart';
import '../services/app_navigation.dart';
import '../services/subscription_service.dart';
import 'payment_screen.dart';

/// Premium özelliğe erişilmeye çalışıldığında gösterilen duvar ekranı.
/// [embedded] = true ise tam ekran yerine IndexedStack içinde yerleşik gösterilir.
class PremiumGateScreen extends StatefulWidget {
  final Widget nextScreen;
  final bool embedded;
  final bool showGuestOption; // "Misafir Olarak Devam Et" seçeneğini göster
  final bool goToHomeOnFreePlan;
  final VoidCallback? onBack;
  final VoidCallback? onGuestContinue;

  const PremiumGateScreen({
    super.key,
    required this.nextScreen,
    this.embedded = false,
    this.showGuestOption = false,
    this.goToHomeOnFreePlan = false,
    this.onBack,
    this.onGuestContinue,
  });

  @override
  State<PremiumGateScreen> createState() => _PremiumGateScreenState();
}

class _PremiumGateScreenState extends State<PremiumGateScreen> {
  int _selectedPlan = 0; // 0 = Aylık, 1 = Yıllık

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surface = theme.colorScheme.surface;
    final onSurface = theme.colorScheme.onSurface;
    final isExpired = SubscriptionService.isExpiredGuest;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: widget.embedded
          ? null
          : AppBar(
              backgroundColor: theme.scaffoldBackgroundColor,
              elevation: 0,
              leading: GestureDetector(
                onTap: widget.onBack ?? () => Navigator.pop(context),
                child: Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 6),
                    ],
                  ),
                  child: Icon(Icons.arrow_back_ios,
                      size: 16, color: onSurface),
                ),
              ),
            ),
      body: Column(
        children: [
          if (widget.embedded)
            SafeArea(
              top: true,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        if (widget.onBack != null) {
                          widget.onBack!();
                        } else if (Navigator.canPop(context)) {
                          Navigator.pop(context);
                        } else {
                          AppNavigation.goToHome();
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: theme.dividerColor),
                        ),
                        child: Icon(Icons.arrow_back_ios, size: 18, color: onSurface),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Text('Premium Başlat', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(20, widget.embedded ? 16 : 24, 20, 100),
              child: Column(
                children: [
                  // ── Başlık ─────────────────────────────────────────────
                  _GateHeader(isExpired: isExpired),
                  const SizedBox(height: 24),

                  // ── Fiyat kartları ─────────────────────────────────────
                  _PlanRow(
                    selected: _selectedPlan,
                    onSelect: (i) => setState(() => _selectedPlan = i),
                  ),
                  const SizedBox(height: 24),

                  // ── Özellikler ─────────────────────────────────────────
                  const _GateFeatureList(),
                ],
              ),
            ),
          ),
        ],
      ),

      bottomSheet: _GateBottomBar(
        selectedPlan: _selectedPlan,
        onStart: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PaymentScreen(
              plan: _selectedPlan == 0 ? 'monthly' : 'yearly',
              nextScreen: widget.nextScreen,
            ),
          ),
        ),
        onFreePlan: () async {
          final messenger = ScaffoldMessenger.of(context);
          final nav = Navigator.of(context);
          final canStartTrial = widget.showGuestOption || !SubscriptionService.hasUsedTrialBefore;
          if (canStartTrial) {
            await SubscriptionService.startGuestTrial();
          } else {
            await SubscriptionService.selectFreePlan();
          }
          if (!mounted) return;

          // Abonelik durumu değişti — tüm sekmeleri rebuild et
          MainNavigation.refreshSubscription();

          if (widget.onGuestContinue != null) {
            widget.onGuestContinue!();
          } else if (widget.goToHomeOnFreePlan) {
            AppNavigation.goToHome();
            if (nav.canPop()) nav.pop();
          } else if (nav.canPop()) {
            nav.pop();
          } else {
            nav.pushReplacement(
              MaterialPageRoute(builder: (_) => widget.nextScreen),
            );
          }
          messenger.showSnackBar(
            SnackBar(
              content: Text(canStartTrial
                  ? '🎁 10 günlük ücretsiz denemeniz başladı!'
                  : 'Ücretsiz plana geçiyorsunuz.'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: canStartTrial
                  ? const Color(0xFF34C759)
                  : null,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              duration: const Duration(seconds: 3),
            ),
          );
        },
        showGuestOption: widget.showGuestOption,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _GateHeader extends StatelessWidget {
  final bool isExpired;
  const _GateHeader({required this.isExpired});

  @override
  Widget build(BuildContext context) {
    final inTrial = SubscriptionService.isInFreeTrial;
    final daysLeft = SubscriptionService.trialDaysLeft;
    final theme = Theme.of(context);
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Text('👑', style: TextStyle(fontSize: 36)),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          isExpired
              ? 'Deneme Süreniz Doldu'
              : inTrial
                  ? 'Ücretsiz Deneme'
                  : 'Premium Özellik',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          isExpired
              ? 'Bu özelliği kullanmaya devam etmek için\nPremium\'a abone olun.'
              : inTrial
                  ? '$daysLeft gün kaldı — tüm özelliklere şimdi erişebilirsiniz.'
                  : 'Bu özelliği kullanmak için\nPremium\'a abone olun.',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontSize: 14,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _PlanRow extends StatelessWidget {
  final int selected;
  final void Function(int) onSelect;
  const _PlanRow({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MiniPlanCard(
            title: 'Aylık',
            price: '₺299',
            sub: '/ay',
            note: 'Taahhütsüz',
            badge: null,
            isSelected: selected == 0,
            onTap: () => onSelect(0),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MiniPlanCard(
            title: 'Yıllık',
            price: '₺2499',
            sub: '/yıl',
            note: 'Ayda ₺208',
            badge: '%30 İNDİRİM',
            isSelected: selected == 1,
            onTap: () => onSelect(1),
          ),
        ),
      ],
    );
  }
}

class _MiniPlanCard extends StatelessWidget {
  final String title, price, sub, note;
  final String? badge;
  final bool isSelected;
  final VoidCallback onTap;

  const _MiniPlanCard({
    required this.title,
    required this.price,
    required this.sub,
    required this.note,
    required this.badge,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? accent.withValues(alpha: 0.07)
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? accent : theme.dividerColor,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
                color: theme.brightness == Brightness.light
                    ? Colors.black.withValues(alpha: 0.04)
                    : Colors.white.withValues(alpha: 0.03),
                blurRadius: 6),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (badge != null)
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(badge!,
                    style: TextStyle(
                        color: theme.colorScheme.secondary,
                        fontSize: 9,
                        fontWeight: FontWeight.bold)),
              ),
            Text(title,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface)),
            const SizedBox(height: 3),
            Text(price,
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface)),
            Text(sub,
                style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.7), fontSize: 11)),
            const SizedBox(height: 2),
            Text(note,
                style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.7), fontSize: 11)),
            const SizedBox(height: 10),
            Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? accent : Colors.grey.shade400,
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? Center(
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                              shape: BoxShape.circle, color: accent),
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

class _GateFeatureList extends StatelessWidget {
  const _GateFeatureList();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const features = [
      ('🎯', 'Gelişmiş Filtreler & Taramalar', 'MACD, RSI, Bollinger, Tilsön ve fazlasıyla tek tıkla tara'),
      ('📊', 'Gelişmiş Sinyal ve Radar Özelliği', 'Özel Sinyal ve Tarama Sayesinde Hisseleri Otomatik bulur'),
      ('🤖', 'Otomatik AI KAP ve Haberleri', 'Yapay zeka ile portföyünün riskini saniyeler içinde analiz et'),
      ('🔔', 'Gerçek Zamanlı Alarmlar', 'Ekran izlemeye son. Fırsat oluştuğunda anında bildirim al'),
    ];

    return Column(
      children: features
          .map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(f.$1, style: TextStyle(fontSize: 20, color: theme.colorScheme.onSurface)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            f.$2,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontSize: 13,
                              color: theme.colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            f.$3,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 11,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────

class _GateBottomBar extends StatelessWidget {
  final int selectedPlan;
  final VoidCallback onStart;
  final VoidCallback onFreePlan;
  final bool showGuestOption; // Misafir seçeneğini gör/gizle

  const _GateBottomBar({
    required this.selectedPlan,
    required this.onStart,
    required this.onFreePlan,
    this.showGuestOption = false,
  });

  @override
  Widget build(BuildContext context) {
    final priceLabel =
        selectedPlan == 0 ? '₺299/ay' : '₺2499/yıl';

    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
              color: theme.brightness == Brightness.light
                  ? Colors.black.withValues(alpha: 0.06)
                  : Colors.white.withValues(alpha: 0.06),
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
              onPressed: onStart,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(
                'Premium\'u Başlat · $priceLabel',
                style: theme.textTheme.bodyLarge?.copyWith(
                    fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: onFreePlan,
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.primary,
                padding: const EdgeInsets.symmetric(vertical: 12),
                backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.08),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                showGuestOption || !SubscriptionService.hasUsedTrialBefore
                    ? 'Misafir Olarak Devam Et'
                    : 'Ücretsiz\'i Keşfet',
                style: theme.textTheme.bodyMedium?.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'İlk 10 gün ücretsiz. İstediğin zaman iptal et.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

