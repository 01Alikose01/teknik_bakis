import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart';
import '../services/settings_service.dart';
import '../services/subscription_service.dart';

class SettingsScreen extends StatefulWidget {
  final VoidCallback? onUpgrade;
  const SettingsScreen({super.key, this.onUpgrade});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final onSurfaceSecondary = onSurface.withValues(alpha: 0.75);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Başlık + profil görseli
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ayarlar',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: onSurface)),
                  const SizedBox(height: 16),
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(50),
                      child: Image.asset(
                        'assets/tek.png',
                        width: 180,
                        height: 180,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text('Teknik Bakış',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: onSurface)),
                  ),
                  Center(
                    child: Text('v1.0.0',
                        style: TextStyle(color: onSurfaceSecondary, fontSize: 13)),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  // ── Premium Durum Kartı ──────────────────────────────
                  _PremiumStatusCard(onUpgrade: widget.onUpgrade),
                  const SizedBox(height: 20),

                  _SectionLabel('Görünüm'),
                  ValueListenableBuilder<bool>(
                    valueListenable: SettingsService.darkMode,
                    builder: (context, isDark, _) {
                      return _SettingsGroup(items: [
                        _SettingsItem(
                          title: isDark ? 'Gece Modu' : 'Gündüz Modu',
                          leadingIcon: Icons.brightness_6_outlined,
                          leadingColor: const Color(0xFF34C759),
                          trailing: Switch(
                            value: isDark,
                            activeThumbColor: const Color(0xFF34C759),
                            onChanged: (value) async {
                              await SettingsService.setDarkMode(value);
                              setState(() {});
                            },
                          ),
                          onTap: () async {
                            await SettingsService.setDarkMode(!isDark);
                            setState(() {});
                          },
                        ),
                      ]);
                    },
                  ),

                  const SizedBox(height: 20),
                  _SectionLabel('Hakkında'),
                  _SettingsGroup(items: [
                    _SettingsItem(
                      title: 'Uygulama Hakkında',
                      onTap: () => _showAbout(context),
                    ),
                    _SettingsItem(
                      title: 'Sürüm',
                      trailing: const Text('1.0.0', style: TextStyle(color: Colors.grey)),
                    ),
                  ]),

                  const SizedBox(height: 20),
                  _SectionLabel('Bildirimler'),
                  _SettingsGroup(items: [
                    _SettingsItem(
                      title: 'Bildirim İzinlerini Yönet',
                      leadingIcon: Icons.notifications_outlined,
                      leadingColor: const Color(0xFF34C759),
                      trailingIcon: Icons.open_in_new,
                      onTap: () async {
                        await SystemNavigator.pop();
                      },
                    ),
                  ]),

                  const SizedBox(height: 20),
                  _SectionLabel('Yardım & Destek'),
                  _SettingsGroup(items: [
                    _SettingsItem(
                      title: 'SSS',
                      onTap: () => _showSss(context),
                    ),
                  ]),

                  const SizedBox(height: 20),
                  _SectionLabel('Teknik Bakış Partneri'),
                  _SettingsGroup(items: [
                    _SettingsItem(
                      title: 'Partnerlik Programı',
                      onTap: () {},
                    ),
                  ]),

                  const SizedBox(height: 20),
                  _SectionLabel('Abonelik'),
                  _SettingsGroup(items: [
                    _SettingsItem(
                      title: 'Planları Görüntüle',
                      onTap: () => _showPlansSheet(context),
                    ),
                    _SettingsItem(
                      title: 'Yasal Uyarı',
                      onTap: () => _showLegal(context),
                    ),
                  ]),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAbout(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Teknik Bakış Hakkında'),
        content: const Text(
            'Teknik Bakış, BIST hisselerini teknik analiz göstergeleriyle tarayan ve yatırım kararlarınızı destekleyen bir mobil uygulamadır.\n\n'
            'Sürüm: 1.0.0\n'
            'Bu uygulama yatırım tavsiyesi niteliği taşımaz.'),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Kapat'))],
      ),
    );
  }

  void _showSss(BuildContext context) {
    final theme = Theme.of(context);
    final surface = theme.colorScheme.surface;

    showModalBottomSheet(
      context: context,
      backgroundColor: surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('Sık Sorulan Sorular', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            _FaqItem(q: 'Veriler güncel mi?', a: 'Evet, veriler Yahoo Finance üzerinden gerçek zamanlı çekilmektedir (15 dk gecikme).'),
            _FaqItem(q: 'Tarama nasıl çalışır?', a: 'BIST hisselerini seçili teknik göstergeye göre filtreler ve uygun hisseleri listeler.'),
            _FaqItem(q: 'RSI nasıl hesaplanır?', a: 'Wilder\'ın Smoothed RSI yöntemi kullanılır (14 periyot).'),
          ],
        ),
      ),
    );
  }

  void _showPlansSheet(BuildContext context) {
    final theme = Theme.of(context);
    final surface = theme.colorScheme.surface;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.88,
        maxChildSize: 0.95,
        builder: (_, ctrl) => SingleChildScrollView(
          controller: ctrl,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        'Planlar & Özellikler',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 36),
                ],
              ),
              const SizedBox(height: 4),
              Center(
                child: Text(
                  'Hangi plan size uygun?',
                  style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.7), fontSize: 13),
                ),
              ),
                const SizedBox(height: 24),

                // ── Aylık Plan ──────────────────────────────────────────
                _PlanDetailCard(
                  emoji: '📅',
                  title: 'Aylık Plan',
                  price: '₺299',
                  period: '/ay',
                  badge: SubscriptionService.plan == 'monthly' ? 'SEÇİLİ' : null,
                  badgeColor: SubscriptionService.plan == 'monthly' ? const Color(0xFF34C759) : null,
                  note: 'Taahhütsüz • İstediğin zaman iptal',
                  trialNote: '🎁 İlk 10 gün ücretsiz',
                  accent: const Color(0xFF34C759),
                  features: const [
                    '✅ Sınırsız Radar Taraması',
                    '✅ AI Sinyal (RSI, EMA, MA)',
                    '✅ AI KAP Analizi',
                    '✅ Sınırsız Fiyat Alarmı',
                    '✅ Tüm Teknik Formasyonlar',
                    '✅ Halka Arz Takibi & Alarmı',
                    '✅ Haberler & KAP Bildirimleri',
                    '✅ Anlık Push Bildirimleri',
                  ],
                  onTap: () async {
                    await SubscriptionService.selectMonthlyPlan();
                    MainNavigation.refreshSubscription();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Aylık Plan seçildi. 10 gün ücretsiz deneme başlıyor!'),
                          backgroundColor: const Color(0xFF34C759),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                      Navigator.of(context).pop();
                    }
                  },
                ),
                const SizedBox(height: 12),

                // ── Yıllık Plan ──────────────────────────────────────────
                _PlanDetailCard(
                  emoji: '🏆',
                  title: 'Yıllık Plan',
                  price: '₺2499',
                  period: '/yıl',
                  badge: SubscriptionService.plan == 'yearly' ? 'SEÇİLİ' : '%30 İNDİRİM',
                  badgeColor: SubscriptionService.plan == 'yearly' ? const Color(0xFF34C759) : const Color(0xFFFF9500),
                  note: 'Ayda sadece ₺208 • En avantajlı',
                  trialNote: '🎁 İlk 10 gün ücretsiz',
                  accent: const Color(0xFFFF9500),
                  features: const [
                    '✅ Aylık plandaki her şey',
                    '✅ %30 daha ucuz',
                    '✅ Yıllık öncelikli destek',
                  ],
                  onTap: () async {
                    await SubscriptionService.selectYearlyPlan();
                    MainNavigation.refreshSubscription();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Yıllık Plan seçildi. 10 gün ücretsiz deneme başlıyor!'),
                          backgroundColor: const Color(0xFFFF9500),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                      Navigator.of(context).pop();
                    }
                  },
                ),
                const SizedBox(height: 16),

                // ── Ücretsiz Kullanım ─────────────────────────────────────
                GestureDetector(
                  onTap: () async {
                    await SubscriptionService.selectFreePlan();
                    MainNavigation.refreshSubscription();
                    if (!context.mounted) return;
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Ücretsiz plana geçildi.'),
                        behavior: SnackBarBehavior.floating,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: SubscriptionService.isFreePlanSelected
                            ? const Color(0xFF007AFF)
                            : const Color(0xFF007AFF).withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF007AFF).withValues(alpha: 0.08),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF007AFF).withValues(alpha: 0.08),
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                          ),
                          child: Row(
                            children: [
                              const Text('🆓', style: TextStyle(fontSize: 22)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Ücretsiz Plan',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF007AFF),
                                      ),
                                    ),
                                    Text(
                                      'Temel kullanım • Premium olmayan alanlar',
                                      style: TextStyle(
                                        color: const Color(0xFF007AFF).withValues(alpha: 0.75),
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _FreePlanListItem(text: '✅ Temel ekran ve pano erişimi'),
                              const _FreePlanListItem(text: '✅ Sınırlı radar ve analiz özelliği'),
                              const _FreePlanListItem(text: '✅ Halka arz listesi ve temel takibi'),
                              const _FreePlanListItem(text: '⚠️ Premium özellikler kilitli kalır'),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () async {
                                await SubscriptionService.selectFreePlan();
                                setState(() {});
                                if (!context.mounted) return;
                                Navigator.of(context).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text('Ücretsiz plana geçildi.'),
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF007AFF),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 13),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('Ücretsiz\'i Keşfet', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Yasal not
                const Text(
                  '* 10 günlük deneme süresinde kart bilgisi alınmaz, 1₺ bile çekilmez. '
                  'Deneme bitmeden iptal ederseniz hiçbir ücret ödenmez.',
                  style: TextStyle(color: Colors.grey, fontSize: 11, height: 1.5),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

  void _showLegal(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Yasal Uyarı'),
        content: const Text(
            'Bu uygulama yalnızca bilgilendirme amaçlıdır. Yatırım tavsiyesi niteliği taşımaz. '
            'Yatırım kararlarınızdan doğan her türlü sonuç kullanıcıya aittir.'),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Anladım'))],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    final onSurfaceSecondary = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: TextStyle(color: onSurfaceSecondary, fontSize: 13)),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  final List<_SettingsItem> items;
  const _SettingsGroup({required this.items});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: theme.brightness == Brightness.light ? Colors.black.withValues(alpha: 0.04) : Colors.white.withValues(alpha: 0.03), blurRadius: 6)],
      ),
      child: Column(
        children: items.asMap().entries.map((e) {
          final i = e.key;
          final item = e.value;
          return Column(
            children: [
              item,
              if (i < items.length - 1)
                const Divider(height: 1, indent: 16, endIndent: 16),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _SettingsItem extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final IconData? leadingIcon;
  final Color? leadingColor;
  final IconData? trailingIcon;
  final VoidCallback? onTap;

  const _SettingsItem({
    required this.title,
    this.trailing,
    this.leadingIcon,
    this.leadingColor,
    this.trailingIcon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      onTap: onTap,
      leading: leadingIcon != null
          ? Icon(leadingIcon, color: leadingColor ?? theme.colorScheme.onSurface.withValues(alpha: 0.65), size: 20)
          : null,
      title: Text(title, style: TextStyle(fontSize: 15, color: theme.colorScheme.onSurface)),
      trailing: trailing ??
          (onTap != null
              ? Icon(trailingIcon ?? Icons.chevron_right, color: theme.colorScheme.onSurface.withValues(alpha: 0.65), size: 20)
              : null),
    );
  }
}

class _FaqItem extends StatelessWidget {
  final String q, a;
  const _FaqItem({required this.q, required this.a});

  @override
  Widget build(BuildContext context) {
    final onSurfaceSecondary = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(q, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 2),
          Text(a, style: TextStyle(color: onSurfaceSecondary, fontSize: 12)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Premium Durum Kartı
// ─────────────────────────────────────────────────────────────────────────────

class _PremiumStatusCard extends StatelessWidget {
  final VoidCallback? onUpgrade;
  const _PremiumStatusCard({this.onUpgrade});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPaid       = SubscriptionService.isPaidSubscriber;
    final isInTrial    = SubscriptionService.isInFreeTrial;
    final isExpired    = SubscriptionService.isExpiredGuest;
    final daysLeft     = SubscriptionService.trialDaysLeft;
    final plan         = SubscriptionService.plan;

    // Renk & ikon & mesaj
    final Color bgColor;
    final Color borderColor;
    final String emoji;
    final String title;
    final String subtitle;
    final bool showButton;

    if (isPaid) {
      bgColor     = const Color(0xFF34C759).withValues(alpha: 0.08);
      borderColor = const Color(0xFF34C759).withValues(alpha: 0.3);
      emoji       = '👑';
      title       = plan == 'yearly' ? 'Premium · Yıllık Plan' : 'Premium · Aylık Plan';
      subtitle    = 'Tüm özelliklere tam erişiminiz var.';
      showButton  = false;
    } else if (isInTrial) {
      bgColor     = const Color(0xFF007AFF).withValues(alpha: 0.07);
      borderColor = const Color(0xFF007AFF).withValues(alpha: 0.25);
      emoji       = '🎁';
      title       = 'Ücretsiz Deneme';
      subtitle    = '$daysLeft gün kaldı — Tüm özelliklere erişebilirsiniz.';
      showButton  = true;
    } else if (isExpired) {
      bgColor     = const Color(0xFFFF9500).withValues(alpha: 0.08);
      borderColor = const Color(0xFFFF9500).withValues(alpha: 0.3);
      emoji       = '⚠️';
      title       = 'Deneme Süreniz Doldu';
      subtitle    = 'Premium\'a geçerek tüm özellikleri kullanmaya devam edin.';
      showButton  = true;
    } else {
      bgColor     = theme.colorScheme.surface;
      borderColor = theme.dividerColor;
      emoji       = '🔒';
      title       = 'Ücretsiz Kullanıcı';
      subtitle    = 'Premium\'a geçerek tüm özelliklerin kilidini açın.';
      showButton  = true;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: theme.colorScheme.onSurface)),
                const SizedBox(height: 3),
                Text(subtitle,
                    style: TextStyle(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.7), fontSize: 12, height: 1.4)),
              ],
            ),
          ),
          if (showButton && onUpgrade != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onUpgrade,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFF34C759),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Yükselt',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Plan Detay Kartı (Aylık / Yıllık)
// ─────────────────────────────────────────────────────────────────────────────

class _PlanDetailCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String price;
  final String period;
  final String? badge;
  final Color? badgeColor;
  final String note;
  final String trialNote;
  final Color accent;
  final List<String> features;
  final VoidCallback? onTap;

  const _PlanDetailCard({
    required this.emoji,
    required this.title,
    required this.price,
    required this.period,
    required this.badge,
    required this.badgeColor,
    required this.note,
    required this.trialNote,
    required this.accent,
    required this.features,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.35), width: 1.5),
        boxShadow: [
          BoxShadow(
              color: accent.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Üst şerit
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.08),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(title,
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: accent)),
                        if (badge != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: badgeColor,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(badge!,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ],
                    ),
                    Text(note,
                        style: TextStyle(
                            color: accent.withValues(alpha: 0.75),
                            fontSize: 11)),
                  ],
                ),
                const Spacer(),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                          text: price,
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: accent)),
                      TextSpan(
                          text: period,
                          style: TextStyle(
                              fontSize: 12,
                              color: accent.withValues(alpha: 0.7))),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Deneme notu
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Text(trialNote,
                style: TextStyle(
                    color: accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ),

          // Özellik listesi
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: features
                  .map((f) => Padding(
                        padding: const EdgeInsets.only(bottom: 5),
                        child: Text(f,
                            style: TextStyle(
                                fontSize: 13,
                                color: theme.colorScheme.onSurface,
                                height: 1.3)),
                      ))
                  .toList(),
            ),
          ),

          // Buton
          if (onTap != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onTap,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    'Ücretsiz Dene · $price$period',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Ücretsiz Plan Kartı — 10 günlük deneme içeriği
// ─────────────────────────────────────────────────────────────────────────────

class _FreePlanListItem extends StatelessWidget {
  final String text;
  const _FreePlanListItem({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface, height: 1.3),
      ),
    );
  }
}


