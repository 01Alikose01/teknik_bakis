import 'package:flutter/material.dart';

/// Tek kullanımlık öğretici balon — kullanıcı "Tamam" deyince kapanır.
///
/// Kullanım:
/// ```dart
/// TutorialTooltip(
///   visible: !SettingsService.isTradingViewTooltipSeen,
///   icon: Icons.show_chart,
///   iconColor: Color(0xFF1565C0),
///   title: 'TradingView Grafiği',
///   body: 'Gelişmiş grafikler için TradingView\'ı açabilirsiniz.',
///   onDismiss: () => SettingsService.markTradingViewTooltipSeen(),
///   child: ElevatedButton(...),
/// )
/// ```
class TutorialTooltip extends StatefulWidget {
  final bool visible;
  final Widget child;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String body;
  final VoidCallback onDismiss;

  const TutorialTooltip({
    super.key,
    required this.visible,
    required this.child,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.body,
    required this.onDismiss,
  });

  @override
  State<TutorialTooltip> createState() => _TutorialTooltipState();
}

class _TutorialTooltipState extends State<TutorialTooltip>
    with SingleTickerProviderStateMixin {
  late bool _show;
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _show = widget.visible;
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _fade  = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

    if (_show) {
      // Kısa gecikmeyle göster — build tamamlandıktan sonra
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _ctrl.forward();
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    await _ctrl.reverse();
    widget.onDismiss();
    if (mounted) setState(() => _show = false);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        widget.child,
        if (_show) ...[
          const SizedBox(height: 8),
          FadeTransition(
            opacity: _fade,
            child: SlideTransition(
              position: _slide,
              child: _TooltipCard(
                icon: widget.icon,
                iconColor: widget.iconColor,
                title: widget.title,
                body: widget.body,
                onDismiss: _dismiss,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _TooltipCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String body;
  final VoidCallback onDismiss;

  const _TooltipCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.body,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final theme    = Theme.of(context);
    final isDark   = theme.brightness == Brightness.dark;

    // Gece/Gündüz'e göre renkler
    final cardBg   = isDark ? const Color(0xFF1C2A1C) : const Color(0xFFE8F5E9);
    final border   = isDark
        ? const Color(0xFF2E7D32).withValues(alpha: 0.6)
        : const Color(0xFF34C759).withValues(alpha: 0.4);
    final titleClr = isDark ? Colors.white : const Color(0xFF1B5E20);
    final bodyClr  = isDark
        ? Colors.white.withValues(alpha: 0.75)
        : const Color(0xFF2E7D32);
    final btnClr   = isDark ? const Color(0xFF34C759) : const Color(0xFF2E7D32);
    final btnBg    = isDark
        ? const Color(0xFF34C759).withValues(alpha: 0.15)
        : const Color(0xFF34C759).withValues(alpha: 0.12);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Üst satır: ikon + başlık + kapat
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: isDark ? 0.18 : 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: titleClr,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              GestureDetector(
                onTap: onDismiss,
                child: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: bodyClr.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Açıklama metni
          Text(
            body,
            style: TextStyle(
              color: bodyClr,
              fontSize: 13,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 10),

          // Tamam butonu
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: onDismiss,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
                decoration: BoxDecoration(
                  color: btnBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: btnClr.withValues(alpha: 0.35),
                    width: 1,
                  ),
                ),
                child: Text(
                  'Anladım',
                  style: TextStyle(
                    color: btnClr,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
