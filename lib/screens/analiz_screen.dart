import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/asset_model.dart';
import '../services/stock_service.dart';
import '../services/ai_analysis_service.dart';
import '../widgets/stock_chart.dart';
import '../widgets/indicator_chip.dart';
import '../widgets/stock_quote_panel.dart';
import '../widgets/tutorial_tooltip.dart';
import '../widgets/formatted_analysis_text.dart';
import '../services/portfolio_service.dart';
import '../services/kap_news_service.dart';
import '../services/settings_service.dart';
import '../models/portfolio_model.dart';
import '../models/kap_news_item.dart';
import 'tradingview_screen.dart';
import 'backtest_screen.dart';

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
  final Set<String> _activeIndicators = {'Momentum (14)'};
  List<KapNewsItem> _symbolNews = [];

  // Öğretici tooltip gösterim durumları
  bool _showTvTooltip       = false;
  bool _showBacktestTooltip = false;

  // Üst arama
  final TextEditingController _searchCtrl = TextEditingController();
  List<Map<String, String>> _searchResults = [];

  final List<String> _periods = ['4S', 'G', 'H', '1A', '3A', '1Y'];
  final List<String> _ranges = ['1d', '5d', '1mo', '1mo', '3mo', '1y'];
  final List<String> _intervals = ['5m', '1h', '1d', '1d', '1d', '1wk'];

  final List<Map<String, String>> _indicators = [
    {'label': 'Momentum (14)', 'icon': 'rsi'},
    {'label': 'Ort. 20', 'icon': 'ma'},
    {'label': 'Ort. 50', 'icon': 'ma'},
    {'label': 'Süper Trend', 'icon': 'st'},
    {'label': 'Güç Göstergesi', 'icon': 'macd'},
  ];

  @override
  void initState() {
    super.initState();
    _selectedSymbol = widget.initialSymbol ?? 'THYAO';
    _tabController = TabController(length: 1, vsync: this);
    _load();

    // Tooltip'leri Hive'dan oku — build sonrasında setState ile göster
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _showTvTooltip       = !SettingsService.isTradingViewTooltipSeen;
        _showBacktestTooltip = !SettingsService.isBacktestTooltipSeen;
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Aktif göstergeye göre sinyal ID'si döner (backtest servisi için — değiştirilmez)
  String _resolveSignalId() {
    if (_activeIndicators.contains('Güç Göstergesi')) return 'MACD Bullish';
    if (_activeIndicators.contains('Süper Trend'))    return 'Supertrend AL';
    if (_activeIndicators.contains('Ort. 20') &&
        _activeIndicators.contains('Ort. 50'))        return 'Golden Cross';
    if (_activeIndicators.contains('Momentum (14)')) return 'RSI 40';
    return 'MACD Bullish';
  }

  /// Aktif göstergeye göre kullanıcı dostu Türkçe etiket döner
  String _resolveSignalLabel() {
    if (_activeIndicators.contains('Güç Göstergesi')) return '📊 Güç Göstergesi AL';
    if (_activeIndicators.contains('Süper Trend'))    return '⚡ Süper Trend AL';
    if (_activeIndicators.contains('Ort. 20') &&
        _activeIndicators.contains('Ort. 50'))        return '✨ Altın Kesişim AL';
    if (_activeIndicators.contains('Momentum (14)')) return '📊 Momentum Dip AL';
    return '📊 Güç Göstergesi AL';
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

                      // TradingView butonu (sadece BIST hisseleri için)
                      if (_assetCategory == 'bist')
                        TutorialTooltip(
                          visible: _showTvTooltip,
                          icon: Icons.show_chart,
                          iconColor: const Color(0xFF1565C0),
                          title: 'TradingView ile Gelişmiş Grafik',
                          body:
                              'TradingView, dünyaca tanınan profesyonel bir grafik platformudur. '
                              'Bu butona tıklayarak ${_selectedSymbol} hissesini '
                              'onlarca indikatör, çizim aracı ve farklı zaman dilimleriyle '
                              'derinlemesine inceleyebilirsiniz.',
                          onDismiss: () {
                            SettingsService.markTradingViewTooltipSeen();
                            setState(() => _showTvTooltip = false);
                          },
                          child: GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => TradingViewScreen(
                                    symbol: _selectedSymbol,
                                    name: a?.name ?? _selectedSymbol,
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1565C0),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.show_chart, color: Colors.white, size: 18),
                                  SizedBox(width: 8),
                                  Text(
                                    'TradingView\'da Aç',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                      // ── Stratejiyi Test Et butonu (sadece BIST hisseleri)
                      if (_assetCategory == 'bist') ...[
                        const SizedBox(height: 10),
                        TutorialTooltip(
                          visible: _showBacktestTooltip,
                          icon: Icons.science_rounded,
                          iconColor: const Color(0xFF34C759),
                          title: 'Stratejiyi Test Et — Geçmiş Sınama',
                          body:
                              'Aktif göstergelerinizi (Momentum, Süper Trend, Hareketli Ortalama vb.) '
                              'geçmiş fiyat verileri üzerinde test edin. '
                              'Sinyal kaç kez oluştu, ortalama getirisi ne oldu, '
                              'başarı oranı ne? Gerçek parayla işlem yapmadan önce '
                              'stratejinizin güçlü olup olmadığını görün.',
                          onDismiss: () {
                            SettingsService.markBacktestTooltipSeen();
                            setState(() => _showBacktestTooltip = false);
                          },
                          child: GestureDetector(
                            onTap: () {
                              // Aktif indikatörden sinyal belirle
                              final signalId    = _resolveSignalId();
                              final signalLabel = _resolveSignalLabel();
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => BacktestScreen(
                                    symbol:      _selectedSymbol,
                                    symbolName:  a?.name ?? _selectedSymbol,
                                    signalId:    signalId,
                                    signalLabel: signalLabel,
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF34C759),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.science_rounded,
                                      color: Colors.white, size: 18),
                                  SizedBox(width: 8),
                                  Text(
                                    'Stratejiyi Test Et',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],

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
                          _TeknikAnalizButton(
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
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.10),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.orange.withOpacity(0.30)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.info_outline, color: Colors.orange, size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Veriler geç gelebilir, değerleri kontrol ediniz. Bilgi amaçlıdır.',
                                    style: TextStyle(
                                      color: Colors.orange.shade300,
                                      fontSize: 12,
                                      height: 1.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ] else ...[
                        if (a != null)
                          _TeknikAnalizPanel(
                            key: ValueKey('$_selectedSymbol${_periods[_selectedPeriod]}'),
                            asset: a,
                            periodLabel: _periods[_selectedPeriod],
                          )
                        else
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: surface,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Teknik analiz için veri yükleniyor...',
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
    final isDark = theme.brightness == Brightness.dark;
    final surface = theme.colorScheme.surface;
    final onSurface = theme.colorScheme.onSurface;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 48,
          margin: const EdgeInsets.all(2.0),
          decoration: BoxDecoration(
            color: selected
                ? (isDark ? const Color(0xFF20232B) : Colors.white)
                : (isDark ? surface.withOpacity(0.5) : const Color(0xFFF1F3F6)),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: selected
                  ? (isDark ? const Color(0xFF3F4452) : const Color(0xFFCBD5E1))
                  : (isDark ? theme.dividerColor.withOpacity(0.3) : const Color(0xFFE2E8F0)),
              width: 1.2,
            ),
            boxShadow: selected && !isDark
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: selected
                    ? (isDark ? Colors.white : const Color(0xFF1E293B))
                    : onSurface.withOpacity(0.65),
                fontWeight: selected ? FontWeight.bold : FontWeight.w600,
                fontSize: 14,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TeknikAnalizButton extends StatefulWidget {
  final bool selected;
  final VoidCallback onTap;

  const _TeknikAnalizButton({
    required this.selected,
    required this.onTap,
  });

  @override
  State<_TeknikAnalizButton> createState() => _TeknikAnalizButtonState();
}

class _TeknikAnalizButtonState extends State<_TeknikAnalizButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Expanded(
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return CustomPaint(
              painter: _TeknikAnalizNeonGlowPainter(
                progress: _controller.value,
                isDark: isDark,
                isSelected: widget.selected,
              ),
              child: child,
            );
          },
          child: Container(
            height: 48,
            margin: const EdgeInsets.all(2.0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDark
                    ? [
                        const Color(0xFF1B1D24),
                        const Color(0xFF111216),
                      ]
                    : [
                        Colors.white,
                        const Color(0xFFF5F7FA),
                      ],
              ),
              boxShadow: !isDark
                  ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.35),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: Center(
              child: Text(
                'Teknik Analiz',
                style: TextStyle(
                  color: isDark
                      ? Colors.white
                      : const Color(0xFF283344),
                  fontWeight: widget.selected ? FontWeight.bold : FontWeight.w600,
                  fontSize: 14,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TeknikAnalizNeonGlowPainter extends CustomPainter {
  final double progress;
  final bool isDark;
  final bool isSelected;

  _TeknikAnalizNeonGlowPainter({
    required this.progress,
    required this.isDark,
    required this.isSelected,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(1.5),
      Radius.circular((size.height - 3.0) / 2),
    );

    final angle = progress * 2 * math.pi;

    final coreColors = [
      const Color(0xFF00E5FF), // Cyan
      const Color(0xFF0080FF), // Electric Blue
      const Color(0xFF00E5FF), // Cyan
      const Color(0xFFFFEB3B), // Yellow transition
      const Color(0xFFFF9100), // Neon Orange
      const Color(0xFFFF3D00), // Red Orange
      const Color(0xFFFF9100), // Neon Orange
      const Color(0xFFFFD54F), // Gold
      const Color(0xFF00E5FF), // Back to Cyan
    ];

    final stops = [
      0.0,
      0.15,
      0.35,
      0.50,
      0.65,
      0.80,
      0.90,
      0.96,
      1.0,
    ];

    final double intensity = isSelected ? 1.0 : 0.72;

    final bloomColors = coreColors
        .map((c) => c.withOpacity((isDark ? 0.75 : 0.50) * intensity))
        .toList();

    final midColors = coreColors
        .map((c) => c.withOpacity((isDark ? 0.90 : 0.70) * intensity))
        .toList();

    final rimColors = coreColors
        .map((c) => c.withOpacity(intensity))
        .toList();

    final bloomGradient = SweepGradient(
      center: Alignment.center,
      colors: bloomColors,
      stops: stops,
      transform: GradientRotation(angle),
    );

    final midGradient = SweepGradient(
      center: Alignment.center,
      colors: midColors,
      stops: stops,
      transform: GradientRotation(angle),
    );

    final rimGradient = SweepGradient(
      center: Alignment.center,
      colors: rimColors,
      stops: stops,
      transform: GradientRotation(angle),
    );

    // 1. Soft Outer Bloom Aura
    final bloomPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = isDark ? 8.0 : 6.0
      ..shader = bloomGradient.createShader(rect)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, isDark ? 9.0 : 6.5);

    // 2. Mid Glow Layer
    final midPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = isDark ? 4.0 : 3.0
      ..shader = midGradient.createShader(rect)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3.5);

    // 3. Crisp Rim Stroke
    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..shader = rimGradient.createShader(rect);

    canvas.drawRRect(rrect, bloomPaint);
    canvas.drawRRect(rrect, midPaint);
    canvas.drawRRect(rrect, rimPaint);
  }

  @override
  bool shouldRepaint(covariant _TeknikAnalizNeonGlowPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.isDark != isDark ||
        oldDelegate.isSelected != isSelected;
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

// ─────────────────────────────────────────────────────────────────────────────
// TEKNİK ANALİZ PANELİ
// ─────────────────────────────────────────────────────────────────────────────

class _TeknikAnalizPanel extends StatefulWidget {
  final AssetModel asset;
  final String periodLabel;
  const _TeknikAnalizPanel({super.key, required this.asset, this.periodLabel = 'Günlük'});

  @override
  State<_TeknikAnalizPanel> createState() => _TeknikAnalizPanelState();
}

class _TeknikAnalizPanelState extends State<_TeknikAnalizPanel> {
  String? _aiText;
  bool _aiLoading = false;
  bool _aiUsed = false; // AI yanıtı başarıyla alındı mı?

  AssetModel get asset => widget.asset;

  @override
  void initState() {
    super.initState();
    _fetchAiAnalysis();
  }

  @override
  void didUpdateWidget(_TeknikAnalizPanel old) {
    super.didUpdateWidget(old);
    if (old.asset.symbol != widget.asset.symbol ||
        old.periodLabel != widget.periodLabel) {
      _aiText = null;
      _aiUsed = false;
      _fetchAiAnalysis();
    }
  }

  Future<void> _fetchAiAnalysis() async {
    if (_aiLoading) return;
    setState(() => _aiLoading = true);

    final sup = _supportLevels();
    final res = _resistanceLevels();

    final result = await AiAnalysisService.fetchAnalysis(
      asset: asset,
      emaAboveCount: _emaAboveCount,
      rsiValue: _rsiValue,
      supportLevel: sup.isNotEmpty ? sup.first : null,
      resistanceLevel: res.isNotEmpty ? res.first : null,
      volumeIncreasing: _volumeIncreasing,
      periodChange: _periodChange,
      periodLabel: widget.periodLabel,
    );

    if (mounted) {
      setState(() {
        _aiLoading = false;
        if (result != null && result.isNotEmpty) {
          _aiText = result;
          _aiUsed = true;
        } else {
          _aiText = null;
          _aiUsed = false;
        }
      });
    }
  }

  // ── Destek / Direnç hesaplama (pivot high/low yöntemi) ──────────────────────
  List<double> _resistanceLevels() {
    final p = asset.prices;
    if (p.isEmpty) return [];
    final highs = asset.highs.isNotEmpty ? asset.highs : p;
    final levels = <double>[];
    final lookback = p.length > 60 ? p.length - 60 : 0;
    for (int i = lookback + 2; i < highs.length - 2; i++) {
      if (highs[i] > highs[i - 1] &&
          highs[i] > highs[i - 2] &&
          highs[i] > highs[i + 1] &&
          highs[i] > highs[i + 2]) {
        levels.add(highs[i]);
      }
    }
    levels.sort((a, b) => a.compareTo(b));
    final current = asset.price;
    final above = levels.where((v) => v > current * 1.005).toList();
    return above.take(2).toList();
  }

  List<double> _supportLevels() {
    final p = asset.prices;
    if (p.isEmpty) return [];
    final lows = asset.lows.isNotEmpty ? asset.lows : p;
    final levels = <double>[];
    final lookback = p.length > 60 ? p.length - 60 : 0;
    for (int i = lookback + 2; i < lows.length - 2; i++) {
      if (lows[i] < lows[i - 1] &&
          lows[i] < lows[i - 2] &&
          lows[i] < lows[i + 1] &&
          lows[i] < lows[i + 2]) {
        levels.add(lows[i]);
      }
    }
    levels.sort((a, b) => b.compareTo(a));
    final current = asset.price;
    final below = levels.where((v) => v < current * 0.995).toList();
    return below.take(3).toList();
  }

  // ── RSI değeri ve yorumu ────────────────────────────────────────────────────
  double get _rsiValue {
    final r = asset.rsi();
    return r.isNotEmpty ? r.last : 0;
  }

  String get _rsiLabel {
    final v = _rsiValue;
    if (v >= 70) return 'Aşırı alım';
    if (v >= 60) return 'Güçlü';
    if (v >= 45) return 'Dengeli';
    if (v >= 30) return 'Zayıf';
    return 'Aşırı satım';
  }

  // ── EMA durumu ──────────────────────────────────────────────────────────────
  // Kaç tane EMA'nın üzerinde? (20, 50, 200)
  int get _emaAboveCount {
    int count = 0;
    final ema20 = asset.ema(20);
    final ema50 = asset.ema(50);
    final ema200 = asset.ema(200);
    if (ema20.isNotEmpty && asset.price > ema20.last) count++;
    if (ema50.isNotEmpty && asset.price > ema50.last) count++;
    if (ema200.isNotEmpty && asset.price > ema200.last) count++;
    return count;
  }

  String get _emaLabel {
    final c = _emaAboveCount;
    if (c == 3) return 'Hepsinin üzerinde';
    if (c == 2) return 'İkisinin üzerinde';
    if (c == 1) return 'Birinin üzerinde';
    return 'Hepsinin altında';
  }

  // ── Hacim yorumu ────────────────────────────────────────────────────────────
  bool get _volumeIncreasing {
    final volumes = asset.volumes;
    if (volumes.length < 6) return false;

    final recentStart = volumes.length > 3 ? volumes.length - 3 : 0;
    final previousEnd = recentStart;
    final previousStart =
        previousEnd > 3 ? previousEnd - 3 : 0;

    if (previousEnd <= previousStart) return false;

    final recent = volumes.sublist(recentStart);
    final previous = volumes.sublist(previousStart, previousEnd);

    final avgRecent =
        recent.reduce((a, b) => a + b) / recent.length;
    final avgPrevious =
        previous.reduce((a, b) => a + b) / previous.length;

    return avgRecent > avgPrevious;
  }

  // ── Dönem değişimi ──────────────────────────────────────────────────────────
  double get _periodChange {
    if (asset.prices.length < 2) return 0;
    final first = asset.prices.first;
    final last = asset.prices.last;
    if (first == 0) return 0;
    return (last - first) / first * 100;
  }

  // ── 52 hafta pozisyonu (0.0–1.0) ────────────────────────────────────────────
  double get _weekPosition {
    final low = asset.low52w;
    final high = asset.high52w;
    if (high == low) return 0.5;
    return (asset.price - low) / (high - low);
  }

  // ── Genel görünüm metni üretici — zengin varyantlar ────────────────────────
  // ── LOCAL TEKNİK ANALİZ MOTORU ─────────────────────────────────────────────
  //
  // Cloud AI cevap veremezse kullanılan yerel motor.
  // Önce teknik ilişkileri hesaplar, sonra bu ilişkileri doğal Türkçe
  // cümlelere dönüştürür. Rastgele cümle seçimi yoktur; aynı veri aynı
  // sonucu üretir ve çelişkili yorumların önüne geçilir.
  String _buildGenel() {
    final price = asset.price;
    final rsi = _rsiValue;
    final change = _periodChange;

    final ema20List = asset.ema(20);
    final ema50List = asset.ema(50);
    final ema200List = asset.ema(200);

    final ema20 = ema20List.isNotEmpty ? ema20List.last : null;
    final ema50 = ema50List.isNotEmpty ? ema50List.last : null;
    final ema200 = ema200List.isNotEmpty ? ema200List.last : null;

    final support = _supportLevels();
    final resistance = _resistanceLevels();

    final parts = <String>[];

    // ── 1. Trend: fiyatın EMA'lara göre gerçek konumu ───────────────────────
    if (ema20 != null && ema50 != null && ema200 != null) {
      if (price > ema20 && price > ema50 && price > ema200) {
        parts.add(
          '${asset.name} fiyatı 20, 50 ve 200 günlük üssel hareketli '
          'ortalamaların üzerinde. Kısa, orta ve uzun vadeli trend yapısı '
          'aynı yönde güçlü.',
        );
      } else if (price < ema20 && price < ema50 && price < ema200) {
        parts.add(
          '${asset.name} fiyatı 20, 50 ve 200 günlük üssel hareketli '
          'ortalamaların altında. Ana trend baskı altında ve fiyat henüz '
          'önemli ortalamaların üzerine çıkabilmiş değil.',
        );
      } else if (price > ema20 && price > ema50 && price <= ema200) {
        parts.add(
          '${asset.name} kısa ve orta vadeli ortalamalarının üzerinde, '
          'ancak 200 günlük ortalamanın altında. Kısa vadeli toparlanma '
          'var; uzun vadeli trend için henüz tam teyit yok.',
        );
      } else if (price > ema20 && price <= ema50 && price <= ema200) {
        parts.add(
          '${asset.name} 20 günlük ortalamanın üzerinde tutunuyor ancak '
          '50 ve 200 günlük ortalamaların altında. Kısa vadeli toparlanma '
          'denemesi var fakat ana trend henüz değişmiş değil.',
        );
      } else if (price <= ema20 && price > ema50 && price > ema200) {
        parts.add(
          '${asset.name} 50 ve 200 günlük ortalamaların üzerinde kalırken '
          '20 günlük ortalamanın altında. Uzun vadeli yapı korunuyor ancak '
          'kısa vadede bir miktar zayıflama var.',
        );
      } else {
        parts.add(
          '${asset.name} hareketli ortalamalara göre karma bir görünüm '
          'sergiliyor. Kısa, orta ve uzun vadeli trendler aynı yönde değil.',
        );
      }
    } else {
      final count = _emaAboveCount;
      if (count >= 2) {
        parts.add(
          '${asset.name} hesaplanabilen hareketli ortalamaların çoğunun '
          'üzerinde seyrediyor; trend görünümü destekleniyor.',
        );
      } else if (count == 0) {
        parts.add(
          '${asset.name} hesaplanabilen hareketli ortalamaların altında '
          'seyrediyor; trend görünümü zayıf.',
        );
      } else {
        parts.add(
          '${asset.name} hareketli ortalamalara göre karma bir görünüm '
          'sergiliyor.',
        );
      }
    }

    // ── 2. EMA20 / EMA50 ilişkisi ──────────────────────────────────────────
    if (ema20 != null && ema50 != null && ema50 != 0) {
      final gap = ((ema20 - ema50) / ema50) * 100;

      if (asset.isGoldenCross) {
        parts.add(
          '20 günlük EMA ile 50 günlük EMA arasında yukarı yönlü kesişim '
          'sinyali bulunuyor. Bu, kısa ve orta vadeli momentum açısından '
          'olumlu bir gelişme.',
        );
      } else if (asset.isDeathCross) {
        parts.add(
          '20 günlük EMA ile 50 günlük EMA arasında aşağı yönlü kesişim '
          'sinyali bulunuyor. Bu, kısa ve orta vadeli momentum üzerindeki '
          'baskının arttığını gösteriyor.',
        );
      } else if (gap > 1) {
        parts.add(
          '20 günlük EMA, 50 günlük EMA\'nın %${gap.toStringAsFixed(1)} '
          'üzerinde. Kısa vadeli momentum orta vadeye göre daha güçlü.',
        );
      } else if (gap < -1) {
        parts.add(
          '20 günlük EMA, 50 günlük EMA\'nın %${gap.abs().toStringAsFixed(1)} '
          'altında. Kısa vadeli momentum orta vadeye göre daha zayıf.',
        );
      }
    }

    // ── 3. RSI ─────────────────────────────────────────────────────────────
    if (rsi >= 70) {
      parts.add(
        'RSI ${rsi.toStringAsFixed(0)} seviyesinde ve aşırı alım bölgesinde. '
        'Momentum güçlü olsa da kısa vadede soluklanma veya düzeltme ihtimali '
        'artmış durumda.',
      );
    } else if (rsi >= 60) {
      parts.add(
        'RSI ${rsi.toStringAsFixed(0)} seviyesinde. Momentum pozitif ve '
        'henüz klasik aşırı alım bölgesinde değil.',
      );
    } else if (rsi >= 50) {
      parts.add(
        'RSI ${rsi.toStringAsFixed(0)} seviyesinde. Momentum nötr-pozitif '
        'bölgede ve belirgin bir aşırılık göstermiyor.',
      );
    } else if (rsi >= 40) {
      parts.add(
        'RSI ${rsi.toStringAsFixed(0)} seviyesinde. Momentum zayıf-nötr '
        'bölgede; alıcılar henüz belirgin üstünlük kurmuş değil.',
      );
    } else if (rsi >= 30) {
      parts.add(
        'RSI ${rsi.toStringAsFixed(0)} seviyesinde. Momentum zayıf ve '
        '30 seviyesine yakın; ancak klasik aşırı satım bölgesine henüz girmedi.',
      );
    } else {
      parts.add(
        'RSI ${rsi.toStringAsFixed(0)} seviyesinde ve klasik aşırı satım '
        'bölgesinde. Teknik tepki ihtimali artabilir ancak RSI tek başına '
        'trend dönüşü teyidi değildir.',
      );
    }

    // ── 4. MACD: AssetModel'deki gerçek anlam histogram sıfır geçişi ────────
    if (asset.isMacdBullish) {
      parts.add(
        'MACD histogramının negatiften pozitife dönmesi kısa vadeli '
        'momentumda toparlanma sinyali veriyor. Ancak bunun kalıcı bir trend '
        'dönüşümü sayılması için fiyat hareketinin de destek vermesi gerekiyor.',
      );
    } else if (asset.isMacdBearish) {
      parts.add(
        'MACD histogramının pozitiften negatife dönmesi kısa vadeli '
        'momentumun zayıfladığına işaret ediyor.',
      );
    }

    // ── 5. Supertrend ─────────────────────────────────────────────────────
    if (asset.isSupertrendBuy) {
      parts.add(
        'Supertrend tarafında AL yönlü sinyal oluşmuş. Bu kısa vadeli '
        'toparlanmayı destekliyor; ancak ana trendle birlikte okunmalı.',
      );
    } else if (asset.isSupertrendSell) {
      parts.add(
        'Supertrend tarafında SAT yönlü sinyal oluşmuş. Kısa vadeli '
        'aşağı yönlü baskı artmış görünüyor.',
      );
    }

    // ── 6. Uyuşmazlık ───────────────────────────────────────────────────────
    if (asset.isBullishDivergence) {
      parts.add(
        'Pozitif uyuşmazlık görülüyor. Fiyat zayıflarken momentumun aynı '
        'ölçüde zayıflamaması satış baskısının azalıyor olabileceğine işaret '
        'ediyor; fiyat teyidi yine de gerekli.',
      );
    } else if (asset.isBearishDivergence) {
      parts.add(
        'Negatif uyuşmazlık görülüyor. Fiyat yükselirken momentumun '
        'zayıflaması yükseliş gücünün azalabileceğine işaret ediyor.',
      );
    }

    // ── 7. Mum formasyonları ───────────────────────────────────────────────
    if (asset.isHammer) {
      parts.add(
        'Son mumda Çekiç formasyonu oluşmuş. Alt bölgede alıcıların '
        'devreye girdiğine dair kısa vadeli bir işaret var.',
      );
    } else if (asset.isBullishEngulfing) {
      parts.add(
        'Yutan Boğa formasyonu oluşmuş. Son mumda alıcıların kısa vadeli '
        'kontrolü artırdığı görülüyor.',
      );
    } else if (asset.isMorningStar) {
      parts.add(
        'Sabah Yıldızı formasyonu görülüyor. Dip bölgesinde toparlanmayı '
        'destekleyen bir mum yapısı oluşmuş.',
      );
    } else if (asset.isBearishEngulfing) {
      parts.add(
        'Yutan Ayı formasyonu oluşmuş. Satıcıların kısa vadeli baskısı '
        'artmış görünüyor.',
      );
    } else if (asset.isDoji) {
      parts.add(
        'Son mumda Doji oluşmuş. Alıcı ve satıcılar arasında kararsızlık '
        'var; sonraki fiyat hareketi yön açısından önemli.',
      );
    }

    // ── 8. Hacim: sadece artıyor/azalıyor demek yerine 20 günlük kıyas ────
    final volumeRatio = _volume20Ratio;
    if (volumeRatio != null) {
      if (volumeRatio >= 1.50) {
        parts.add(
          'Son işlem hacmi 20 günlük ortalamanın yaklaşık '
          '%${((volumeRatio - 1) * 100).toStringAsFixed(0)} üzerinde. '
          'Piyasaya katılım belirgin şekilde artmış durumda; ancak hacim '
          'tek başına yönün pozitif olduğunu göstermez.',
        );
      } else if (volumeRatio >= 1.30) {
        parts.add(
          'Son işlem hacmi 20 günlük ortalamanın yaklaşık '
          '%${((volumeRatio - 1) * 100).toStringAsFixed(0)} üzerinde. '
          'Hareketin arkasındaki katılım normalin üzerinde.',
        );
      } else if (volumeRatio >= 1.0) {
        parts.add(
          'Son işlem hacmi 20 günlük ortalamaya yakın veya üzerinde. '
          'Fiyat hareketinin hacim tarafında belirgin bir zayıflama yok.',
        );
      } else if (volumeRatio >= 0.70) {
        parts.add(
          'Son işlem hacmi 20 günlük ortalamanın altında. '
          'Fiyat hareketinin arkasındaki katılım sınırlı.',
        );
      } else {
        parts.add(
          'Son işlem hacmi 20 günlük ortalamanın belirgin şekilde altında. '
          'Hareket düşük katılımla gerçekleşiyor.',
        );
      }
    } else if (_volumeIncreasing) {
      parts.add(
        'İşlem hacmi son günlerde artıyor. Piyasaya katılım güçleniyor; '
        'ancak hacim tek başına yön belirlemez.',
      );
    } else {
      parts.add(
        'İşlem hacmi son günlerde zayıflıyor. Mevcut fiyat hareketinin '
        'hacim tarafından teyidi sınırlı.',
      );
    }

    // ── 9. Destek / direnç ─────────────────────────────────────────────────
    if (support.isNotEmpty && resistance.isNotEmpty) {
      final s = support.first;
      final r = resistance.first;

      if (price <= s * 1.01) {
        parts.add(
          'Fiyat ${s.toStringAsFixed(2)} seviyesindeki yakın desteğe '
          'yakın. Bu seviyenin korunması kısa vadeli görünüm açısından önemli.',
        );
      } else if (price >= r * 0.99) {
        parts.add(
          'Fiyat ${r.toStringAsFixed(2)} seviyesindeki yakın dirence '
          'yaklaşmış durumda. Bu bölgede oluşacak fiyat hareketi önemli.',
        );
      } else {
        parts.add(
          'Yakın destek ${s.toStringAsFixed(2)}, yakın direnç '
          '${r.toStringAsFixed(2)} seviyesinde. Fiyat şu anda bu iki seviye '
          'arasında bulunuyor.',
        );
      }
    } else if (support.isNotEmpty) {
      parts.add(
        'Yakın destek ${support.first.toStringAsFixed(2)} seviyesinde. '
        'Bu seviyenin korunması aşağı yönlü baskının artmaması açısından önemli.',
      );
    } else if (resistance.isNotEmpty) {
      parts.add(
        'Yakın direnç ${resistance.first.toStringAsFixed(2)} seviyesinde. '
        'Bu bölgedeki fiyat davranışı kısa vadeli yön açısından önemli.',
      );
    }

    // ── 10. Dönem performansı ──────────────────────────────────────────────
    if (change >= 20) {
      parts.add(
        'Seçili dönemde fiyat %${change.toStringAsFixed(1)} yükselmiş. '
        'Bu performansın ardından mevcut teknik seviyelerin korunması önemli.',
      );
    } else if (change <= -20) {
      parts.add(
        'Seçili dönemde fiyat %${change.abs().toStringAsFixed(1)} gerilemiş. '
        'Bu nedenle toparlanma sinyallerinin kalıcı olup olmadığı izlenmeli.',
      );
    } else if (change > 0) {
      parts.add(
        'Seçili dönemde fiyat %${change.toStringAsFixed(1)} yükselmiş; '
        'hareket henüz belirgin bir trend performansı oluşturmuyor.',
      );
    } else if (change < 0) {
      parts.add(
        'Seçili dönemde fiyat %${change.abs().toStringAsFixed(1)} gerilemiş; '
        'toparlanma sinyallerinin fiyat tarafından teyit edilmesi gerekiyor.',
      );
    }

    // ── 11. Sinyalleri birlikte okuma ──────────────────────────────────────
    final bullish = <String>[];
    final bearish = <String>[];

    if (_emaAboveCount >= 2) bullish.add('ortalamalar');
    if (_emaAboveCount == 0) bearish.add('ortalamalar');

    if (asset.isGoldenCross) bullish.add('Golden Cross');
    if (asset.isDeathCross) bearish.add('Death Cross');

    if (asset.isMacdBullish) bullish.add('MACD');
    if (asset.isMacdBearish) bearish.add('MACD');

    if (asset.isSupertrendBuy) bullish.add('Supertrend');
    if (asset.isSupertrendSell) bearish.add('Supertrend');

    if (asset.isBullishDivergence) bullish.add('pozitif uyuşmazlık');
    if (asset.isBearishDivergence) bearish.add('negatif uyuşmazlık');

    if (asset.isHammer ||
        asset.isBullishEngulfing ||
        asset.isMorningStar) {
      bullish.add('mum formasyonu');
    }

    if (asset.isBearishEngulfing) bearish.add('mum formasyonu');
    if (rsi < 40) bearish.add('zayıf RSI');

    // Ana trend zayıf + kısa vadeli toparlanma sinyalleri:
    if (_emaAboveCount <= 1 &&
        (asset.isMacdBullish ||
            asset.isBullishDivergence ||
            asset.isSupertrendBuy)) {
      parts.add(
        'Sinyaller birlikte değerlendirildiğinde ana trend henüz güçlü '
        'bir yükseliş yapısına dönüşmüş değil; buna karşılık kısa vadeli '
        'toparlanmayı destekleyen göstergeler bulunuyor. Mevcut tablo '
        'zayıf trend içinde toparlanma denemesi şeklinde okunabilir.',
      );
    } else if (_emaAboveCount >= 2 &&
        bullish.length >= bearish.length + 2) {
      parts.add(
        'Teknik göstergelerin önemli bölümü aynı yönde. Trend ve momentum '
        'tarafında olumlu sinyaller birbirini destekliyor.',
      );
    } else if (bearish.length >= bullish.length + 2) {
      parts.add(
        'Teknik göstergelerin önemli bölümü aşağı yönlü baskıya işaret ediyor. '
        'Kısa vadeli tepki oluşsa bile bunun kalıcı trend dönüşümü olduğunu '
        'söylemek için ek teyit gerekiyor.',
      );
    } else {
      parts.add(
        'Teknik göstergeler tamamen aynı yönde değil. Bu nedenle trend, '
        'momentum, hacim ve kritik fiyat seviyeleri birlikte izlenmeli.',
      );
    }

    // ── 12. Sonuç ──────────────────────────────────────────────────────────
    if (_emaAboveCount == 3 &&
        bullish.length >= bearish.length + 2) {
      parts.add(
        'Genel görünüm: Trend ve momentum tarafında güçlü bir yapı var; '
        'kritik desteklerin korunması takip edilmeli.',
      );
    } else if (_emaAboveCount == 0 &&
        bearish.length >= bullish.length) {
      parts.add(
        'Genel görünüm: Ana trend zayıf ve aşağı yönlü baskı devam ediyor. '
        'Olumlu sinyaller oluşsa bile trend teyidi ayrıca takip edilmeli.',
      );
    } else if (rsi < 40 &&
        (asset.isMacdBullish || asset.isBullishDivergence)) {
      parts.add(
        'Genel görünüm: Momentum zayıf olmasına rağmen kısa vadeli '
        'toparlanma sinyalleri oluşuyor. Tepkinin kalıcı olup olmadığı '
        'fiyat ve hacim tarafından teyit edilmeli.',
      );
    } else {
      parts.add(
        'Genel görünüm: Teknik tablo karışık. Tek bir gösterge yerine '
        'trend, momentum, hacim ve kritik fiyat seviyeleri birlikte okunmalı.',
      );
    }

    parts.add(
      'Bu analiz yalnızca mevcut teknik verilere dayanır ve yatırım tavsiyesi değildir.',
    );

    return parts.join('\n\n');
  }

  // Son hacmin 20 günlük ortalamaya oranı.
  double? get _volume20Ratio {
    final volumes = asset.volumes;
    if (volumes.length < 2) return null;

    final end = volumes.length;
    final start = end > 21 ? end - 21 : 0;
    final previous = volumes.sublist(start, end - 1);

    if (previous.isEmpty) return null;

    final avg = previous.reduce((a, b) => a + b) / previous.length;
    if (avg <= 0) return null;

    return volumes.last / avg;
  }


  // ── Artılar / Eksiler ────────────────────────────────────────────────────────
  List<String> _pros() {
    final list = <String>[];
    final ema20 = asset.ema(20);
    final ema50 = asset.ema(50);
    final ema200 = asset.ema(200);
    final rsi = _rsiValue;

    if (ema200.isNotEmpty && asset.price > ema200.last) {
      list.add('Fiyat 200 günlük uzun vadeli ortalamanın üstünde. Büyük resim sağlam.');
    }
    if (ema20.isNotEmpty && ema50.isNotEmpty && ema20.last > ema50.last) {
      list.add('Kısa vadeli ortalama (20 günlük) orta vadeli ortalamanın (50 günlük) üstünde. Olumlu sinyal.');
    }
    if (asset.fk > 0 && asset.fk < 15) {
      list.add('Fiyat/Kazanç oranı ${asset.fk.toStringAsFixed(0)}. Kazancına göre makul fiyatlanıyor.');
    }
    if (rsi >= 45 && rsi < 65) {
      list.add('Momentum göstergesi ${rsi.toStringAsFixed(0)}. Dengeli bölge, aşırılık yok.');
    }
    if (_periodChange > 30) {
      list.add('Dönem içinde %${_periodChange.toStringAsFixed(0)} yükseldi. Güçlü trend.');
    }
    if (asset.isBullishDivergence) {
      list.add('Olumlu momentum uyuşmazlığı var. Güç dönüşü sinyali.');
    }
    if (_emaAboveCount == 3) {
      list.add('Tüm önemli hareketli ortalamaların üzerinde. Trend güçlü.');
    }
    return list;
  }

  List<String> _cons() {
    final list = <String>[];
    final res = _resistanceLevels();
    final rsi = _rsiValue;
    final change = _periodChange;
    final ema200 = asset.ema(200);

    if (res.isNotEmpty) {
      list.add('Direnç çok yakın (${res.first.toStringAsFixed(2)}). Yükseliş için önce onu aşmalı.');
    }
    if (rsi >= 70) {
      list.add('Momentum göstergesi aşırı alım bölgesinde (${rsi.toStringAsFixed(0)}). Kâr realizasyonu riski var.');
    }
    if (change > 80) {
      list.add('Bu dönemde %${change.toStringAsFixed(0)} yükseldi. Geç kalma riski var.');
    }
    if (!_volumeIncreasing) {
      list.add('Hacim azalıyor. Yükseliş teyitsiz kalabilir.');
    }
    if (ema200.isNotEmpty && asset.price < ema200.last) {
      list.add('200 günlük uzun vadeli ortalama baskısı devam ediyor.');
    }
    if (asset.isBearishDivergence) {
      list.add('Olumsuz momentum uyuşmazlığı var. Düşüş sinyali gözüküyor.');
    }
    if (_emaAboveCount == 0) {
      list.add('Tüm önemli hareketli ortalamaların altında. Genel tablo baskılı.');
    }
    return list;
  }

  // ── Net yargı ────────────────────────────────────────────────────────────────
  String _netYargi() {
    final pros = _pros().length;
    final cons = _cons().length;
    if (pros > cons + 1) return 'Genel görünüm olumlu. Teknikler destekliyor.';
    if (cons > pros + 1) return 'Genel görünüm temkinli. Dikkatli olunmalı.';
    return 'Artılar ve eksiler başa baş. Beklemek de bir karardır.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final onSurfaceSecondary = onSurface.withOpacity(0.65);
    final shadowColor = theme.brightness == Brightness.light
        ? Colors.black.withOpacity(0.05)
        : Colors.white.withOpacity(0.04);

    final rsi = _rsiValue;
    final emaCount = _emaAboveCount;
    final change = _periodChange;
    final supLevels = _supportLevels();
    final resLevels = _resistanceLevels();
    final pros = _pros();
    final cons = _cons();
    final weekPos = _weekPosition;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Genel Görünüm Kartı ──────────────────────────────────────────────
        _TeknikKart(
          shadow: shadowColor,
          header: '[ Genel görünüm ]',
          isAi: true,
          child: _aiLoading
              ? const _AiLoadingRow()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FormattedAnalysisText(
                      text: _aiText ?? _buildGenel(),
                      style: TextStyle(color: onSurface, fontSize: 13, height: 1.68),
                    ),
                    const SizedBox(height: 12),
                    _AnalizBadgeRow(
                      isAi: _aiUsed,
                      onRefresh: () {
                        setState(() { _aiText = null; _aiUsed = false; });
                        _fetchAiAnalysis();
                      },
                    ),
                  ],
                ),
        ),

        // ── Şimdi almayı düşünüyorsan ──────────────────────────────────────
        _TeknikKart(
          shadow: shadowColor,
          header: '[ Şimdi almayı düşünüyorsan ]',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _netYargi(),
                style: TextStyle(
                  color: onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 14),
              if (pros.isNotEmpty) ...[
                Text('Artılar',
                    style: TextStyle(
                        color: onSurfaceSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                ...pros.map((p) => _BulletRow(
                    text: p,
                    icon: '+',
                    color: const Color(0xFF34C759))),
                const SizedBox(height: 12),
              ],
              if (cons.isNotEmpty) ...[
                Text('Eksiler',
                    style: TextStyle(
                        color: onSurfaceSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                ...cons.map((c) => _BulletRow(
                    text: c,
                    icon: '—',
                    color: const Color(0xFFFF3B30))),
                const SizedBox(height: 8),
              ],
              Text(
                'Bu bir yatırım tavsiyesi değil. Tabloyu sadeleştirdim; kararı sen verirsin.',
                style: TextStyle(
                    color: onSurfaceSecondary,
                    fontSize: 11,
                    fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),

        // ── Destek / Direnç ──────────────────────────────────────────────────
        _TeknikKart(
          shadow: shadowColor,
          header: '[ Destek ve direnç ]',
          badge: '${resLevels.length + supLevels.length} seviye',
          child: Column(
            children: [
              // Direnç seviyeleri
              ...resLevels.map((v) => _SeviyeRow(
                    label: 'Direnç',
                    value: v,
                    currentPrice: asset.price,
                    isResistance: true,
                    onSurface: onSurface,
                    onSurfaceSecondary: onSurfaceSecondary,
                  )),
              if (resLevels.isNotEmpty) const SizedBox(height: 4),
              // Son fiyat ortada
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Text('Son fiyat',
                        style: TextStyle(
                            color: onSurfaceSecondary, fontSize: 12)),
                    const Spacer(),
                    Text(
                      asset.price.toStringAsFixed(2),
                      style: TextStyle(
                          color: onSurface,
                          fontSize: 20,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              if (supLevels.isNotEmpty) const Divider(height: 1),
              const SizedBox(height: 4),
              // Destek seviyeleri
              ...supLevels.map((v) => _SeviyeRow(
                    label: 'Destek',
                    value: v,
                    currentPrice: asset.price,
                    isResistance: false,
                    onSurface: onSurface,
                    onSurfaceSecondary: onSurfaceSecondary,
                  )),
            ],
          ),
        ),

        // ── Momentum + Ortalamalar (yan yana) ───────────────────────────────
        Row(
          children: [
            Expanded(
              child: _TeknikKart(
                shadow: shadowColor,
                header: '[ Momentum (14) ]',
                trailingIcon: Icons.show_chart,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rsi.toStringAsFixed(2).replaceAll('.', ','),
                      style: TextStyle(
                        color: onSurface,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(_rsiLabel,
                        style: TextStyle(
                            color: _rsiColor(rsi), fontSize: 12)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _TeknikKart(
                shadow: shadowColor,
                header: '[ Ortalamalar ]',
                trailingIcon: Icons.keyboard_arrow_up,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$emaCount/3',
                      style: TextStyle(
                        color: onSurface,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(_emaLabel,
                        style: TextStyle(
                            color: emaCount >= 2
                                ? const Color(0xFF34C759)
                                : emaCount == 1
                                    ? Colors.orange
                                    : const Color(0xFFFF3B30),
                            fontSize: 12)),
                  ],
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 0),

        // ── Hacim + Dönem Değişimi (yan yana) ───────────────────────────────
        Row(
          children: [
            Expanded(
              child: _TeknikKart(
                shadow: shadowColor,
                header: '[ Hacim ]',
                trailingIcon:
                    _volumeIncreasing ? Icons.trending_up : Icons.trending_down,
                trailingIconColor:
                    _volumeIncreasing ? const Color(0xFF34C759) : const Color(0xFFFF3B30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _volumeIncreasing ? 'Artıyor' : 'Azalıyor',
                      style: TextStyle(
                        color: onSurface,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _volumeIncreasing
                          ? 'Katılım güçleniyor'
                          : 'Katılım zayıflıyor',
                      style:
                          TextStyle(color: onSurfaceSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _TeknikKart(
                shadow: shadowColor,
                header: '[ Dönem değişimi ]',
                trailingIcon: Icons.swap_horiz,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${change >= 0 ? '+' : ''}${change.toStringAsFixed(1).replaceAll('.', ',')}%',
                      style: TextStyle(
                        color: change >= 0
                            ? const Color(0xFF34C759)
                            : const Color(0xFFFF3B30),
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('Görünen aralıkta',
                        style:
                            TextStyle(color: onSurfaceSecondary, fontSize: 12)),
                  ],
                ),
              ),
            ),
          ],
        ),

        // ── Temel Görünüm ────────────────────────────────────────────────────
        _TeknikKart(
          shadow: shadowColor,
          header: '[ Temel görünüm ]',
          badge: 'İstanbul',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text('52 hafta',
                    style: TextStyle(
                        color: onSurfaceSecondary, fontSize: 12)),
                const Spacer(),
                Text(
                  'aralığın %${(weekPos * 100).toStringAsFixed(0)} noktasında',
                  style:
                      TextStyle(color: onSurfaceSecondary, fontSize: 12),
                ),
              ]),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: weekPos.clamp(0.0, 1.0),
                  minHeight: 6,
                  backgroundColor: onSurface.withOpacity(0.12),
                  valueColor: const AlwaysStoppedAnimation(Color(0xFF34C759)),
                ),
              ),
              const SizedBox(height: 4),
              Row(children: [
                Text(asset.low52w.toStringAsFixed(2),
                    style: TextStyle(
                        color: onSurfaceSecondary, fontSize: 11)),
                const Spacer(),
                Text(asset.high52w.toStringAsFixed(2),
                    style: TextStyle(
                        color: onSurfaceSecondary, fontSize: 11)),
              ]),
              if (asset.fk > 0 || asset.pdDd > 0) ...[
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 10),
                Row(children: [
                  if (asset.fk > 0) ...[
                    _TemelBadge(label: 'F/K', value: asset.fk.toStringAsFixed(1)),
                    const SizedBox(width: 10),
                  ],
                  if (asset.pdDd > 0)
                    _TemelBadge(label: 'PD/DD', value: asset.pdDd.toStringAsFixed(2)),
                  const Spacer(),
                  if (asset.dailyTurnover > 0)
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text('Günlük hacim',
                          style: TextStyle(
                              color: onSurfaceSecondary, fontSize: 10)),
                      Text(
                        _formatHacim(asset.dailyTurnover),
                        style: TextStyle(
                            color: onSurface,
                            fontSize: 13,
                            fontWeight: FontWeight.bold),
                      ),
                    ]),
                ]),
              ],
            ],
          ),
        ),

        // ── Uyarı ────────────────────────────────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.orange.withOpacity(0.25)),
          ),
          child: Row(children: [
            const Icon(Icons.info_outline, color: Colors.orange, size: 15),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Teknik analiz geçmiş veriye dayanır, geleceği garanti etmez. Yatırım tavsiyesi değildir.',
                style: TextStyle(
                    color: Colors.orange.shade300, fontSize: 11, height: 1.5),
              ),
            ),
          ]),
        ),

        const SizedBox(height: 24),
      ],
    );
  }

  Color _rsiColor(double rsi) {
    if (rsi >= 70) return const Color(0xFFFF3B30);
    if (rsi >= 60) return const Color(0xFF34C759);
    if (rsi >= 45) return Colors.orange;
    if (rsi >= 30) return const Color(0xFFFF9500);
    return const Color(0xFFFF3B30);
  }

  String _formatHacim(double v) {
    if (v >= 1e9) return '${(v / 1e9).toStringAsFixed(1)} Mr ₺';
    if (v >= 1e6) return '${(v / 1e6).toStringAsFixed(1)} Mn ₺';
    return '${v.toStringAsFixed(0)} ₺';
  }
}

// ── AI Loading Row ───────────────────────────────────────────────────────────

class _AiLoadingRow extends StatelessWidget {
  const _AiLoadingRow();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 1.8,
              valueColor: AlwaysStoppedAnimation(
                const Color(0xFF7C3AED).withOpacity(0.85),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Yapay zeka analiz ediyor...',
            style: TextStyle(
              color: onSurface.withOpacity(0.55),
              fontSize: 13,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Analiz Rozeti Satırı (✦ AI Analiz / ✦ Teknik Analiz) ──────────────────────

class _AnalizBadgeRow extends StatelessWidget {
  final bool isAi;
  final VoidCallback onRefresh;
  const _AnalizBadgeRow({required this.isAi, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final label = isAi ? 'AI Analiz' : 'Teknik Analiz';

    return Row(
      children: [
        // ✦ AI Analiz veya Teknik Analiz rozeti — aynı degrade ve tasarım
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF7C3AED), Color(0xFF2563EB)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7C3AED).withOpacity(isDark ? 0.45 : 0.25),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('✦', style: TextStyle(color: Colors.white, fontSize: 10)),
              const SizedBox(width: 5),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        // Yenile butonu
        GestureDetector(
          onTap: onRefresh,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withOpacity(0.07),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: theme.colorScheme.onSurface.withOpacity(0.12),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.refresh_rounded,
                  size: 12,
                  color: theme.colorScheme.onSurface.withOpacity(0.55),
                ),
                const SizedBox(width: 4),
                Text(
                  'Yenile',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withOpacity(0.55),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Teknik Kart ─────────────────────────────────────────────────────────────

class _TeknikKart extends StatelessWidget {
  final String header;
  final String? badge;
  final IconData? trailingIcon;
  final Color? trailingIconColor;
  final Widget child;
  final Color shadow;
  final bool isAi;

  const _TeknikKart({
    required this.header,
    required this.child,
    required this.shadow,
    this.badge,
    this.trailingIcon,
    this.trailingIconColor,
    this.isAi = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final onSurface = theme.colorScheme.onSurface;
    final onSurfaceSecondary = onSurface.withOpacity(0.5);

    // AI / Genel görünüm kartı için hafif mor glow border
    final border = isAi
        ? Border.all(
            color: const Color(0xFF7C3AED).withOpacity(isDark ? 0.35 : 0.18),
            width: 1,
          )
        : null;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: border,
        boxShadow: [
          BoxShadow(color: shadow, blurRadius: 6),
          if (isAi)
            BoxShadow(
              color: const Color(0xFF7C3AED).withOpacity(isDark ? 0.12 : 0.06),
              blurRadius: 16,
              spreadRadius: 1,
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(header,
                style: TextStyle(
                    color: onSurfaceSecondary,
                    fontSize: 11,
                    letterSpacing: 0.3)),
            const Spacer(),
            if (badge != null)
              Text(badge!,
                  style: TextStyle(
                      color: onSurfaceSecondary, fontSize: 11)),
            if (trailingIcon != null)
              Icon(trailingIcon,
                  color: trailingIconColor ?? onSurfaceSecondary, size: 16),
          ]),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

// ── Seviye Satırı (Destek/Direnç) ───────────────────────────────────────────

class _SeviyeRow extends StatelessWidget {
  final String label;
  final double value;
  final double currentPrice;
  final bool isResistance;
  final Color onSurface;
  final Color onSurfaceSecondary;

  const _SeviyeRow({
    required this.label,
    required this.value,
    required this.currentPrice,
    required this.isResistance,
    required this.onSurface,
    required this.onSurfaceSecondary,
  });

  @override
  Widget build(BuildContext context) {
    final pct = (value - currentPrice) / currentPrice * 100;
    final color =
        isResistance ? const Color(0xFFFF3B30) : const Color(0xFF34C759);
    final pctStr =
        '${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(1)}%';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 32,
            decoration: BoxDecoration(
              color: color.withOpacity(0.7),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: TextStyle(color: onSurfaceSecondary, fontSize: 11)),
            Row(children: [
              for (int i = 0; i < 4; i++)
                Container(
                  width: 5,
                  height: 5,
                  margin: const EdgeInsets.only(right: 2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withOpacity(i < 3 ? 0.7 : 0.25),
                  ),
                ),
            ]),
          ]),
          const Spacer(),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            RichText(
              text: TextSpan(
                style: TextStyle(
                    color: onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
                children: [
                  TextSpan(text: value.toStringAsFixed(0)),
                  TextSpan(
                    text: ',${(value % 1 * 100).toStringAsFixed(0).padLeft(2, '0')}',
                    style: TextStyle(
                        color: onSurface.withOpacity(0.45),
                        fontSize: 13),
                  ),
                ],
              ),
            ),
            Text(pctStr,
                style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w500)),
          ]),
        ],
      ),
    );
  }
}

// ── Artı/Eksi Satır ──────────────────────────────────────────────────────────

class _BulletRow extends StatelessWidget {
  final String text;
  final String icon;
  final Color color;

  const _BulletRow(
      {required this.text, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 20,
          child: Text(icon,
              style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.bold)),
        ),
        Expanded(
          child: Text(text,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.85),
                  fontSize: 13,
                  height: 1.4)),
        ),
      ]),
    );
  }
}

// ── Temel Badge ──────────────────────────────────────────────────────────────

class _TemelBadge extends StatelessWidget {
  final String label;
  final String value;
  const _TemelBadge({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface.withOpacity(0.07),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text('$label ',
            style: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.55),
                fontSize: 11)),
        Text(value,
            style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 12,
                fontWeight: FontWeight.bold)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

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
