import 'package:flutter/material.dart';
import '../models/asset_model.dart';
import '../services/stock_service.dart';
import 'portfolio_screen.dart';
import 'watchlist_screen.dart';
import '../main.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _marketTab = 0;
  List<AssetModel> _marketList = [];
  List<AssetModel> _quickPrices = [];
  AssetModel? _bist100, _bist30, _goldGram, _silverGram, _dollar, _euro;
  bool _loadingMarket = false;
  bool _loadingQuick = false;
  final TextEditingController _searchCtrl = TextEditingController();
  List<Map<String, String>> _searchResults = [];

  final List<String> _selectedItems = ['bist100', 'bist30', 'goldgram', 'THYAO', 'GARAN'];

  // Tüm BIST hisselerini çekmek yerine ilk 100'ü kullan (performans)
  static final List<String> _topSymbols =
      kBistStocks.take(100).map((e) => e['symbol']!).toList();

  // Yüklenen tüm piyasa verisi (filtreleme için saklanır)
  List<AssetModel> _allMarketAssets = [];

  @override
  void initState() {
    super.initState();
    _loadQuickPrices();
    _loadMarketList();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  static const List<String> _specialIds = [
    'bist100', 'bist30', 'goldgram', 'silvergram', 'dollar', 'euro'
  ];

  Future<void> _loadQuickPrices() async {
    setState(() => _loadingQuick = true);
    final needB100  = _selectedItems.contains('bist100');
    final needB30   = _selectedItems.contains('bist30');
    final needGold  = _selectedItems.contains('goldgram');
    final needSilv  = _selectedItems.contains('silvergram');
    final needDollar= _selectedItems.contains('dollar');
    final needEuro  = _selectedItems.contains('euro');
    final stocks    = _selectedItems.where((s) => !_specialIds.contains(s)).toList();

    final futures = <Future>[
      if (needB100)   StockService.fetchIndex('XU100.IS', 'BIST 100', 'BIST 100'),
      if (needB30)    StockService.fetchIndex('XU030.IS', 'BIST 30', 'BIST 30'),
      if (needGold)   StockService.fetchGoldGram(),
      if (needSilv)   StockService.fetchSilverGram(),
      if (needDollar) StockService.fetchDollar(),
      if (needEuro)   StockService.fetchEuro(),
      ...stocks.map((s) => StockService.fetchStock(s, period: '5d')),
    ];
    final results = await Future.wait(futures);
    if (!mounted) return;

    int idx = 0;
    AssetModel? b100, b30, gold, silv, dollar, euro;
    final hisseler = <AssetModel>[];
    if (needB100)   b100   = results[idx++] as AssetModel?;
    if (needB30)    b30    = results[idx++] as AssetModel?;
    if (needGold)   gold   = results[idx++] as AssetModel?;
    if (needSilv)   silv   = results[idx++] as AssetModel?;
    if (needDollar) dollar = results[idx++] as AssetModel?;
    if (needEuro)   euro   = results[idx++] as AssetModel?;
    for (int i = idx; i < results.length; i++) {
      final a = results[i] as AssetModel?;
      if (a != null) hisseler.add(a);
    }
    setState(() {
      _bist100 = b100; _bist30 = b30; _goldGram = gold;
      _silverGram = silv; _dollar = dollar; _euro = euro;
      _quickPrices = hisseler; _loadingQuick = false;
    });
  }

  Future<void> _loadMarketList() async {
    setState(() { _loadingMarket = true; _marketList = []; });
    final assets = await StockService.fetchMultiple(_topSymbols, period: '5d');
    if (!mounted) return;
    _allMarketAssets = assets;
    _applyMarketFilter();
  }

  void _applyMarketFilter() {
    if (!mounted) return;
    List<AssetModel> filtered;
    switch (_marketTab) {
      case 0:
        // En Çok Artan: değişim >= +10%, hacme göre büyükten küçüğe, ilk 10
        filtered = _allMarketAssets
            .where((a) => a.changePercent >= 10.0)
            .toList()
          ..sort((a, b) => b.avgVolume.compareTo(a.avgVolume));
        filtered = filtered.take(10).toList();
        // 10'dan az varsa eşiği düşür
        if (filtered.isEmpty) {
          filtered = [..._allMarketAssets]
            ..sort((a, b) => b.changePercent.compareTo(a.changePercent));
          filtered = filtered.take(10).toList();
        }
        break;
      case 1:
        // En Çok Azalan: değişim <= -10%, hacme göre büyükten küçüğe, ilk 10
        filtered = _allMarketAssets
            .where((a) => a.changePercent <= -10.0)
            .toList()
          ..sort((a, b) => b.avgVolume.compareTo(a.avgVolume));
        filtered = filtered.take(10).toList();
        if (filtered.isEmpty) {
          filtered = [..._allMarketAssets]
            ..sort((a, b) => a.changePercent.compareTo(b.changePercent));
          filtered = filtered.take(10).toList();
        }
        break;
      default:
        // Hacim liderleri
        filtered = [..._allMarketAssets]
          ..sort((a, b) => b.avgVolume.compareTo(a.avgVolume));
        filtered = filtered.take(10).toList();
    }
    setState(() { _marketList = filtered; _loadingMarket = false; });
  }

  void _onSearch(String val) {
    if (val.isEmpty) { setState(() => _searchResults = []); return; }
    final q = val.trim().toUpperCase();
    setState(() {
      if (q.length == 1) {
        // Tek harf: sembol VEYA isim o harfle BAŞLAMALI
        _searchResults = kBistStocks.where((s) =>
            s['symbol']!.startsWith(q) ||
            s['name']!.toUpperCase().startsWith(q)
        ).take(10).toList();
      } else {
        // 2+ harf: sembolü q ile başlayanlar önce, sonra isim içinde geçenler
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

  void _onSelectStock(String symbol, String name) {
    _searchCtrl.clear();
    setState(() => _searchResults = []);
    _navigateToAnaliz(symbol, name);
  }

  void _navigateToAnaliz(String symbol, String name) {
    // Alt navbar görünür kalması için MainNavigation üzerinden Analiz sekmesine geçiş
    MainNavigation.goToAnaliz(symbol, name);
  }

  List<Widget> _buildPriceCards() {
    final cards = <Widget>[];
    bool first = true;
    void add(Widget w) {
      if (!first) cards.add(const SizedBox(width: 10));
      cards.add(w); first = false;
    }
    String chg(AssetModel a) =>
        '${a.changePercent >= 0 ? '+' : ''}${a.changePercent.toStringAsFixed(2)}%';

    for (final id in _selectedItems) {
      switch (id) {
        case 'bist100':
          if (_bist100 != null) { add(_IndexCard(symbol: 'BIST 100',
              value: _bist100!.price.toStringAsFixed(2), change: chg(_bist100!),
              isPos: _bist100!.changePercent >= 0, badge: 'B100', badgeColor: const Color(0xFF0066CC))); }
        case 'bist30':
          if (_bist30 != null) { add(_IndexCard(symbol: 'BIST 30',
              value: _bist30!.price.toStringAsFixed(2), change: chg(_bist30!),
              isPos: _bist30!.changePercent >= 0, badge: 'B30', badgeColor: const Color(0xFF0066CC))); }
        case 'goldgram':
          if (_goldGram != null) { add(_IndexCard(symbol: 'Gram Altın',
              value: '${_goldGram!.price.toStringAsFixed(2)} ₺', change: chg(_goldGram!),
              isPos: _goldGram!.changePercent >= 0, badge: 'AU', badgeColor: const Color(0xFFD4AF37))); }
        case 'silvergram':
          if (_silverGram != null) { add(_IndexCard(symbol: 'Gram Gümüş',
              value: '${_silverGram!.price.toStringAsFixed(2)} ₺', change: chg(_silverGram!),
              isPos: _silverGram!.changePercent >= 0, badge: 'AG', badgeColor: const Color(0xFF9E9E9E))); }
        case 'dollar':
          if (_dollar != null) { add(_IndexCard(symbol: 'Dolar/TL',
              value: _dollar!.price.toStringAsFixed(4), change: chg(_dollar!),
              isPos: _dollar!.changePercent >= 0, badge: r'$', badgeColor: const Color(0xFF2E7D32))); }
        case 'euro':
          if (_euro != null) { add(_IndexCard(symbol: 'Euro/TL',
              value: _euro!.price.toStringAsFixed(4), change: chg(_euro!),
              isPos: _euro!.changePercent >= 0, badge: '€', badgeColor: const Color(0xFF1565C0))); }
        default:
          final a = _quickPrices.where((x) => x.symbol == id).firstOrNull;
          if (a != null) { add(_StockQuickCard(asset: a)); }
      }
    }
    return cards;
  }

  void _showEditSheet() {
    final fixedOptions = [
      {'id': 'bist100',    'label': 'BIST 100',  'icon': 'B100'},
      {'id': 'bist30',     'label': 'BIST 30',   'icon': 'B30'},
      {'id': 'goldgram',   'label': 'Gram Altın', 'icon': 'AU'},
      {'id': 'silvergram', 'label': 'Gram Gümüş', 'icon': 'AG'},
      {'id': 'dollar',     'label': 'Dolar/TL',  'icon': r'$'},
      {'id': 'euro',       'label': 'Euro/TL',   'icon': '€'},
    ];
    final bistOptions = kBistStocks.take(30).toList();

    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => DraggableScrollableSheet(
          expand: false, initialChildSize: 0.65, maxChildSize: 0.9,
          builder: (_, ctrl) => Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Anlık Fiyatları Düzenle',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text('Görmek istediğiniz varlıkları seçin',
                  style: TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 14),
              const Text('Endeks & Döviz & Emtia',
                  style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: fixedOptions.map((opt) {
                  final sel = _selectedItems.contains(opt['id']);
                  return GestureDetector(
                    onTap: () {
                      setSheet(() {
                        if (sel) { _selectedItems.remove(opt['id']); }
                        else { _selectedItems.add(opt['id']!); }
                      });
                      setState(() {});
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: sel ? const Color(0xFF34C759) : const Color(0xFFF2F2F7),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: sel ? const Color(0xFF34C759) : Colors.grey.shade300),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(opt['icon']!, style: TextStyle(
                            color: sel ? Colors.white : Colors.black54,
                            fontWeight: FontWeight.bold, fontSize: 11)),
                        const SizedBox(width: 5),
                        Text(opt['label']!, style: TextStyle(
                            color: sel ? Colors.white : Colors.black87,
                            fontSize: 12,
                            fontWeight: sel ? FontWeight.bold : FontWeight.normal)),
                      ]),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              const Text('BIST Hisseleri',
                  style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  controller: ctrl,
                  itemCount: bistOptions.length,
                  itemBuilder: (_, i) {
                    final s = bistOptions[i];
                    final sel = _selectedItems.contains(s['symbol']);
                    return ListTile(
                      dense: true, contentPadding: EdgeInsets.zero,
                      leading: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF34C759).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(s['symbol']!, style: const TextStyle(
                            color: Color(0xFF34C759), fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                      title: Text(s['name']!, style: const TextStyle(fontSize: 13)),
                      trailing: Checkbox(
                        value: sel, activeColor: const Color(0xFF34C759),
                        onChanged: (_) {
                          setSheet(() {
                            if (sel) { _selectedItems.remove(s['symbol']); }
                            else { _selectedItems.add(s['symbol']!); }
                          });
                          setState(() {});
                        },
                      ),
                      onTap: () {
                        setSheet(() {
                          if (sel) { _selectedItems.remove(s['symbol']); }
                          else { _selectedItems.add(s['symbol']!); }
                        });
                        setState(() {});
                      },
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () { Navigator.pop(ctx); _loadQuickPrices(); },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF34C759), foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Uygula', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: SafeArea(
        child: RefreshIndicator(
          color: const Color(0xFF34C759),
          onRefresh: () async { await _loadQuickPrices(); await _loadMarketList(); },
          child: CustomScrollView(slivers: [

            // Başlık
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(children: [
                const Text('Anasayfa', style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF34C759))),
                const Spacer(),
                IconButton(icon: const Icon(Icons.notifications_outlined, color: Colors.black54),
                    onPressed: () {}),
              ]),
            )),

            // Arama
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(children: [
                TextField(
                  controller: _searchCtrl, onChanged: _onSearch,
                  decoration: InputDecoration(
                    hintText: 'Hisse Ara...', hintStyle: const TextStyle(color: Colors.grey),
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    filled: true, fillColor: Colors.white,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
                if (_searchResults.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8)]),
                    child: Column(
                      children: _searchResults.map((s) => ListTile(
                        dense: true,
                        leading: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                              color: const Color(0xFF34C759).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6)),
                          child: Text(s['symbol']!, style: const TextStyle(
                              color: Color(0xFF34C759), fontWeight: FontWeight.bold, fontSize: 11)),
                        ),
                        title: Text(s['name']!, style: const TextStyle(fontSize: 13)),
                        trailing: const Icon(Icons.bar_chart, color: Color(0xFF34C759), size: 18),
                        onTap: () => _onSelectStock(s['symbol']!, s['name']!),
                      )).toList(),
                    ),
                  ),
              ]),
            )),

            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // Portföy / Takip / Robo
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                _QuickCard(label: 'Portföyüm', icon: Icons.receipt_long_outlined,
                    color: const Color(0xFF34C759),
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const PortfolioScreen()))),
                const SizedBox(width: 10),
                _QuickCard(label: 'Takip Listesi', icon: Icons.remove_red_eye_outlined,
                    color: const Color(0xFF2DB84B),
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const WatchlistScreen()))),
                const SizedBox(width: 10),
                _QuickCard(label: 'Robo Asistan', icon: Icons.psychology_outlined,
                    color: Colors.white, textColor: const Color(0xFF34C759),
                    isPremium: true, onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Row(children: [
                            Icon(Icons.info_outline, color: Colors.white, size: 18),
                            SizedBox(width: 8),
                            Expanded(child: Text(
                              'Yakında bu özellik aktif edilecektir.',
                              style: TextStyle(color: Colors.white),
                            )),
                          ]),
                          backgroundColor: const Color(0xFF1C3A5E),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }),
              ]),
            )),

            const SliverToBoxAdapter(child: SizedBox(height: 20)),

            // Anlık Fiyatlar başlık + Düzenle
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                const Text('Anlık Fiyatlar', style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                const Spacer(),
                GestureDetector(
                  onTap: _showEditSheet,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF34C759).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(children: [
                      Icon(Icons.edit_outlined, size: 13, color: Color(0xFF34C759)),
                      SizedBox(width: 4),
                      Text('Düzenle', style: TextStyle(
                          color: Color(0xFF34C759), fontSize: 12, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
              ]),
            )),
            const SliverToBoxAdapter(child: SizedBox(height: 10)),

            // Fiyat kartları
            SliverToBoxAdapter(child: SizedBox(
              height: 120,
              child: _loadingQuick
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF34C759)))
                  : ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      scrollDirection: Axis.horizontal,
                      children: _buildPriceCards()),
            )),

            const SliverToBoxAdapter(child: SizedBox(height: 20)),

            // Piyasa tab
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                _TabChip(label: 'En Çok Artan', isActive: _marketTab == 0,
                    onTap: () { setState(() => _marketTab = 0); _applyMarketFilter(); }),
                const SizedBox(width: 8),
                _TabChip(label: 'En Çok Azalan', isActive: _marketTab == 1,
                    onTap: () { setState(() => _marketTab = 1); _applyMarketFilter(); }),
                const SizedBox(width: 8),
                _TabChip(label: 'Hacim Liderleri', isActive: _marketTab == 2,
                    onTap: () { setState(() => _marketTab = 2); _applyMarketFilter(); }),
              ]),
            )),

            const SliverToBoxAdapter(child: SizedBox(height: 10)),

            // Market listesi
            if (_loadingMarket)
              const SliverToBoxAdapter(child: Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator(color: Color(0xFF34C759))),
              ))
            else
              SliverList(delegate: SliverChildBuilderDelegate((_, i) {
                final a = _marketList[i];
                final isPos = a.changePercent >= 0;
                final chgColor = isPos ? const Color(0xFF34C759) : const Color(0xFFFF3B30);
                return GestureDetector(
                  onTap: () => MainNavigation.goToAnaliz(a.symbol, a.name),
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04), blurRadius: 5)],
                    ),
                    child: Row(children: [
                      // Sıra numarası
                      Container(
                        width: 28, height: 28,
                        decoration: BoxDecoration(
                          color: chgColor.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text('${i + 1}',
                              style: TextStyle(color: chgColor,
                                  fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Sembol + isim
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(a.symbol, style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87)),
                          Text(a.name, style: const TextStyle(color: Colors.grey, fontSize: 11),
                              overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 2),
                          Text('Hacim: ${_fmtVol(a.avgVolume)}',
                              style: const TextStyle(color: Colors.grey, fontSize: 11)),
                        ],
                      )),
                      // Fiyat + değişim rozeti
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text('${a.price.toStringAsFixed(2)} ₺',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87)),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: chgColor,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${isPos ? '+' : ''}${a.changePercent.toStringAsFixed(2)}%',
                            style: const TextStyle(color: Colors.white,
                                fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                      ]),
                      const SizedBox(width: 6),
                      Icon(Icons.chevron_right, color: Colors.grey[300], size: 18),
                    ]),
                  ),
                );
              }, childCount: _marketList.length)),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ]),
        ),
      ),
    );
  }

  String _fmtVol(double v) {
    if (v >= 1e9) return '${(v / 1e9).toStringAsFixed(1)}B';
    if (v >= 1e6) return '${(v / 1e6).toStringAsFixed(1)}M';
    if (v >= 1e3) return '${(v / 1e3).toStringAsFixed(1)}k';
    return v.toStringAsFixed(0);
  }
}

class _QuickCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Color? textColor;
  final bool isPremium;
  final VoidCallback onTap;
  const _QuickCard({required this.label, required this.icon, required this.color,
      this.textColor, this.isPremium = false, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isWhite = color == Colors.white;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 90, padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color, borderRadius: BorderRadius.circular(14),
            border: isWhite ? Border.all(color: const Color(0xFF34C759).withValues(alpha: 0.3)) : null,
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6, offset: const Offset(0, 2))],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, color: isWhite ? const Color(0xFF34C759) : Colors.white, size: 22),
            const Spacer(),
            Text(label, style: TextStyle(
                color: isWhite ? const Color(0xFF34C759) : Colors.white,
                fontWeight: FontWeight.bold, fontSize: 12)),
            if (isPremium)
              Container(
                margin: const EdgeInsets.only(top: 2),
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(color: const Color(0xFF34C759), borderRadius: BorderRadius.circular(4)),
                child: const Text('PREMIUM', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
              ),
          ]),
        ),
      ),
    );
  }
}

class _IndexCard extends StatelessWidget {
  final String symbol, value, change, badge;
  final bool isPos;
  final Color badgeColor;
  const _IndexCard({required this.symbol, required this.value, required this.change,
      required this.isPos, required this.badge, required this.badgeColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120, padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(color: badgeColor, shape: BoxShape.circle),
          child: Center(child: Text(badge, style: const TextStyle(
              color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold))),
        ),
        const SizedBox(height: 6),
        Text(symbol, style: const TextStyle(color: Colors.grey, fontSize: 11), overflow: TextOverflow.ellipsis),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(
            color: isPos ? const Color(0xFF34C759) : const Color(0xFFFF3B30),
            fontWeight: FontWeight.bold, fontSize: 12), overflow: TextOverflow.ellipsis),
        Text(change, style: TextStyle(
            color: isPos ? const Color(0xFF34C759) : const Color(0xFFFF3B30), fontSize: 11)),
      ]),
    );
  }
}

class _StockQuickCard extends StatelessWidget {
  final AssetModel asset;
  const _StockQuickCard({required this.asset});

  @override
  Widget build(BuildContext context) {
    final isPos = asset.changePercent >= 0;
    final shortSym = asset.symbol.length > 4 ? asset.symbol.substring(0, 4) : asset.symbol;
    return Container(
      width: 120, padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
              color: isPos ? const Color(0xFF34C759) : const Color(0xFFFF3B30), shape: BoxShape.circle),
          child: Center(child: Text(shortSym, style: const TextStyle(
              color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold))),
        ),
        const SizedBox(height: 6),
        Text(asset.symbol, style: const TextStyle(color: Colors.grey, fontSize: 11), overflow: TextOverflow.ellipsis),
        const SizedBox(height: 2),
        Text(asset.price.toStringAsFixed(2), style: TextStyle(
            color: isPos ? const Color(0xFF34C759) : const Color(0xFFFF3B30),
            fontWeight: FontWeight.bold, fontSize: 12), overflow: TextOverflow.ellipsis),
        Text('${isPos ? '+' : ''}${asset.changePercent.toStringAsFixed(2)}%', style: TextStyle(
            color: isPos ? const Color(0xFF34C759) : const Color(0xFFFF3B30), fontSize: 11)),
      ]),
    );
  }
}

class _TabChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  const _TabChip({required this.label, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF34C759) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)],
        ),
        child: Text(label, style: TextStyle(
            color: isActive ? Colors.white : Colors.black54,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal, fontSize: 13)),
      ),
    );
  }
}
