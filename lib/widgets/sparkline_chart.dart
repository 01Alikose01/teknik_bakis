import 'package:flutter/material.dart';

/// Küçük çizgi grafik (sparkline) — Takip listesinde hisse başına gösterilir.
/// [prices] boşsa widget görünmez.
/// [color] belirtilmezse değişime göre otomatik seçilir: yeşil / kırmızı / sarı.
class SparklineChart extends StatelessWidget {
  final List<double> prices;
  final Color? color;
  final double width;
  final double height;
  final double strokeWidth;

  const SparklineChart({
    super.key,
    required this.prices,
    this.color,
    this.width = 80,
    this.height = 36,
    this.strokeWidth = 1.5,
  });

  /// changePercent'e göre renk döner
  static Color colorFor(double changePercent) {
    if (changePercent > 0) return const Color(0xFF34C759);
    if (changePercent < 0) return const Color(0xFFFF3B30);
    return const Color(0xFFFF9500); // nötr / sıfır
  }

  @override
  Widget build(BuildContext context) {
    if (prices.length < 2) return SizedBox(width: width, height: height);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lineColor = color ?? const Color(0xFF34C759);

    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _SparklinePainter(
          prices: prices,
          color: lineColor,
          strokeWidth: strokeWidth,
          isDark: isDark,
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> prices;
  final Color color;
  final double strokeWidth;
  final bool isDark;

  _SparklinePainter({
    required this.prices,
    required this.color,
    required this.strokeWidth,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (prices.length < 2) return;

    double minVal = prices.reduce((a, b) => a < b ? a : b);
    double maxVal = prices.reduce((a, b) => a > b ? a : b);
    final range = maxVal - minVal;

    // Çok düz çizgi: biraz padding ekle
    final effectiveMin = range < 0.001 ? minVal - 1 : minVal;
    final effectiveMax = range < 0.001 ? maxVal + 1 : maxVal;
    final effectiveRange = effectiveMax - effectiveMin;

    final vertPad = size.height * 0.12;
    final usableHeight = size.height - vertPad * 2;

    Offset toOffset(int i, double price) {
      final x = size.width * i / (prices.length - 1);
      final y = vertPad +
          usableHeight * (1 - (price - effectiveMin) / effectiveRange);
      return Offset(x, y);
    }

    // Dolgu alanı (fill)
    final fillPath = Path();
    fillPath.moveTo(0, size.height);
    for (int i = 0; i < prices.length; i++) {
      final o = toOffset(i, prices[i]);
      if (i == 0) {
        fillPath.lineTo(o.dx, o.dy);
      } else {
        fillPath.lineTo(o.dx, o.dy);
      }
    }
    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withValues(alpha: isDark ? 0.18 : 0.12),
          color.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, fillPaint);

    // Çizgi
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final linePath = Path();
    for (int i = 0; i < prices.length; i++) {
      final o = toOffset(i, prices[i]);
      if (i == 0) {
        linePath.moveTo(o.dx, o.dy);
      } else {
        linePath.lineTo(o.dx, o.dy);
      }
    }
    canvas.drawPath(linePath, linePaint);

    // Son nokta
    final lastOffset = toOffset(prices.length - 1, prices.last);
    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(lastOffset, strokeWidth + 0.8, dotPaint);
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      old.prices != prices || old.color != color || old.isDark != isDark;
}
