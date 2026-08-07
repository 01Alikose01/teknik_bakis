import 'package:flutter/material.dart';
import '../models/asset_model.dart';
import '../models/portfolio_model.dart';
import '../widgets/stock_quote_panel.dart';
import '../services/portfolio_service.dart';

class BuyScreen extends StatefulWidget {
  final AssetModel asset;

  const BuyScreen({super.key, required this.asset});

  @override
  State<BuyScreen> createState() => _BuyScreenState();
}

class _BuyScreenState extends State<BuyScreen> {
  final TextEditingController _qtyCtrl = TextEditingController(text: '1');
  bool _saved = false;

  double get _qty => double.tryParse(_qtyCtrl.text.replaceAll(',', '.')) ?? 0;
  double get _total => _qty * widget.asset.price;

  void _increment() => setState(() {
    final v = (_qty + 1);
    _qtyCtrl.text = v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(2);
  });

  void _decrement() {
    if (_qty <= 1) return;
    setState(() {
      final v = (_qty - 1);
      _qtyCtrl.text = v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(2);
    });
  }

  Future<void> _buy() async {
    if (_qty <= 0) return;
    await PortfolioService.addPortfolioItem(PortfolioItem(
      symbol: widget.asset.symbol,
      name: widget.asset.name,
      buyPrice: widget.asset.price,
      quantity: _qty,
      buyDate: DateTime.now(),
    ));
    setState(() => _saved = true);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${widget.asset.symbol} portföye eklendi!'),
          backgroundColor: const Color(0xFF34C759),
          behavior: SnackBarBehavior.floating,
        ),
      );
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) Navigator.pop(context, true);
    }
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final asset = widget.asset;
    final isPos = asset.changePercent >= 0;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: theme.colorScheme.onSurface, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(asset.symbol,
            style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hisse bilgi kartı
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.05), blurRadius: 8)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48, height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFF34C759).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            asset.symbol.length > 4 ? asset.symbol.substring(0, 4) : asset.symbol,
                            style: const TextStyle(
                                color: Color(0xFF34C759), fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(asset.symbol,
                                style: TextStyle(fontWeight: FontWeight.bold,
                                    fontSize: 18, color: theme.colorScheme.onSurface)),
                            Text(asset.name,
                                style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.7), fontSize: 12),
                                overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _InfoItem(label: 'Anlık Fiyat',
                          value: '${asset.price.toStringAsFixed(2)} ₺',
                          valueColor: isPos ? const Color(0xFF34C759) : const Color(0xFFFF3B30)),
                      _InfoItem(label: 'Değişim',
                          value: '${isPos ? '+' : ''}${asset.changePercent.toStringAsFixed(2)}%',
                          valueColor: isPos ? const Color(0xFF34C759) : const Color(0xFFFF3B30)),
                      _InfoItem(label: '52H En Yüksek',
                          value: '${asset.high52w.toStringAsFixed(2)} ₺',
                          valueColor: Colors.black87),
                      _InfoItem(label: '52H En Düşük',
                          value: '${asset.low52w.toStringAsFixed(2)} ₺',
                          valueColor: Colors.black87),
                    ],
                  ),
                  StockQuotePanel(asset: asset, showDivider: true),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Alım formu
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.05), blurRadius: 8)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Alım Emri',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: theme.colorScheme.onSurface)),
                  const SizedBox(height: 16),

                  // Fiyat (salt okunur, anlık)
                  _FieldLabel('Fiyat (₺)'),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Text(asset.price.toStringAsFixed(2),
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface)),
                        const Spacer(),
                        Text('₺', style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.7))),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Adet girişi
                  _FieldLabel('Adet'),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      // Azalt
                      GestureDetector(
                        onTap: _decrement,
                        child: Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceVariant,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.remove, color: theme.colorScheme.onSurface.withOpacity(0.7)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _qtyCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: theme.colorScheme.surfaceVariant,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Artır
                      GestureDetector(
                        onTap: _increment,
                        child: Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFF34C759),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.add, color: Colors.white),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 16),

                  // Toplam
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Toplam Tutar',
                          style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.65), fontSize: 14)),
                      Text('${_total.toStringAsFixed(2)} ₺',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 18, color: theme.colorScheme.onSurface)),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Aldım butonu
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saved ? null : _buy,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF34C759),
                  foregroundColor: theme.colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                child: Text(_saved ? '✓ Portföye Eklendi' : 'Aldım — Portföye Ekle'),
              ),
            ),

            const SizedBox(height: 8),
            Center(
              child: Text(
                'Bu işlem yatırım tavsiyesi niteliği taşımaz.',
                style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.65), fontSize: 11),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  final String label, value;
  final Color valueColor;
  const _InfoItem({required this.label, required this.value, required this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(color: valueColor, fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(color: Colors.grey, fontSize: 13));
  }
}

