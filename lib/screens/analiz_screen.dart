import 'package:flutter/material.dart';
import '../models/asset_model.dart';
import '../services/stock_service.dart';
import '../widgets/stock_chart.dart';
import '../widgets/indicator_chip.dart';
import '../widgets/stock_quote_panel.dart';
import '../services/portfolio_service.dart';
import '../models/portfolio_model.dart';

class AnalizScreen extends StatefulWidget {
  final String? initialSymbol;
  final String? initialName;
  const AnalizScreen({super.key, this.initialSymbol, this.initialName});

  @override
  State<AnalizScreen> createState() => _AnalizScreenState();
}

class _AnalizScreenState extends State<AnalizScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late String _selectedSymbol;
  String _assetCategory = 'bist';
  int _selectedPeriod = 1;
  AssetModel? _asset;
  bool _loading = false;
  final Set<String> _activeIndicators = {'RSI 30'};

  // Üst arama
  final TextEditingController _searchCtrl = TextEditingController();
  List<Map<String, String>> _searchResults = [];

  final List<String> _periods = ['1A', '3A', '1Y'];
  final List<String> _ranges  = ['1mo', '3mo', '1y'];

  final List<Map<String, String>> _indicators = [
    {'label': 'RSI 30', 'icon': 'rsi'},
    {'label': 'EMA 20', 'icon': 'ma'},
    {'label': 'EMA 50', 'icon': 'ma'},
    {'label': 'Supertrend', 'icon': 'st'},
    {'label': 'MACD', 'icon': 'macd'},
  ];

  @override
  void initState() {
    super.initState();
    _selectedSymbol = widget.initialSymbol ?? 'THYAO';
    _tabController = TabController(length: 1, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearch(String val) {
    if (val.isEmpty) { setState(() => _searchResults = []); return; }
    final q = val.trim().toUpperCase();
    setState(() {
      if (q.length == 1) {
        _searchResults = kBistStocks.where((s) =>
            s['symbol']!.startsWith(q) ||
            s['name']!.toUpperCase().startsWith(q)
        ).take(10).toList();
      } else {
        final bySymbol = kBistStocks
            .where((s) => s['symbol']!.startsWith(q))
            .toList();
        final byName = kBistStocks
            .where((s) =>
                !s['symbol']!.startsWith(q) &&
                s['name']!.toUpperCase().contains(q))
            .toList();
        _searchResults = [...bySymbol, ...byName].take(10).toList();
      }
    });
  }

  void _onSelectFromSearch(Map<String, String> s) {
    _searchCtrl.clear();
    setState(() {
      _searchResults = [];
      _selectedSymbol = s['symbol']!;
      _assetCategory = 'bist';
    });
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    AssetModel? a;
    if (_assetCategory == 'gold') {
      a = await StockService.fetchGold();
    } else if (_assetCategory == 'dollar') {
      a = await StockService.fetchDollar();
    } else {
      a = await StockService.fetchStock(_selectedSymbol, period: _ranges[_selectedPeriod]);
    }
    if (mounted) setState(() { _asset = a; _loading = false; });
  }

  void _showPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _PickerSheet(
        selectedCategory: _assetCategory,
        selectedSymbol: _selectedSymbol,
        onSelect: (cat, sym) {
          setState(() { _assetCategory = cat; _selectedSymbol = sym; });
          _load();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final a = _asset;
    final isPos = (a?.changePercent ?? 0) >= 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: SafeArea(
        child: Column(
          children: [
            // Başlık
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: _showPicker,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Text(a?.symbol ?? _selectedSymbol,
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
                            const SizedBox(width: 4),
                            const Icon(Icons.keyboard_arrow_down, color: Colors.grey, size: 18),
                          ]),
                          if (a != null)
                            Text(a.name, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ),
                  ),
                  if (_loading)
                    const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF34C759)))
                  else
                    Row(children: [
                      if (_assetCategory == 'bist')
                        GestureDetector(
                          onTap: () async {
                            if (PortfolioService.isInWatchlist(_selectedSymbol)) {
                              await PortfolioService.removeFromWatchlist(_selectedSymbol);
                            } else {
                              await PortfolioService.addToWatchlist(
                                  WatchlistItem(symbol: _selectedSymbol, name: a?.name ?? _selectedSymbol));
                            }
                            setState(() {});
                          },
                          child: Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Icon(
                              PortfolioService.isInWatchlist(_selectedSymbol) ? Icons.star : Icons.star_border,
                              color: PortfolioService.isInWatchlist(_selectedSymbol)
                                  ? const Color(0xFFFFB300) : Colors.grey,
                              size: 22,
                            ),
                          ),
                        ),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text(a?.price.toStringAsFixed(2) ?? '-',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
                        Text('${isPos ? '+' : ''}${a?.changePercent.toStringAsFixed(2) ?? '0.00'}%',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                                color: isPos ? const Color(0xFF34C759) : const Color(0xFFFF3B30))),
                      ]),
                    ]),
                ],
              ),
            ),

            if (a != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: StockQuotePanel(asset: a, showDivider: false),
              ),

            const SizedBox(height: 10),

            // ── Üst Arama Kutusu ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _searchCtrl,
                    onChanged: _onSearch,
                    style: const TextStyle(color: Colors.black87),
                    decoration: InputDecoration(
                      hintText: 'Hisse ara... (örn: THY, Akbank)',
                      hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
                      prefixIcon: const Icon(Icons.search, color: Colors.grey, size: 20),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: Colors.grey, size: 18),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _searchResults = []);
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                  if (_searchResults.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08), blurRadius: 8)],
                      ),
                      child: Column(
                        children: _searchResults.map((s) => ListTile(
                          dense: true,
                          leading: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF34C759).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(s['symbol']!, style: const TextStyle(
                                color: Color(0xFF34C759),
                                fontWeight: FontWeight.bold, fontSize: 11)),
                          ),
                          title: Text(s['name']!,
                              style: const TextStyle(fontSize: 13)),
                          trailing: const Icon(Icons.bar_chart,
                              color: Color(0xFF34C759), size: 18),
                          onTap: () => _onSelectFromSearch(s),
                        )).toList(),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            Expanded(
              child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      // Periyot
                      Row(children: List.generate(_periods.length, (i) {
                        final sel = _selectedPeriod == i;
                        return Expanded(child: GestureDetector(
                          onTap: () { setState(() => _selectedPeriod = i); _load(); },
                          child: Container(
                            margin: EdgeInsets.only(right: i < _periods.length - 1 ? 8 : 0),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: sel ? const Color(0xFF34C759) : Colors.white,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(child: Text(_periods[i], style: TextStyle(
                              color: sel ? Colors.white : Colors.grey,
                              fontWeight: sel ? FontWeight.bold : FontWeight.normal, fontSize: 13,
                            ))),
                          ),
                        ));
                      })),

                      const SizedBox(height: 14),

                      if (_loading)
                        const SizedBox(height: 200,
                            child: Center(child: CircularProgressIndicator(color: Color(0xFF34C759))))
                      else if (a != null)
                        StockChart(asset: a, activeIndicators: _activeIndicators)
                      else
                        const SizedBox(height: 200,
                            child: Center(child: Text('Veri yüklenemedi', style: TextStyle(color: Colors.grey)))),

                      const SizedBox(height: 16),
                      const Text('Göstergeler', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87)),
                      const SizedBox(height: 8),
                      Wrap(spacing: 8, runSpacing: 8, children: _indicators.map<Widget>((ind) {
                        final active = _activeIndicators.contains(ind['label']);
                        return IndicatorChip(
                          label: ind['label']!, iconType: ind['icon']!, isActive: active,
                          onTap: () => setState(() {
                            if (active) { _activeIndicators.remove(ind['label']); }
                            else { _activeIndicators.add(ind['label']!); }
                          }),
                        );
                      }).toList()),

                      const SizedBox(height: 16),
                      const Text('Algoritmalar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87)),
                      const SizedBox(height: 8),
                      if (a != null) ...[
                        _AlgoCard(label: 'Trend Takip (EMA Cross)',
                            signal: a.isGoldenCross ? 'Al Sinyali' : a.isDeathCross ? 'Sat Sinyali' : 'Nötr',
                            isPositive: a.isGoldenCross ? true : a.isDeathCross ? false : null),
                        const SizedBox(height: 8),
                        _AlgoCard(label: 'Supertrend',
                            signal: a.isSupertrendBuy ? 'Al Sinyali' : a.isSupertrendSell ? 'Sat Sinyali' : 'Nötr',
                            isPositive: a.isSupertrendBuy ? true : a.isSupertrendSell ? false : null),
                        const SizedBox(height: 8),
                        _AlgoCard(label: 'RSI Tarayıcısı',
                            signal: a.isRsiBelow40 ? 'Aşırı Satım' : 'Normal',
                            isPositive: a.isRsiBelow40 ? true : null),
                      ],
                      const SizedBox(height: 24),
                    ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlgoCard extends StatelessWidget {
  final String label, signal; final bool? isPositive;
  const _AlgoCard({required this.label, required this.signal, required this.isPositive});

  @override
  Widget build(BuildContext context) {
    final color = isPositive == true ? const Color(0xFF34C759)
        : isPositive == false ? const Color(0xFFFF3B30) : Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        const Icon(Icons.settings_input_component, color: Colors.grey, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: const TextStyle(color: Colors.black87, fontSize: 14))),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
          child: Text(signal, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
        ),
      ]),
    );
  }
}

class _PickerSheet extends StatefulWidget {
  final String selectedCategory, selectedSymbol;
  final Function(String, String) onSelect;
  const _PickerSheet({required this.selectedCategory, required this.selectedSymbol, required this.onSelect});

  @override
  State<_PickerSheet> createState() => _PickerSheetState();
}

class _PickerSheetState extends State<_PickerSheet> {
  late String _cat; String _q = '';
  @override
  void initState() { super.initState(); _cat = widget.selectedCategory; }

  List<Map<String, String>> get _filtered {
    if (_q.isEmpty) return kBistStocks;
    final q = _q.trim().toUpperCase();
    if (q.length == 1) {
      return kBistStocks.where((s) =>
          s['symbol']!.startsWith(q) ||
          s['name']!.toUpperCase().startsWith(q)
      ).toList();
    }
    final bySymbol = kBistStocks
        .where((s) => s['symbol']!.startsWith(q))
        .toList();
    final byName = kBistStocks
        .where((s) =>
            !s['symbol']!.startsWith(q) &&
            s['name']!.toUpperCase().contains(q))
        .toList();
    return [...bySymbol, ...byName];
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false, initialChildSize: 0.6, maxChildSize: 0.9,
      builder: (_, ctrl) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Column(children: [
          const Text('Varlık Seç', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(children: [
            _CatBtn(label: 'BIST', value: 'bist', cur: _cat, onTap: (v) => setState(() => _cat = v)),
            const SizedBox(width: 8),
            _CatBtn(label: 'Altın', value: 'gold', cur: _cat, onTap: (v) => setState(() => _cat = v)),
            const SizedBox(width: 8),
            _CatBtn(label: 'Dolar', value: 'dollar', cur: _cat, onTap: (v) => setState(() => _cat = v)),
          ]),
          const SizedBox(height: 10),
          if (_cat == 'bist')
            TextField(
              decoration: InputDecoration(
                hintText: 'Hisse ara...', prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true, fillColor: const Color(0xFFF2F2F7),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
              onChanged: (v) => setState(() => _q = v),
            ),
          const SizedBox(height: 8),
          Expanded(child: ListView(controller: ctrl, children: [
            if (_cat == 'bist')
              ..._filtered.map((s) => ListTile(
                contentPadding: EdgeInsets.zero, dense: true,
                title: Text(s['name']!), subtitle: Text(s['symbol']!),
                trailing: s['symbol'] == widget.selectedSymbol
                    ? const Icon(Icons.check, color: Color(0xFF34C759)) : null,
                onTap: () { widget.onSelect('bist', s['symbol']!); Navigator.pop(context); },
              )),
            if (_cat == 'gold') ListTile(
              title: const Text('Altın (USD/oz)'),
              trailing: const Icon(Icons.check, color: Color(0xFF34C759)),
              onTap: () { widget.onSelect('gold', 'ALTIN'); Navigator.pop(context); },
            ),
            if (_cat == 'dollar') ListTile(
              title: const Text('Dolar/TL'),
              trailing: const Icon(Icons.check, color: Color(0xFF34C759)),
              onTap: () { widget.onSelect('dollar', 'DOLAR'); Navigator.pop(context); },
            ),
          ])),
        ]),
      ),
    );
  }
}

class _CatBtn extends StatelessWidget {
  final String label, value, cur; final Function(String) onTap;
  const _CatBtn({required this.label, required this.value, required this.cur, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final sel = value == cur;
    return GestureDetector(
      onTap: () => onTap(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: sel ? const Color(0xFF34C759) : const Color(0xFFF2F2F7),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: TextStyle(
            color: sel ? Colors.white : Colors.black54, fontWeight: FontWeight.bold, fontSize: 13)),
      ),
    );
  }
}

