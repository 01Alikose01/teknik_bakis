import 'package:flutter/material.dart';
import '../models/asset_model.dart';
import '../services/stock_service.dart';
import '../widgets/stock_chart.dart';
import '../widgets/indicator_chip.dart';
import '../widgets/stock_quote_panel.dart';
import '../services/portfolio_service.dart';
import '../services/kap_news_service.dart';
import '../models/portfolio_model.dart';
import '../models/kap_news_item.dart';

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
  int _selectedChartStyle = 0; // 0 = Çizgi, 1 = Mum
  AssetModel? _asset;
  bool _loading = false;
  bool _newsLoading = false;
  int _selectedInfoTab = 0;
  final Set<String> _activeIndicators = {'RSI 30'};
  List<KapNewsItem> _symbolNews = [];

  // Üst arama
  final TextEditingController _searchCtrl = TextEditingController();
  List<Map<String, String>> _searchResults = [];

  final List<String> _periods = ['4S', 'G', 'H', '1A', '3A', '1Y'];
  final List<String> _ranges = ['1d', '5d', '1mo', '1mo', '3mo', '1y'];
  final List<String> _intervals = ['5m', '1h', '1d', '1d', '1d', '1wk'];

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
      a = await StockService.fetchStock(
        _selectedSymbol,
        period: _ranges[_selectedPeriod],
        interval: _intervals[_selectedPeriod],
      );
    }
    if (mounted) {
      setState(() {
        _asset = a;
        _loading = false;
      });
    }
    await _loadSymbolNews();
  }

  Future<void> _loadSymbolNews() async {
    if (_assetCategory != 'bist') {
      if (mounted) setState(() => _symbolNews = []);
      return;
    }

    if (mounted) setState(() => _newsLoading = true);
    try {
      final investingNews = await KapNewsService.fetchInvestingNews(_selectedSymbol);
      if (investingNews.isNotEmpty) {
        if (mounted) setState(() => _symbolNews = investingNews);
        return;
      }

      final allNews = await KapNewsService.fetch();
      final filtered = KapNewsService.filterBySymbol(allNews, _selectedSymbol);
      if (mounted) setState(() => _symbolNews = filtered.take(6).toList());
    } catch (_) {
      if (mounted) setState(() => _symbolNews = []);
    } finally {
      if (mounted) setState(() => _newsLoading = false);
    }
  }

  void _showPicker() {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
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

  Future<void> _addToFavoriteList(String symbol, String name, String listKey) async {
    final listA = PortfolioService.getFavoriteList('listA');
    final listB = PortfolioService.getFavoriteList('listB');

    if (listKey == 'listA' && listA.contains(symbol) || listKey == 'listB' && listB.contains(symbol)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$name zaten ${listKey == 'listA' ? 'Takip 1' : 'Takip 2'} listesinde.')),
        );
      }
      return;
    }

    if (listKey == 'listA') {
      await PortfolioService.saveFavoriteLists([...listA, symbol], listB);
    } else {
      await PortfolioService.saveFavoriteLists(listA, [...listB, symbol]);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$name ${listKey == 'listA' ? 'Takip 1' : 'Takip 2'} listesine eklendi.')),
      );
      setState(() {});
    }
  }

  void _showFavoriteChoiceDialog(String symbol, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Favori Listesine Ekle'),
        content: const Text('Hisseyi hangi listeye eklemek istersiniz?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _addToFavoriteList(symbol, name, 'listA');
            },
            child: const Text('Takip 1'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _addToFavoriteList(symbol, name, 'listB');
            },
            child: const Text('Takip 2'),
          ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surface = theme.colorScheme.surface;
    final surfaceVariant = theme.colorScheme.surfaceVariant;
    final onSurface = theme.colorScheme.onSurface;
    final onSurfaceSecondary = onSurface.withOpacity(0.72);
    final borderColor = theme.dividerColor;
    final shadowColor = theme.brightness == Brightness.light
        ? Colors.black.withOpacity(0.08)
        : Colors.white.withOpacity(0.08);
    final a = _asset;
    final isPos = (a?.changePercent ?? 0) >= 0;
    final isInFavorites = PortfolioService.getFavoriteList('listA').contains(_selectedSymbol) ||
        PortfolioService.getFavoriteList('listB').contains(_selectedSymbol);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
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
                                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: onSurface)),
                            const SizedBox(width: 4),
                            Icon(Icons.keyboard_arrow_down, color: onSurfaceSecondary, size: 18),
                          ]),
                          if (a != null)
                            Text(a.name, style: TextStyle(fontSize: 12, color: onSurfaceSecondary)),
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
                          onTap: () => _showFavoriteChoiceDialog(_selectedSymbol, a?.name ?? _selectedSymbol),
                          child: Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Icon(
                              isInFavorites ? Icons.star : Icons.star_border,
                              color: isInFavorites ? const Color(0xFFFFB300) : onSurfaceSecondary,
                              size: 22,
                            ),
                          ),
                        ),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text(a?.price.toStringAsFixed(2) ?? '-',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: onSurface)),
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
                    style: TextStyle(color: onSurface),
                    decoration: InputDecoration(
                      hintText: 'Hisse ara... (örn: THY, Akbank)',
                      hintStyle: TextStyle(color: onSurfaceSecondary, fontSize: 13),
                      prefixIcon: Icon(Icons.search, color: onSurfaceSecondary, size: 20),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear, color: onSurfaceSecondary, size: 18),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _searchResults = []);
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: surface,
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
                        color: surface,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(
                            color: shadowColor, blurRadius: 8)],
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
                              color: sel ? const Color(0xFF34C759) : surface,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(child: Text(_periods[i], style: TextStyle(
                              color: sel ? Colors.white : onSurfaceSecondary,
                              fontWeight: sel ? FontWeight.bold : FontWeight.normal, fontSize: 13,
                            ))),
                          ),
                        ));
                      })),

                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(child: GestureDetector(
                          onTap: () => setState(() { _selectedChartStyle = 0; }),
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _selectedChartStyle == 0 ? const Color(0xFF34C759) : surface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: _selectedChartStyle == 0 ? Colors.transparent : borderColor),
                            ),
                            child: Center(child: Text('Çizgi', style: TextStyle(
                              color: _selectedChartStyle == 0 ? Colors.white : onSurfaceSecondary,
                              fontWeight: _selectedChartStyle == 0 ? FontWeight.bold : FontWeight.normal,
                              fontSize: 13,
                            ))),
                          ),
                        )),
                        Expanded(child: GestureDetector(
                          onTap: () => setState(() { _selectedChartStyle = 1; }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _selectedChartStyle == 1 ? const Color(0xFF34C759) : surface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: _selectedChartStyle == 1 ? Colors.transparent : borderColor),
                            ),
                            child: Center(child: Text('Mum', style: TextStyle(
                              color: _selectedChartStyle == 1 ? Colors.white : onSurfaceSecondary,
                              fontWeight: _selectedChartStyle == 1 ? FontWeight.bold : FontWeight.normal,
                              fontSize: 13,
                            ))),
                          ),
                        )),
                      ]),

                      const SizedBox(height: 14),

                      if (_loading)
                        const SizedBox(height: 200,
                            child: Center(child: CircularProgressIndicator(color: Color(0xFF34C759))))
                      else if (a != null)
                        StockChart(
                          asset: a,
                          activeIndicators: _activeIndicators,
                          showCandles: _selectedChartStyle == 1,
                        )
                      else
                        SizedBox(height: 200,
                            child: Center(child: Text('Veri yüklenemedi', style: TextStyle(color: onSurfaceSecondary)))),

                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Grafik görsel bir referans olarak gösterilmektedir. Karar verme aşamasında ek analiz ve kendi stratejiniz önemlidir.',
                          style: TextStyle(
                            color: onSurfaceSecondary,
                            fontSize: 12,
                            height: 1.5,
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _InfoTabButton(
                            label: 'Özet',
                            selected: _selectedInfoTab == 0,
                            onTap: () => setState(() => _selectedInfoTab = 0),
                          ),
                          const SizedBox(width: 8),
                          _InfoTabButton(
                            label: 'Haberler',
                            selected: _selectedInfoTab == 1,
                            onTap: () => setState(() => _selectedInfoTab = 1),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_selectedInfoTab == 0) ...[
                        if (a != null) ...[
                          _SummaryCard(items: [
                            _SummaryItem(label: 'Son Fiyat', value: '${a.price.toStringAsFixed(2)} ₺'),
                            _SummaryItem(label: 'Alış Fiyatı', value: '${a.open.toStringAsFixed(2)} ₺'),
                            _SummaryItem(label: 'Satış Fiyatı', value: '${a.price.toStringAsFixed(2)} ₺'),
                            _SummaryItem(label: 'Önceki Kapanış', value: '${a.previousClose.toStringAsFixed(2)} ₺'),
                            _SummaryItem(label: 'Açılış Fiyatı', value: '${a.open.toStringAsFixed(2)} ₺'),
                            _SummaryItem(label: 'Ağırlıklı Ortalama', value: '${a.vwap.toStringAsFixed(2)} ₺'),
                            _SummaryItem(label: 'En Yüksek', value: '${a.high.toStringAsFixed(2)} ₺'),
                            _SummaryItem(label: 'En Düşük', value: '${a.low.toStringAsFixed(2)} ₺'),
                            _SummaryItem(label: 'PD/DD', value: a.pdDd > 0 ? a.pdDd.toStringAsFixed(2) : '-'),
                            _SummaryItem(label: 'F/K', value: a.fk > 0 ? a.fk.toStringAsFixed(2) : '-'),
                            _SummaryItem(label: 'Tavan', value: '${a.ceiling.toStringAsFixed(2)} ₺'),
                            _SummaryItem(label: 'Taban', value: '${a.floor.toStringAsFixed(2)} ₺'),
                            _SummaryItem(label: 'Günlük İşlem Adedi', value: a.latestVolume.toStringAsFixed(0)),
                            _SummaryItem(label: 'Günlük İşlem Hacmi', value: '${a.dailyTurnover.toStringAsFixed(2)} ₺'),
                          ]),
                        ],
                      ] else ...[
                        if (_assetCategory == 'bist') ...[
                          if (_newsLoading)
                            const SizedBox(
                              height: 80,
                              child: Center(child: CircularProgressIndicator(color: Color(0xFF34C759))),
                            )
                          else if (_symbolNews.isEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: surface,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '$_selectedSymbol için henüz haber bulunamadı.',
                                style: TextStyle(color: onSurfaceSecondary, fontSize: 13),
                              ),
                            )
                          else
                            ..._symbolNews.map((item) => Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: surface,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: borderColor.withOpacity(0.4)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              item.cleanTitle.isNotEmpty ? item.cleanTitle : item.title,
                                              style: TextStyle(
                                                color: onSurface,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF34C759).withOpacity(0.12),
                                              borderRadius: BorderRadius.circular(999),
                                            ),
                                            child: Text(
                                              item.source,
                                              style: const TextStyle(
                                                color: Color(0xFF34C759),
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      if (item.summary.isNotEmpty)
                                        Text(
                                          item.summary,
                                          style: TextStyle(color: onSurfaceSecondary, fontSize: 12, height: 1.4),
                                        ),
                                      const SizedBox(height: 6),
                                      Text(
                                        item.time,
                                        style: TextStyle(color: onSurfaceSecondary.withOpacity(0.8), fontSize: 11),
                                      ),
                                    ],
                                  ),
                                )),
                        ] else
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: surface,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Haberler bölümü yalnızca BIST hisseleri için kullanılabilir.',
                              style: TextStyle(color: onSurfaceSecondary, fontSize: 13),
                            ),
                          ),
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

class _InfoTabButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _InfoTabButton({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surface = theme.colorScheme.surface;
    final onSurface = theme.colorScheme.onSurface;
    final color = selected ? const Color(0xFF34C759) : onSurface.withOpacity(0.72);

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF34C759).withOpacity(0.12) : surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: selected ? const Color(0xFF34C759) : theme.dividerColor),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final List<_SummaryItem> items;
  const _SummaryCard({required this.items});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surface = theme.colorScheme.surface;
    final shadowColor = theme.brightness == Brightness.light
        ? Colors.black.withOpacity(0.05)
        : Colors.white.withOpacity(0.05);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: shadowColor, blurRadius: 10)],
      ),
      child: Column(
        children: items.map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _SummaryTile(item: item),
        )).toList(),
      ),
    );
  }
}

class _SummaryItem {
  final String label;
  final String value;
  const _SummaryItem({required this.label, required this.value});
}

class _SummaryTile extends StatelessWidget {
  final _SummaryItem item;
  const _SummaryTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final onSurfaceSecondary = onSurface.withOpacity(0.72);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(item.label, style: TextStyle(color: onSurfaceSecondary, fontSize: 13)),
        Text(item.value, style: TextStyle(color: onSurface, fontSize: 13, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _AlgoCard extends StatelessWidget {
  final String label, signal; final bool? isPositive;
  const _AlgoCard({required this.label, required this.signal, required this.isPositive});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final onSurfaceSecondary = onSurface.withOpacity(0.72);
    final color = isPositive == true ? const Color(0xFF34C759)
        : isPositive == false ? const Color(0xFFFF3B30) : Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(color: theme.colorScheme.surface, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Icon(Icons.settings_input_component, color: onSurfaceSecondary, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: TextStyle(color: onSurface, fontSize: 14))),
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
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              decoration: InputDecoration(
                hintText: 'Hisse ara...',
                hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                prefixIcon: Icon(Icons.search, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                filled: true, fillColor: Theme.of(context).colorScheme.surface,
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
    final theme = Theme.of(context);
    final sel = value == cur;
    return GestureDetector(
      onTap: () => onTap(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: sel ? const Color(0xFF34C759) : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: TextStyle(
            color: sel ? Colors.white : theme.colorScheme.onSurface.withOpacity(0.65), fontWeight: FontWeight.bold, fontSize: 13)),
      ),
    );
  }
}

