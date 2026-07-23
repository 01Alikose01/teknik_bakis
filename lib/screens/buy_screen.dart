import 'package:flutter/material.dart';
import '../models/asset_model.dart';
import '../models/portfolio_model.dart';
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
    final asset = widget.asset;
    final isPos = asset.changePercent >= 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black87, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(asset.symbol,
            style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
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
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)],
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
                                style: const TextStyle(fontWeight: FontWeight.bold,
                                    fontSize: 18, color: Colors.black87)),
                            Text(asset.name,
                                style: const TextStyle(color: Colors.grey, fontSize: 12),
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
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Alım formu
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Alım Emri',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                  const SizedBox(height: 16),

                  // Fiyat (salt okunur, anlık)
                  _FieldLabel('Fiyat (₺)'),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F2F7),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Text(asset.price.toStringAsFixed(2),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
                                color: Colors.black87)),
                        const Spacer(),
                        const Text('₺', style: TextStyle(color: Colors.grey)),
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
                            color: const Color(0xFFF2F2F7),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.remove, color: Colors.black54),
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
                            fillColor: const Color(0xFFF2F2F7),
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
                      const Text('Toplam Tutar',
                          style: TextStyle(color: Colors.grey, fontSize: 14)),
                      Text('${_total.toStringAsFixed(2)} ₺',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87)),
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
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                child: Text(_saved ? '✓ Portföye Eklendi' : 'Aldım — Portföye Ekle'),
              ),
            ),

            const SizedBox(height: 8),
            const Center(
              child: Text(
                'Bu işlem yatırım tavsiyesi niteliği taşımaz.',
                style: TextStyle(color: Colors.grey, fontSize: 11),
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
