import 'package:flutter/material.dart';
import '../models/asset_model.dart';

/// Fiyat, günlük değişim % ve OHLC — StockService'ten gelen AssetModel ile kullanılır.
class StockQuotePanel extends StatelessWidget {
  final AssetModel asset;
  final bool showDivider;

  const StockQuotePanel({
    super.key,
    required this.asset,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPos = asset.changePercent >= 0;
    final priceColor =
        isPos ? const Color(0xFF34C759) : const Color(0xFFFF3B30);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showDivider) ...[
          const Divider(height: 1, color: Color(0xFFF2F2F7)),
          const SizedBox(height: 10),
        ],
        Row(
          children: [
            _OhlcCell(
              label: 'Açılış',
              value: asset.open > 0
                  ? asset.open.toStringAsFixed(2)
                  : asset.price.toStringAsFixed(2),
              color: theme.colorScheme.onSurface.withOpacity(0.9),
            ),
            _OhlcCell(
              label: 'Yüksek',
              value: asset.high > 0
                  ? asset.high.toStringAsFixed(2)
                  : '—',
              color: const Color(0xFF34C759),
            ),
            _OhlcCell(
              label: 'Düşük',
              value:
                  asset.low > 0 ? asset.low.toStringAsFixed(2) : '—',
              color: const Color(0xFFFF3B30),
            ),
            _OhlcCell(
              label: 'Anlık',
              value: asset.price.toStringAsFixed(2),
              color: priceColor,
              isBold: true,
            ),
          ],
        ),
      ],
    );
  }
}

class StockPriceChangeBadge extends StatelessWidget {
  final AssetModel asset;
  final double? fontSize;

  const StockPriceChangeBadge({
    super.key,
    required this.asset,
    this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    final isPos = asset.changePercent >= 0;
    final color =
        isPos ? const Color(0xFF34C759) : const Color(0xFFFF3B30);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '${isPos ? '+' : ''}${asset.changePercent.toStringAsFixed(2)}%',
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize ?? 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class StockPriceHeader extends StatelessWidget {
  final AssetModel asset;

  const StockPriceHeader({super.key, required this.asset});

  @override
  Widget build(BuildContext context) {
    final isPos = asset.changePercent >= 0;
    final priceColor =
        isPos ? const Color(0xFF34C759) : const Color(0xFFFF3B30);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          '${asset.price.toStringAsFixed(2)} ₺',
          style: TextStyle(
            color: priceColor,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(width: 8),
        StockPriceChangeBadge(asset: asset),
      ],
    );
  }
}

class _OhlcCell extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool isBold;

  const _OhlcCell({
    required this.label,
    required this.value,
    required this.color,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
