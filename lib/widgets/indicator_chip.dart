import 'package:flutter/material.dart';

class IndicatorChip extends StatelessWidget {
  final String label;
  final String iconType;
  final bool isActive;
  final VoidCallback onTap;

  const IndicatorChip({
    super.key,
    required this.label,
    required this.iconType,
    required this.isActive,
    required this.onTap,
  });

  IconData _getIcon() {
    switch (iconType) {
      case 'rsi':  return Icons.show_chart;
      case 'ma':   return Icons.trending_up;
      case 'st':   return Icons.bolt;
      case 'vol':  return Icons.bar_chart;
      case 'macd': return Icons.stacked_line_chart;
      case 'boll': return Icons.align_vertical_center;
      default:     return Icons.analytics;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme   = Theme.of(context);
    final isDark  = theme.brightness == Brightness.dark;

    final activeBg     = const Color(0xFF34C759);
    final inactiveBg   = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final inactiveBorder = isDark
        ? Colors.white.withValues(alpha: 0.15)
        : Colors.grey.shade300;
    final inactiveIcon  = isDark
        ? Colors.white.withValues(alpha: 0.45)
        : Colors.grey;
    final inactiveText  = isDark
        ? Colors.white.withValues(alpha: 0.60)
        : Colors.black54;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? activeBg : inactiveBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? activeBg : inactiveBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _getIcon(),
              size: 14,
              color: isActive ? Colors.white : inactiveIcon,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : inactiveText,
                fontSize: 13,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
