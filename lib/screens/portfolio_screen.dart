import 'package:flutter/material.dart';
import '../models/portfolio_model.dart';
import '../services/portfolio_service.dart';
import '../services/stock_service.dart';

// ─────────────────────────────────────────────
// Gruplu hisse modeli (aynı sembol = bir grup)
// ─────────────────────────────────────────────

class _StockGroup {
  final String symbol;
  final String name;
  final List<PortfolioItem> lots; // her alış kaydı

  _StockGroup({required this.symbol, required this.name, required this.lots});

  // Toplam adet
  double get totalQty => lots.fold(0.0, (s, l) => s + l.quantity);

  // Toplam maliyet
  double get totalCost => lots.fold(0.0, (s, l) => s + l.totalCost());

  // Ortalama alış fiyatı (ağırlıklı)
  double get avgPrice => totalQty > 0 ? totalCost / totalQty : 0;

  // Anlık değer
  double totalValue(double currentPrice) => currentPrice * totalQty;

  // Kar/Zarar TL
  double profit(double currentPrice) => totalValue(currentPrice) - totalCost;

  // Kar/Zarar %
  double profitPercent(double currentPrice) =>
      totalCost > 0 ? (profit(currentPrice) / totalCost) * 100 : 0;
}

// ─────────────────────────────────────────────
// Ana Portföy Ekranı
// ─────────────────────────────────────────────

class PortfolioScreen extends StatefulWidget {
  const PortfolioScreen({super.key});

  @override
  State<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends State<PortfolioScreen> {
  List<_StockGroup> _groups = [];
  Map<String, double> _currentPrices = {};
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadPortfolio();
  }

  Future<void> _loadPortfolio() async {
    setState(() => _loading = true);
    final all = PortfolioService.getPortfolio();

    // Sembol bazında grupla
    final map = <String, List<PortfolioItem>>{};
    for (final item in all) {
      map.putIfAbsent(item.symbol, () => []).add(item);
    }
    final groups = map.entries.map((e) => _StockGroup(
      symbol: e.key,
      name: e.value.first.name,
      lots: e.value..sort((a, b) => b.buyDate.compareTo(a.buyDate)),
    )).toList();

    // Fiyatları çek
    final prices = <String, double>{};
    for (final g in groups) {
      final asset = await StockService.fetchStock(g.symbol, period: '5d');
      if (asset != null) prices[g.symbol] = asset.price;
      if (mounted) setState(() => _currentPrices = Map.from(prices));
    }

    if (mounted) setState(() { _groups = groups; _loading = false; });
  }

  // Toplam portföy değerleri
  double get _totalCost =>
      _groups.fold(0.0, (s, g) => s + g.totalCost);
  double get _totalValue =>
      _groups.fold(0.0, (s, g) =>
          s + g.totalValue(_currentPrices[g.symbol] ?? g.avgPrice));
  double get _totalProfit => _totalValue - _totalCost;
  double get _totalProfitPct =>
      _totalCost > 0 ? (_totalProfit / _totalCost) * 100 : 0;

  void _showAddDialog() {
    showDialog(
      context: context,
      builder: (_) => _AddPortfolioDialog(
        onAdd: (item) async {
          await PortfolioService.addPortfolioItem(item);
          _loadPortfolio();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isProfit = _totalProfit >= 0;
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        backgroundColor: const Color(0xFF34C759),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: const Color(0xFF34C759),
          onRefresh: _loadPortfolio,
          child: CustomScrollView(slivers: [

            // Başlık
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Row(children: [
                if (Navigator.canPop(context))
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 4)]),
                      child: const Icon(Icons.arrow_back_ios,
                          size: 16, color: Colors.black87),
                    ),
                  ),
                const Text('Portföy', style: TextStyle(fontSize: 22,
                    fontWeight: FontWeight.bold, color: Colors.black87)),
                const Spacer(),
                if (_loading)
                  const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Color(0xFF34C759))),
                IconButton(onPressed: _loadPortfolio,
                    icon: const Icon(Icons.refresh, color: Colors.grey, size: 20)),
              ]),
            )),

            // Özet kart
            if (_groups.isNotEmpty)
              SliverToBoxAdapter(child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFF34C759),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(children: [
                    const Text('Toplam Portföy Değeri',
                        style: TextStyle(color: Colors.white70, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text('${_totalValue.toStringAsFixed(2)} ₺',
                        style: const TextStyle(color: Colors.white,
                            fontSize: 28, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _SummaryItem(label: 'Maliyet',
                              value: '${_totalCost.toStringAsFixed(2)} ₺',
                              color: Colors.white),
                          _SummaryItem(
                              label: 'Kar/Zarar',
                              value: '${isProfit ? '+' : ''}${_totalProfit.toStringAsFixed(2)} ₺',
                              color: Colors.white),
                          _SummaryItem(
                              label: 'Değişim',
                              value: '${isProfit ? '+' : ''}${_totalProfitPct.toStringAsFixed(2)}%',
                              color: Colors.white),
                        ]),
                  ]),
                ),
              )),

            // Boş durum
            if (_groups.isEmpty && !_loading)
              SliverFillRemaining(child: Center(child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.pie_chart_outline, color: Colors.grey, size: 56),
                  const SizedBox(height: 16),
                  const Text('Portföyünüz boş',
                      style: TextStyle(color: Colors.grey, fontSize: 16)),
                  const SizedBox(height: 6),
                  const Text('Sağ alttaki + butonuna tıklayarak hisse ekleyin.',
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _showAddDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Hisse Ekle'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF34C759),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12))),
                  ),
                ],
              ))),

            // Gruplu hisse listesi
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
              sliver: SliverList(delegate: SliverChildBuilderDelegate(
                (_, i) {
                  final g = _groups[i];
                  final current = _currentPrices[g.symbol] ?? g.avgPrice;
                  final profit = g.profit(current);
                  final profitPct = g.profitPercent(current);
                  final isPos = profit >= 0;
                  final chgColor = isPos
                      ? const Color(0xFF34C759) : const Color(0xFFFF3B30);

                  return GestureDetector(
                    onTap: () => _showLotDetail(g, current),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 6)],
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        // Üst: sembol + anlık fiyat
                        Row(children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: chgColor.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(g.symbol, style: TextStyle(
                                color: chgColor,
                                fontWeight: FontWeight.bold, fontSize: 14)),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(g.name, style: const TextStyle(
                                  color: Colors.black87, fontSize: 13,
                                  fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis),
                              Text('${g.lots.length} alış kaydı  •  '
                                  '${g.totalQty % 1 == 0 ? g.totalQty.toInt() : g.totalQty.toStringAsFixed(2)} lot',
                                  style: const TextStyle(
                                      color: Colors.grey, fontSize: 11)),
                            ],
                          )),
                          Column(crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                            Text('${current.toStringAsFixed(2)} ₺',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16, color: Colors.black87)),
                            Container(
                              margin: const EdgeInsets.only(top: 2),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                  color: chgColor,
                                  borderRadius: BorderRadius.circular(5)),
                              child: Text(
                                '${isPos ? '+' : ''}${profitPct.toStringAsFixed(2)}%',
                                style: const TextStyle(color: Colors.white,
                                    fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                          ]),
                        ]),

                        const SizedBox(height: 12),
                        const Divider(height: 1),
                        const SizedBox(height: 10),

                        // Ort. maliyet / toplam maliyet / kar-zarar
                        Row(children: [
                          Expanded(child: _DetailItem(label: 'Ort. Maliyet',
                              value: '${g.avgPrice.toStringAsFixed(2)} ₺')),
                          Expanded(child: _DetailItem(label: 'Top. Maliyet',
                              value: '${g.totalCost.toStringAsFixed(2)} ₺')),
                          Expanded(child: _DetailItem(label: 'Güncel Değer',
                              value: '${g.totalValue(current).toStringAsFixed(2)} ₺')),
                        ]),
                        const SizedBox(height: 8),
                        Row(children: [
                          Expanded(child: _DetailItem(label: 'Kar/Zarar (₺)',
                              value: '${isPos ? '+' : ''}${profit.toStringAsFixed(2)} ₺',
                              valueColor: chgColor)),
                          Expanded(child: _DetailItem(label: 'Kar/Zarar (%)',
                              value: '${isPos ? '+' : ''}${profitPct.toStringAsFixed(2)}%',
                              valueColor: chgColor)),
                          Expanded(child: _DetailItem(label: 'Alış Sayısı',
                              value: '${g.lots.length} kayıt')),
                        ]),

                        const SizedBox(height: 6),
                        Row(children: [
                          const Icon(Icons.touch_app_outlined,
                              size: 12, color: Colors.grey),
                          const SizedBox(width: 4),
                          const Text('Alış detayları için tıkla',
                              style: TextStyle(color: Colors.grey, fontSize: 11)),
                          const Spacer(),
                          const Icon(Icons.chevron_right,
                              size: 16, color: Colors.grey),
                        ]),
                      ]),
                    ),
                  );
                },
                childCount: _groups.length,
              )),
            ),
          ]),
        ),
      ),
    );
  }

  // Alış detay alt sayfası
  void _showLotDetail(_StockGroup g, double currentPrice) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => _LotDetailScreen(
        group: g,
        currentPrice: currentPrice,
        onDelete: (item) async {
          final key = PortfolioService.portfolioBox.keys.firstWhere(
            (k) => PortfolioService.portfolioBox.get(k) == item,
            orElse: () => null,
          );
          if (key != null) {
            await PortfolioService.deletePortfolioItem(
                PortfolioService.portfolioBox.keys.toList().indexOf(key));
          }
          _loadPortfolio();
        },
        onAddLot: () {
          showDialog(
            context: context,
            builder: (_) => _AddPortfolioDialog(
              initialSymbol: g.symbol,
              initialName: g.name,
              onAdd: (item) async {
                await PortfolioService.addPortfolioItem(item);
                _loadPortfolio();
              },
            ),
          );
        },
      ),
    ));
  }
}

// ─────────────────────────────────────────────
// Alış Detay Ekranı
// ─────────────────────────────────────────────

class _LotDetailScreen extends StatelessWidget {
  final _StockGroup group;
  final double currentPrice;
  final void Function(PortfolioItem) onDelete;
  final VoidCallback onAddLot;

  const _LotDetailScreen({
    required this.group,
    required this.currentPrice,
    required this.onDelete,
    required this.onAddLot,
  });

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year} '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final isPos = group.profit(currentPrice) >= 0;
    final chgColor =
        isPos ? const Color(0xFF34C759) : const Color(0xFFFF3B30);

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF2F2F7),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              size: 18, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF1C3A5E),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Text(group.symbol, style: const TextStyle(
                color: Colors.white, fontSize: 13,
                fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(group.name, style: const TextStyle(
              color: Colors.black87, fontSize: 14,
              fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis)),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline,
                color: Color(0xFF34C759)),
            tooltip: 'Yeni Alış Ekle',
            onPressed: () { Navigator.pop(context); onAddLot(); },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          // Özet kart
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: chgColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                _SummaryItem(label: 'Anlık Fiyat',
                    value: '${currentPrice.toStringAsFixed(2)} ₺',
                    color: Colors.white),
                _SummaryItem(label: 'Ort. Maliyet',
                    value: '${group.avgPrice.toStringAsFixed(2)} ₺',
                    color: Colors.white),
                _SummaryItem(label: 'Top. Adet',
                    value: '${group.totalQty % 1 == 0 ? group.totalQty.toInt() : group.totalQty.toStringAsFixed(2)} lot',
                    color: Colors.white),
              ]),
              const SizedBox(height: 12),
              const Divider(color: Colors.white24, height: 1),
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                _SummaryItem(label: 'Top. Maliyet',
                    value: '${group.totalCost.toStringAsFixed(2)} ₺',
                    color: Colors.white),
                _SummaryItem(label: 'Güncel Değer',
                    value: '${group.totalValue(currentPrice).toStringAsFixed(2)} ₺',
                    color: Colors.white),
                _SummaryItem(
                    label: 'Kar/Zarar',
                    value: '${isPos ? '+' : ''}${group.profit(currentPrice).toStringAsFixed(2)} ₺',
                    color: Colors.white),
              ]),
            ]),
          ),

          const SizedBox(height: 16),
          Text('Alış Kayıtları (${group.lots.length})',
              style: const TextStyle(fontWeight: FontWeight.bold,
                  fontSize: 15, color: Colors.black87)),
          const SizedBox(height: 8),

          // Her alış kaydı
          ...group.lots.asMap().entries.map((entry) {
            final idx = entry.key;
            final lot = entry.value;
            final lotProfit = (currentPrice - lot.buyPrice) * lot.quantity;
            final lotProfitPct = lot.buyPrice > 0
                ? ((currentPrice - lot.buyPrice) / lot.buyPrice) * 100 : 0.0;
            final lotIsPos = lotProfit >= 0;
            final lotColor = lotIsPos
                ? const Color(0xFF34C759) : const Color(0xFFFF3B30);

            return Dismissible(
              key: Key('${lot.symbol}_${lot.buyDate.millisecondsSinceEpoch}_$idx'),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF3B30),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Column(mainAxisSize: MainAxisSize.min,
                    children: [
                  Icon(Icons.delete, color: Colors.white),
                  Text('Sil', style: TextStyle(color: Colors.white, fontSize: 11)),
                ]),
              ),
              confirmDismiss: (_) async {
                return await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Alış kaydı silinsin mi?'),
                    content: Text(
                      '${_fmtDate(lot.buyDate)} tarihli '
                      '${lot.quantity % 1 == 0 ? lot.quantity.toInt() : lot.quantity.toStringAsFixed(2)} '
                      'lot @ ${lot.buyPrice.toStringAsFixed(2)} ₺ kaydı silinecek.',
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('İptal')),
                      TextButton(onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Sil',
                              style: TextStyle(color: Color(0xFFFF3B30)))),
                    ],
                  ),
                ) ?? false;
              },
              onDismissed: (_) {
                onDelete(lot);
                Navigator.pop(context);
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 4)],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1C3A5E).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('${idx + 1}. Alış',
                            style: const TextStyle(
                                color: Color(0xFF1C3A5E), fontSize: 11,
                                fontWeight: FontWeight.bold)),
                      ),
                      const Spacer(),
                      // Düzenleme butonu
                      GestureDetector(
                        onTap: () => _showEditLot(context, lot, idx),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF34C759).withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.edit_outlined,
                                size: 11, color: Color(0xFF34C759)),
                            SizedBox(width: 3),
                            Text('Düzenle', style: TextStyle(
                                color: Color(0xFF34C759),
                                fontSize: 11,
                                fontWeight: FontWeight.bold)),
                          ]),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.access_time, size: 11, color: Colors.grey),
                      const SizedBox(width: 3),
                      Text(_fmtDate(lot.buyDate),
                          style: const TextStyle(color: Colors.grey, fontSize: 11)),
                    ]),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(child: _DetailItem(label: 'Alış Fiyatı',
                          value: '${lot.buyPrice.toStringAsFixed(2)} ₺')),
                      Expanded(child: _DetailItem(label: 'Adet',
                          value: '${lot.quantity % 1 == 0 ? lot.quantity.toInt() : lot.quantity.toStringAsFixed(2)} lot')),
                      Expanded(child: _DetailItem(label: 'Maliyet',
                          value: '${lot.totalCost().toStringAsFixed(2)} ₺')),
                    ]),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(child: _DetailItem(label: 'Anlık Değer',
                          value: '${(currentPrice * lot.quantity).toStringAsFixed(2)} ₺')),
                      Expanded(child: _DetailItem(label: 'Kar/Zarar (₺)',
                          value: '${lotIsPos ? '+' : ''}${lotProfit.toStringAsFixed(2)} ₺',
                          valueColor: lotColor)),
                      Expanded(child: _DetailItem(label: 'Kar/Zarar (%)',
                          value: '${lotIsPos ? '+' : ''}${lotProfitPct.toStringAsFixed(2)}%',
                          valueColor: lotColor)),
                    ]),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  void _showEditLot(BuildContext context, PortfolioItem lot, int idx) {
    final priceCtrl = TextEditingController(
        text: lot.buyPrice.toStringAsFixed(2));
    final qtyCtrl = TextEditingController(
        text: lot.quantity % 1 == 0
            ? lot.quantity.toInt().toString()
            : lot.quantity.toStringAsFixed(2));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('${idx + 1}. Alışı Düzenle',
            style: const TextStyle(
                color: Colors.black87, fontWeight: FontWeight.bold)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: priceCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: Colors.black87),
            decoration: InputDecoration(
              labelText: 'Alış Fiyatı (₺)',
              filled: true, fillColor: const Color(0xFFF2F2F7),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: qtyCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: Colors.black87),
            decoration: InputDecoration(
              labelText: 'Adet (lot)',
              filled: true, fillColor: const Color(0xFFF2F2F7),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none),
            ),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF34C759),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              final newPrice = double.tryParse(
                  priceCtrl.text.replaceAll(',', '.'));
              final newQty = double.tryParse(
                  qtyCtrl.text.replaceAll(',', '.'));
              if (newPrice == null || newQty == null ||
                  newPrice <= 0 || newQty <= 0) { return; }
              lot.buyPrice = newPrice;
              lot.quantity = newQty;
              await lot.save();
              if (ctx.mounted) Navigator.pop(ctx);
              // Sayfayı yenilemek için geri dön
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Kaydet',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Hisse Ekleme Dialog
// ─────────────────────────────────────────────

class _AddPortfolioDialog extends StatefulWidget {
  final void Function(PortfolioItem) onAdd;
  final String? initialSymbol;
  final String? initialName;

  const _AddPortfolioDialog({
    required this.onAdd,
    this.initialSymbol,
    this.initialName,
  });

  @override
  State<_AddPortfolioDialog> createState() => _AddPortfolioDialogState();
}

class _AddPortfolioDialogState extends State<_AddPortfolioDialog> {
  final _searchCtrl = TextEditingController();
  final _priceCtrl  = TextEditingController();
  final _qtyCtrl    = TextEditingController();
  final _dateCtrl   = TextEditingController();

  List<Map<String, String>> _filtered = [];
  Map<String, String>? _selected;
  double? _currentPrice;
  double? _currentChange;
  bool _loadingPrice = false;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    if (widget.initialSymbol != null) {
      _selected = {'symbol': widget.initialSymbol!, 'name': widget.initialName ?? ''};
      _searchCtrl.text = widget.initialSymbol!;
      _fetchPrice(widget.initialSymbol!);
    }
    _dateCtrl.text = _fmtDate(_selectedDate);
  }

  @override
  void dispose() {
    _searchCtrl.dispose(); _priceCtrl.dispose();
    _qtyCtrl.dispose(); _dateCtrl.dispose();
    super.dispose();
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year} '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  void _onSearch(String val) {
    final q = val.trim().toUpperCase();
    if (q.isEmpty) { setState(() => _filtered = []); return; }
    if (q.length == 1) {
      setState(() { _filtered = kBistStocks.where((s) =>
          s['symbol']!.startsWith(q) || s['name']!.toUpperCase().startsWith(q))
          .take(8).toList(); });
    } else {
      final bySymbol = kBistStocks.where((s) => s['symbol']!.startsWith(q)).toList();
      final byName = kBistStocks.where((s) =>
          !s['symbol']!.startsWith(q) &&
          s['name']!.toUpperCase().contains(q)).toList();
      setState(() { _filtered = [...bySymbol, ...byName].take(8).toList(); });
    }
  }

  void _pick(Map<String, String> stock) {
    setState(() {
      _selected = stock;
      _searchCtrl.text = stock['symbol']!;
      _filtered = [];
      _currentPrice = null;
    });
    _fetchPrice(stock['symbol']!);
  }

  Future<void> _fetchPrice(String symbol) async {
    setState(() => _loadingPrice = true);
    final asset = await StockService.fetchStock(symbol, period: '5d');
    if (!mounted) return;
    setState(() {
      _loadingPrice = false;
      if (asset != null) {
        _currentPrice  = asset.price;
        _currentChange = asset.changePercent;
        if (_priceCtrl.text.isEmpty) {
          _priceCtrl.text = asset.price.toStringAsFixed(2);
        }
      }
    });
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2010),
      lastDate: DateTime.now(),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDate),
    );
    if (!mounted) return;
    final dt = DateTime(date.year, date.month, date.day,
        time?.hour ?? _selectedDate.hour, time?.minute ?? _selectedDate.minute);
    setState(() {
      _selectedDate = dt;
      _dateCtrl.text = _fmtDate(dt);
    });
  }

  double get _buyPrice  => double.tryParse(_priceCtrl.text.replaceAll(',', '.')) ?? 0;
  double get _qty       => double.tryParse(_qtyCtrl.text.replaceAll(',', '.')) ?? 0;
  double get _totalCost => _buyPrice * _qty;
  double get _totalValue => (_currentPrice ?? _buyPrice) * _qty;
  double get _profit    => _totalValue - _totalCost;
  double get _profitPct => _totalCost > 0 ? (_profit / _totalCost) * 100 : 0;
  bool get _canAdd => _selected != null && _buyPrice > 0 && _qty > 0;

  @override
  Widget build(BuildContext context) {
    final isPos = _profit >= 0;
    final profitColor = isPos ? const Color(0xFF34C759) : const Color(0xFFFF3B30);
    final cpColor = (_currentChange ?? 0) >= 0
        ? const Color(0xFF34C759) : const Color(0xFFFF3B30);

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

          // Başlık
          Row(children: [
            const Text('Hisse Ekle', style: TextStyle(fontSize: 18,
                fontWeight: FontWeight.bold, color: Colors.black87)),
            const Spacer(),
            IconButton(icon: const Icon(Icons.close, color: Colors.grey),
                onPressed: () => Navigator.pop(context),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints()),
          ]),
          const SizedBox(height: 14),

          // Hisse arama (initialSymbol varsa gizle)
          if (widget.initialSymbol == null) ...[
            TextField(
              controller: _searchCtrl,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(color: Colors.black87),
              decoration: _dec('Hisse ara... (THYAO, Akbank...)'),
              onChanged: _onSearch,
            ),
            if (_filtered.isNotEmpty) ...[
              const SizedBox(height: 6),
              ConstrainedBox(constraints: const BoxConstraints(maxHeight: 160),
                child: ListView.builder(shrinkWrap: true,
                  itemCount: _filtered.length,
                  itemBuilder: (_, i) {
                    final s = _filtered[i];
                    final chosen = _selected?['symbol'] == s['symbol'];
                    return GestureDetector(
                      onTap: () => _pick(s),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        margin: const EdgeInsets.only(bottom: 3),
                        decoration: BoxDecoration(
                          color: chosen
                              ? const Color(0xFF34C759).withValues(alpha: 0.10)
                              : const Color(0xFFF2F2F7),
                          borderRadius: BorderRadius.circular(8),
                          border: chosen ? Border.all(
                              color: const Color(0xFF34C759).withValues(alpha: 0.4))
                              : null,
                        ),
                        child: Row(children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(color: const Color(0xFF1C3A5E),
                                borderRadius: BorderRadius.circular(5)),
                            child: Text(s['symbol']!, style: const TextStyle(
                                color: Colors.white, fontSize: 11,
                                fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Text(s['name']!,
                              style: TextStyle(color: chosen
                                  ? const Color(0xFF34C759) : Colors.black87,
                                  fontSize: 12),
                              overflow: TextOverflow.ellipsis)),
                          if (chosen) const Icon(Icons.check_circle,
                              color: Color(0xFF34C759), size: 16),
                        ]),
                      ),
                    );
                  }),
              ),
            ],
          ],

          // Seçili hisse + anlık fiyat
          if (_selected != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1C3A5E).withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: const Color(0xFF1C3A5E).withValues(alpha: 0.15)),
              ),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(color: const Color(0xFF1C3A5E),
                      borderRadius: BorderRadius.circular(7)),
                  child: Text(_selected!['symbol']!, style: const TextStyle(
                      color: Colors.white, fontSize: 12,
                      fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(_selected!['name']!,
                    style: const TextStyle(color: Colors.black87, fontSize: 12),
                    overflow: TextOverflow.ellipsis)),
                if (_loadingPrice)
                  const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2,
                          color: Color(0xFF34C759)))
                else if (_currentPrice != null)
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('${_currentPrice!.toStringAsFixed(2)} ₺',
                        style: TextStyle(color: cpColor,
                            fontWeight: FontWeight.bold, fontSize: 14)),
                    Text('${(_currentChange ?? 0) >= 0 ? '+' : ''}${(_currentChange ?? 0).toStringAsFixed(2)}%',
                        style: TextStyle(color: cpColor, fontSize: 11)),
                  ]),
              ]),
            ),
          ],

          const SizedBox(height: 14),

          // Alış Fiyatı
          _Label('Alış Fiyatı (₺)'),
          const SizedBox(height: 4),
          TextField(controller: _priceCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.black87),
              decoration: _dec('Örn: 325.50'),
              onChanged: (_) => setState(() {})),
          const SizedBox(height: 10),

          // Adet
          _Label('Adet (lot)'),
          const SizedBox(height: 4),
          TextField(controller: _qtyCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.black87),
              decoration: _dec('Örn: 100'),
              onChanged: (_) => setState(() {})),
          const SizedBox(height: 10),

          // Tarih/Saat (opsiyonel — boş = şimdiki zaman)
          _Label('Alış Tarihi / Saati (opsiyonel)'),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: _pickDate,
            child: AbsorbPointer(
              child: TextField(
                controller: _dateCtrl,
                style: const TextStyle(color: Colors.black87),
                decoration: _dec('').copyWith(
                  hintText: 'Boş bırakırsanız şu an kullanılır',
                  hintStyle: const TextStyle(color: Colors.grey, fontSize: 12),
                  suffixIcon: const Icon(Icons.calendar_today,
                      color: Colors.grey, size: 18),
                ),
              ),
            ),
          ),

          // Hesaplama özeti
          if (_buyPrice > 0 && _qty > 0) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F8F8),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(children: [
                _CalcRow('Toplam Maliyet',
                    '${_totalCost.toStringAsFixed(2)} ₺', Colors.black87),
                const SizedBox(height: 6),
                _CalcRow('Anlık Değer',
                    _currentPrice != null
                        ? '${_totalValue.toStringAsFixed(2)} ₺' : '—',
                    Colors.black87),
                if (_currentPrice != null) ...[
                  const Divider(height: 14),
                  _CalcRow('Kar / Zarar (₺)',
                      '${isPos ? '+' : ''}${_profit.toStringAsFixed(2)} ₺',
                      profitColor),
                  const SizedBox(height: 4),
                  _CalcRow('Kar / Zarar (%)',
                      '${isPos ? '+' : ''}${_profitPct.toStringAsFixed(2)}%',
                      profitColor),
                  const SizedBox(height: 4),
                  _CalcRow('Ortalama Maliyet',
                      '${_buyPrice.toStringAsFixed(2)} ₺ / lot',
                      Colors.black54),
                ],
              ]),
            ),
          ],

          const SizedBox(height: 18),

          // Butonlar
          Row(children: [
            Expanded(child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.grey.shade300),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('İptal',
                  style: TextStyle(color: Colors.grey)),
            )),
            const SizedBox(width: 10),
            Expanded(child: ElevatedButton(
              onPressed: _canAdd ? () {
                final item = PortfolioItem(
                  symbol:   _selected!['symbol']!,
                  name:     _selected!['name']!,
                  buyPrice: _buyPrice,
                  quantity: _qty,
                  buyDate:  _selectedDate,
                );
                Navigator.pop(context);
                widget.onAdd(item);
              } : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF34C759),
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade200,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('Portföye Ekle',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            )),
          ]),
        ]),
      ),
    );
  }

  InputDecoration _dec(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
        filled: true,
        fillColor: const Color(0xFFF2F2F7),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      );
}

// ─────────────────────────────────────────────
// Yardımcı widget'lar
// ─────────────────────────────────────────────

class _SummaryItem extends StatelessWidget {
  final String label, value;
  final Color color;
  const _SummaryItem({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Column(children: [
        Text(label, style: TextStyle(color: color.withValues(alpha: 0.75),
            fontSize: 11)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(color: color,
            fontWeight: FontWeight.bold, fontSize: 13)),
      ]);
}

class _DetailItem extends StatelessWidget {
  final String label, value;
  final Color? valueColor;
  const _DetailItem({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(
              color: valueColor ?? Colors.black87,
              fontWeight: FontWeight.w600, fontSize: 12)),
        ]);
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(color: Colors.black54, fontSize: 12,
          fontWeight: FontWeight.w600));
}

class _CalcRow extends StatelessWidget {
  final String label, value;
  final Color color;
  const _CalcRow(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          Text(value, style: TextStyle(color: color,
              fontWeight: FontWeight.w600, fontSize: 13)),
        ]);
}
