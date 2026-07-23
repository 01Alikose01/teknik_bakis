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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF34C759) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? const Color(0xFF34C759) : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_getIcon(), size: 14, color: isActive ? Colors.white : Colors.grey),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : Colors.black54,
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
