import 'dart:async';
import 'package:flutter/material.dart';
import '../models/asset_model.dart';
import '../services/portfolio_service.dart';
import '../services/stock_service.dart';
import 'portfolio_screen.dart';
import 'watchlist_screen.dart';
import 'notifications_screen.dart';
import '../widgets/stock_quote_panel.dart';
import '../main.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _marketTab = 0;
  int _homeSection = 0; // 0 = Favori Listeleri, 1 = Hisseler
  int _homePanel = 0; // Takip 1 / Takip 2
  List<AssetModel> _marketList = [];
  List<AssetModel> _quickPrices = [];
  AssetModel? _bist100,
      _bist30,
      _goldGram,
      _silverTl,
      _palladiumTl,
      _platinumTl,
      _dollar,
      _euro;
  bool _loadingMarket = false;
  bool _loadingQuick = false;
  StreamSubscription? _favoriteListSubscription;
  final TextEditingController _searchCtrl = TextEditingController();
  List<Map<String, String>> _searchResults = [];

  static const List<String> _defaultFavoriteListA = [
    'THYAO',
    'GARAN',
    'AKBNK',
    'SISE',
    'ARCLK',
  ];
  static const List<String> _defaultFavoriteListB = [
    'ISCTR',
    'ASELS',
    'ORTAK',
    'KRDMD',
    'YKBNK',
  ];

  final List<String> _selectedItems = [
    'bist100',
    'bist30',
    'goldgram',
    'silvertl',
    'palladiumtl',
    'platinumtl',
    'dollar',
    'euro',
  ];
  final List<String> _favoriteListA = List<String>.from(_defaultFavoriteListA);
  final List<String> _favoriteListB = List<String>.from(_defaultFavoriteListB);

  // Hisse fiyat verisi cache
  final Map<String, AssetModel> _stockPriceCache = {};

  // Anasayfa piyasa listesinde tüm hisseleri baz al
  static final List<String> _topSymbols = kBistStocks
      .map((e) => e['symbol']!)
      .toList();

  // Yüklenen tüm piyasa verisi (filtreleme için saklanır)
  List<AssetModel> _allMarketAssets = [];

  @override
  void initState() {
    super.initState();
    _favoriteListSubscription = PortfolioService.favoriteBox.watch().listen((
      event,
    ) {
      if (!mounted) return;
      if (event.key == 'listA' || event.key == 'listB') {
        _loadFavoriteLists(event.key as String);
        _loadFavoritePrices();
      }
    });
    _loadFavoriteLists();
    _loadQuickPrices();
    _loadMarketList();
    _loadFavoritePrices();
  }

  void _loadFavoriteLists([String? key]) {
    final savedA = PortfolioService.getFavoriteList('listA');
    final savedB = PortfolioService.getFavoriteList('listB');

    setState(() {
      if (key == null || key == 'listA') {
        _favoriteListA
          ..clear()
          ..addAll(savedA);
      }
      if (key == null || key == 'listB') {
        _favoriteListB
          ..clear()
          ..addAll(savedB);
      }
    });
  }

  Future<void> _saveFavoriteLists() async {
    await PortfolioService.saveFavoriteLists(_favoriteListA, _favoriteListB);
  }

  Future<void> _loadFavoritePrices({List<String>? symbols}) async {
    final allFavs = (symbols ?? [..._favoriteListA, ..._favoriteListB])
        .where((s) => s.trim().isNotEmpty)
        .toSet()
        .toList();
    if (allFavs.isEmpty) return;

    final results = await StockService.fetchMultiple(allFavs, period: '5d');
    if (!mounted) return;

    setState(() {
      for (final asset in results) {
        _stockPriceCache[asset.symbol] = asset;
      }
    });
  }

  @override
  void dispose() {
    _favoriteListSubscription?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  static const List<String> _specialIds = [
    'bist100',
    'bist30',
    'goldgram',
    'silvertl',
    'palladiumtl',
    'platinumtl',
    'dollar',
    'euro',
  ];

  Future<void> _loadQuickPrices() async {
    setState(() => _loadingQuick = true);
    final needB100 = _selectedItems.contains('bist100');
    final needB30 = _selectedItems.contains('bist30');
    final needGold = _selectedItems.contains('goldgram');
    final needSilver = _selectedItems.contains('silvertl');
    final needPalladium = _selectedItems.contains('palladiumtl');
    final needPlatinum = _selectedItems.contains('platinumtl');
    final needDollar = _selectedItems.contains('dollar');
    final needEuro = _selectedItems.contains('euro');
    final stocks = _selectedItems
        .where((s) => !_specialIds.contains(s))
        .toList();

    final futures = <Future>[
      if (needB100) StockService.fetchIndex('XU100.IS', 'BIST 100', 'BIST 100'),
      if (needB30) StockService.fetchIndex('XU030.IS', 'BIST 30', 'BIST 30'),
      if (needGold) StockService.fetchGoldGram(),
      if (needSilver) StockService.fetchSilverTl(),
      if (needPalladium) StockService.fetchPalladiumTl(),
      if (needPlatinum) StockService.fetchPlatinumTl(),
      if (needDollar) StockService.fetchDollar(),
      if (needEuro) StockService.fetchEuro(),
      ...stocks.map((s) => StockService.fetchStock(s, period: '5d')),
    ];
    final results = await Future.wait(futures);
    if (!mounted) return;

    int idx = 0;
    AssetModel? b100, b30, gold, silver, palladium, platinum, dollar, euro;
    final hisseler = <AssetModel>[];
    if (needB100) b100 = results[idx++] as AssetModel?;
    if (needB30) b30 = results[idx++] as AssetModel?;
    if (needGold) gold = results[idx++] as AssetModel?;
    if (needSilver) silver = results[idx++] as AssetModel?;
    if (needPalladium) palladium = results[idx++] as AssetModel?;
    if (needPlatinum) platinum = results[idx++] as AssetModel?;
    if (needDollar) dollar = results[idx++] as AssetModel?;
    if (needEuro) euro = results[idx++] as AssetModel?;
    for (int i = idx; i < results.length; i++) {
      final a = results[i] as AssetModel?;
      if (a != null) hisseler.add(a);
    }
    setState(() {
      _bist100 = b100;
      _bist30 = b30;
      _goldGram = gold;
      _silverTl = silver;
      _palladiumTl = palladium;
      _platinumTl = platinum;
      _dollar = dollar;
      _euro = euro;
      _quickPrices = hisseler;
      _loadingQuick = false;
    });
  }

  Future<void> _loadMarketList() async {
    setState(() {
      _loadingMarket = true;
      _marketList = [];
    });
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
        // En Çok Artan: önce yüzde artışı grubu, sonra aynı gruptaki hacim sıralaması
        filtered =
            _allMarketAssets
                .where((a) => a.changePercent > 0 && a.changePercent <= 10.0)
                .toList()
              ..sort((a, b) {
                final changeCmp = b.changePercent.compareTo(a.changePercent);
                if (changeCmp != 0) return changeCmp;
                return b.avgVolume.compareTo(a.avgVolume);
              });
        filtered = filtered.take(10).toList();
        break;
      case 1:
        // En Çok Azalan: önce daha düşük yüzde (örneğin -10%)
        // sonra aynı yüzdeli hisseleri hacmi yüksekten düşüğe sıralar.
        filtered =
            _allMarketAssets
                .where((a) => a.changePercent < 0 && a.changePercent >= -10.0)
                .toList()
              ..sort((a, b) {
                final changeCmp = a.changePercent.compareTo(b.changePercent);
                if (changeCmp != 0) return changeCmp;
                return b.avgVolume.compareTo(a.avgVolume);
              });
        filtered = filtered.take(10).toList();
        break;
      default:
        // Hacim liderleri
        filtered = [..._allMarketAssets]
          ..sort((a, b) => b.avgVolume.compareTo(a.avgVolume));
        filtered = filtered.take(10).toList();
    }
    setState(() {
      _marketList = filtered;
      _loadingMarket = false;
    });
  }

  void _onSearch(String val) {
    if (val.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    final q = val.trim().toUpperCase();
    setState(() {
      if (q.length == 1) {
        // Tek harf: sembol VEYA isim o harfle BAŞLAMALI
        _searchResults = kBistStocks
            .where(
              (s) =>
                  s['symbol']!.startsWith(q) ||
                  s['name']!.toUpperCase().startsWith(q),
            )
            .take(10)
            .toList();
      } else {
        // 2+ harf: sembolü q ile başlayanlar önce, sonra isim içinde geçenler
        final bySymbol = kBistStocks
            .where((s) => s['symbol']!.startsWith(q))
            .toList();
        final byName = kBistStocks
            .where(
              (s) =>
                  !s['symbol']!.startsWith(q) &&
                  s['name']!.toUpperCase().contains(q),
            )
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
      if (!first) cards.add(const SizedBox(width: 8));
      cards.add(w);
      first = false;
    }

    for (final id in _selectedItems) {
      switch (id) {
        case 'bist100':
          if (_bist100 != null) {
            add(
              _QuoteQuickCard(
                asset: _bist100!,
                title: 'BIST 100',
                priceText: _bist100!.price.toStringAsFixed(2),
                digits: 2,
                badge: 'B100',
                badgeColor: const Color(0xFF0066CC),
              ),
            );
          }
          break;
        case 'bist30':
          if (_bist30 != null) {
            add(
              _QuoteQuickCard(
                asset: _bist30!,
                title: 'BIST 30',
                priceText: _bist30!.price.toStringAsFixed(2),
                digits: 2,
                badge: 'B30',
                badgeColor: const Color(0xFF0066CC),
              ),
            );
          }
          break;
        case 'goldgram':
          if (_goldGram != null) {
            add(
              _QuoteQuickCard(
                asset: _goldGram!,
                title: 'Gram Altın',
                priceText: '${_goldGram!.price.toStringAsFixed(2)} ₺',
                digits: 2,
                badge: 'AU',
                badgeColor: const Color(0xFFD4AF37),
              ),
            );
          }
          break;
        case 'silvertl':
          if (_silverTl != null) {
            add(
              _QuoteQuickCard(
                asset: _silverTl!,
                title: 'Gümüş/TL',
                priceText: '${_silverTl!.price.toStringAsFixed(2)} ₺',
                digits: 2,
                badge: 'AG',
                badgeColor: const Color(0xFF8E9AAF),
              ),
            );
          }
          break;
        case 'palladiumtl':
          if (_palladiumTl != null) {
            add(
              _QuoteQuickCard(
                asset: _palladiumTl!,
                title: 'Paladyum/TL',
                priceText: '${_palladiumTl!.price.toStringAsFixed(2)} ₺',
                digits: 2,
                badge: 'PD',
                badgeColor: const Color(0xFF6D6D72),
              ),
            );
          }
          break;
        case 'platinumtl':
          if (_platinumTl != null) {
            add(
              _QuoteQuickCard(
                asset: _platinumTl!,
                title: 'Platin/TL',
                priceText: '${_platinumTl!.price.toStringAsFixed(2)} ₺',
                digits: 2,
                badge: 'PT',
                badgeColor: const Color(0xFF607D8B),
              ),
            );
          }
          break;
        case 'dollar':
          if (_dollar != null) {
            add(
              _QuoteQuickCard(
                asset: _dollar!,
                title: 'Dolar/TL',
                priceText: _dollar!.price.toStringAsFixed(4),
                digits: 4,
                badge: r'$',
                badgeColor: const Color(0xFF2E7D32),
              ),
            );
          }
          break;
        case 'euro':
          if (_euro != null) {
            add(
              _QuoteQuickCard(
                asset: _euro!,
                title: 'Euro/TL',
                priceText: _euro!.price.toStringAsFixed(4),
                digits: 4,
                badge: '€',
                badgeColor: const Color(0xFF1565C0),
              ),
            );
          }
          break;
      }
    }
    return cards;
  }

  String _symbolName(String symbol) {
    final match = kBistStocks.firstWhere(
      (s) => s['symbol'] == symbol,
      orElse: () => {'name': symbol},
    );
    return match['name'] ?? symbol;
  }

  void _showAddFavoriteSheet(int listIndex) {
    final theme = Theme.of(context);
    final surface = theme.colorScheme.surface;
    final onSurfaceSecondary = theme.colorScheme.onSurface.withOpacity(0.65);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        String query = '';
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            final filtered = query.trim().isEmpty
                ? kBistStocks
                : (() {
                    final q = query.trim().toUpperCase();
                    final bySymbol = kBistStocks
                        .where((s) => s['symbol']!.startsWith(q))
                        .toList();
                    final byName = kBistStocks
                        .where(
                          (s) =>
                              !s['symbol']!.startsWith(q) &&
                              s['name']!.toUpperCase().contains(q),
                        )
                        .toList();
                    return [...bySymbol, ...byName];
                  })();

            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.7,
              maxChildSize: 0.9,
              builder: (_, ctrl) => Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Hisse Ekle',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Listeye eklemek istediğiniz hisseleri seçin.',
                      style: TextStyle(color: onSurfaceSecondary, fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      onChanged: (value) => setSheet(() => query = value),
                      decoration: InputDecoration(
                        hintText: 'Hisse ara...',
                        hintStyle: TextStyle(
                          color: onSurfaceSecondary,
                          fontSize: 13,
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: onSurfaceSecondary,
                          size: 18,
                        ),
                        filled: true,
                        fillColor: surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 10,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: ListView.builder(
                        controller: ctrl,
                        itemCount: filtered.length,
                        itemBuilder: (_, i) {
                          final row = filtered[i];
                          final symbol = row['symbol']!;
                          final items = listIndex == 0
                              ? _favoriteListA
                              : _favoriteListB;
                          final alreadyAdded = items.contains(symbol);
                          return ListTile(
                            dense: true,
                            title: Text(
                              row['name']!,
                              style: const TextStyle(fontSize: 13),
                            ),
                            subtitle: Text(
                              symbol,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                            trailing: alreadyAdded
                                ? const Icon(
                                    Icons.check_circle,
                                    color: Color(0xFF34C759),
                                  )
                                : Icon(
                                    Icons.add_circle_outline,
                                    color: onSurfaceSecondary,
                                  ),
                            onTap: () {
                              if (!alreadyAdded && items.length < 20) {
                                setState(() {
                                  if (listIndex == 0) {
                                    _favoriteListA.add(symbol);
                                  } else {
                                    _favoriteListB.add(symbol);
                                  }
                                });
                                _saveFavoriteLists();
                                _loadFavoritePrices(symbols: [symbol]);
                                Navigator.pop(ctx);
                              }
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showEditSheet() {
    final theme = Theme.of(context);
    final surface = theme.colorScheme.surface;
    final onSurfaceSecondary = theme.colorScheme.onSurface.withOpacity(0.65);
    final dividerColor = theme.dividerColor;

    final fixedOptions = [
      {'id': 'bist100', 'label': 'BIST 100', 'icon': 'B100'},
      {'id': 'bist30', 'label': 'BIST 30', 'icon': 'B30'},
      {'id': 'goldgram', 'label': 'Gram Altın', 'icon': 'AU'},
      {'id': 'silvertl', 'label': 'Gümüş/TL', 'icon': 'AG'},
      {'id': 'palladiumtl', 'label': 'Paladyum/TL', 'icon': 'PD'},
      {'id': 'platinumtl', 'label': 'Platin/TL', 'icon': 'PT'},
      {'id': 'dollar', 'label': 'Dolar/TL', 'icon': r'$'},
      {'id': 'euro', 'label': 'Euro/TL', 'icon': '€'},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.5,
            maxChildSize: 0.7,
            builder: (_, ctrl) => Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Anlık Fiyatları Düzenle',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Görmek istediğiniz varlıkları seçin.',
                    style: TextStyle(color: onSurfaceSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: fixedOptions.map((opt) {
                      final sel = _selectedItems.contains(opt['id']);
                      return GestureDetector(
                        onTap: () {
                          setSheet(() {
                            if (sel) {
                              _selectedItems.remove(opt['id']);
                            } else {
                              _selectedItems.add(opt['id']!);
                            }
                          });
                          setState(() {});
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: sel ? theme.colorScheme.primary : surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: sel
                                  ? theme.colorScheme.primary
                                  : dividerColor,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                opt['icon']!,
                                style: TextStyle(
                                  color: sel
                                      ? theme.colorScheme.onPrimary
                                      : onSurfaceSecondary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                opt['label']!,
                                style: TextStyle(
                                  color: sel
                                      ? theme.colorScheme.onPrimary
                                      : onSurfaceSecondary,
                                  fontSize: 12,
                                  fontWeight: sel
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _loadQuickPrices();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: theme.colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Uygula',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surface = theme.colorScheme.surface;
    final onSurface = theme.colorScheme.onSurface;
    final onSurfaceSecondary = theme.colorScheme.onSurface.withOpacity(0.72);
    final borderColor = theme.dividerColor;
    final shadowColor = theme.brightness == Brightness.light
        ? Colors.black.withOpacity(0.05)
        : Colors.white.withOpacity(0.05);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          color: const Color(0xFF34C759),
          onRefresh: () async {
            await _loadQuickPrices();
            await _loadMarketList();
          },
          child: CustomScrollView(
            slivers: [
              // Başlık
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    children: [
                      const Text(
                        'Anasayfa',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF34C759),
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AlarmScreen(),
                            ),
                          );
                          setState(() {});
                        },
                        icon: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            const Text('🔔', style: TextStyle(fontSize: 26)),
                            if (PortfolioService.getAlarmCount() > 0)
                              Positioned(
                                right: -2,
                                top: -2,
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFFF3B30),
                                    shape: BoxShape.circle,
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 16,
                                    minHeight: 16,
                                  ),
                                  child: Text(
                                    '${PortfolioService.getAlarmCount()}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Arama
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      TextField(
                        controller: _searchCtrl,
                        onChanged: _onSearch,
                        decoration: InputDecoration(
                          hintText: 'Hisse Ara...',
                          hintStyle: TextStyle(color: onSurfaceSecondary),
                          prefixIcon: Icon(
                            Icons.search,
                            color: onSurfaceSecondary,
                          ),
                          filled: true,
                          fillColor: surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 12,
                          ),
                        ),
                      ),
                      if (_searchResults.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          decoration: BoxDecoration(
                            color: surface,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(color: shadowColor, blurRadius: 8),
                            ],
                          ),
                          child: Column(
                            children: _searchResults
                                .map(
                                  (s) => ListTile(
                                    dense: true,
                                    leading: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFF34C759,
                                        ).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        s['symbol']!,
                                        style: const TextStyle(
                                          color: Color(0xFF34C759),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                    title: Text(
                                      s['name']!,
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                    trailing: const Icon(
                                      Icons.bar_chart,
                                      color: Color(0xFF34C759),
                                      size: 18,
                                    ),
                                    onTap: () => _onSelectStock(
                                      s['symbol']!,
                                      s['name']!,
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 16)),

              // Portföy / Takip
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: _QuickCard(
                          label: 'Portföyüm',
                          icon: Icons.receipt_long_outlined,
                          color: const Color(0xFF34C759),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const PortfolioScreen(),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _QuickCard(
                          label: 'Takip Listesi',
                          icon: Icons.remove_red_eye_outlined,
                          color: const Color(0xFF2DB84B),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const WatchlistScreen(),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 20)),

              // Anlık Fiyatlar başlık + Düzenle
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Text(
                        'Anlık Fiyatlar',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: _showEditSheet,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.edit_outlined,
                                size: 13,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Düzenle',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 10)),

              // Fiyat kartları
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 132,
                  child: _loadingQuick
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF34C759),
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          scrollDirection: Axis.horizontal,
                          children: _buildPriceCards(),
                        ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 16)),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: _PanelButton(
                          label: 'Favori Listeleri',
                          isActive: _homeSection == 0,
                          onTap: () => setState(() => _homeSection = 0),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _PanelButton(
                          label: 'Hisseler',
                          isActive: _homeSection == 1,
                          onTap: () => setState(() => _homeSection = 1),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 14)),

              if (_homeSection == 0) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        _PanelButton(
                          label: 'Takip 1',
                          isActive: _homePanel == 0,
                          onTap: () => setState(() => _homePanel = 0),
                        ),
                        const SizedBox(width: 10),
                        _PanelButton(
                          label: 'Takip 2',
                          isActive: _homePanel == 1,
                          onTap: () => setState(() => _homePanel = 1),
                        ),
                      ],
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 14)),
                if (_homePanel == 0)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _FavoriteListCard(
                        title: '',
                        list: _favoriteListA,
                        canAdd: _favoriteListA.length < 20,
                        onAdd: () => _showAddFavoriteSheet(0),
                        onRemove: (symbol) {
                          setState(() {
                            _favoriteListA.remove(symbol);
                          });
                          _saveFavoriteLists();
                          _loadFavoritePrices();
                        },
                        onSelectSymbol: (symbol, name) =>
                            MainNavigation.goToAnaliz(symbol, name),
                        onReorder: (oldIndex, newIndex) {
                          setState(() {
                            if (oldIndex < newIndex) newIndex -= 1;
                            final items = [..._favoriteListA];
                            final item = items.removeAt(oldIndex);
                            items.insert(newIndex, item);
                            _favoriteListA
                              ..clear()
                              ..addAll(items);
                          });
                          _saveFavoriteLists();
                          _loadFavoritePrices();
                        },
                        priceCache: _stockPriceCache,
                      ),
                    ),
                  )
                else
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _FavoriteListCard(
                        title: '',
                        list: _favoriteListB,
                        canAdd: _favoriteListB.length < 20,
                        onAdd: () => _showAddFavoriteSheet(1),
                        onRemove: (symbol) {
                          setState(() {
                            _favoriteListB.remove(symbol);
                          });
                          _saveFavoriteLists();
                          _loadFavoritePrices();
                        },
                        onSelectSymbol: (symbol, name) =>
                            MainNavigation.goToAnaliz(symbol, name),
                        onReorder: (oldIndex, newIndex) {
                          setState(() {
                            if (oldIndex < newIndex) newIndex -= 1;
                            final items = [..._favoriteListB];
                            final item = items.removeAt(oldIndex);
                            items.insert(newIndex, item);
                            _favoriteListB
                              ..clear()
                              ..addAll(items);
                          });
                          _saveFavoriteLists();
                          _loadFavoritePrices();
                        },
                        priceCache: _stockPriceCache,
                      ),
                    ),
                  ),
              ] else ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        _TabChip(
                          label: 'En Çok Artan',
                          isActive: _marketTab == 0,
                          onTap: () {
                            setState(() => _marketTab = 0);
                            _applyMarketFilter();
                          },
                        ),
                        const SizedBox(width: 6),
                        _TabChip(
                          label: 'En Çok Azalan',
                          isActive: _marketTab == 1,
                          onTap: () {
                            setState(() => _marketTab = 1);
                            _applyMarketFilter();
                          },
                        ),
                        const SizedBox(width: 6),
                        _TabChip(
                          label: 'Hacim Liderleri',
                          isActive: _marketTab == 2,
                          onTap: () {
                            setState(() => _marketTab = 2);
                            _applyMarketFilter();
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 10)),
                if (_loadingMarket)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  )
                else
                  SliverToBoxAdapter(
                    child: ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _marketList.length,
                      itemBuilder: (context, i) {
                        final theme = Theme.of(context);
                        final a = _marketList[i];
                        final isPos = a.changePercent >= 0;
                        final chgColor = isPos
                            ? theme.colorScheme.primary
                            : const Color(0xFFFF3B30);
                        return GestureDetector(
                          onTap: () =>
                              MainNavigation.goToAnaliz(a.symbol, a.name),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 20,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceVariant,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.12),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: theme.brightness == Brightness.light
                                        ? Colors.black.withOpacity(0.04)
                                        : Colors.white.withOpacity(0.02),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          a.symbol,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 20,
                                            color: onSurface,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          a.name,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: onSurfaceSecondary,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '${a.price.toStringAsFixed(2)} ₺',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                          color: onSurface,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        '${isPos ? '+' : ''}${a.changePercent.toStringAsFixed(2)}%',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 16,
                                          color: chgColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Color? textColor;
  final bool isPremium;
  final VoidCallback onTap;
  const _QuickCard({
    required this.label,
    required this.icon,
    required this.color,
    this.textColor,
    this.isPremium = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isWhite = color == Colors.white;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 90,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(14),
            border: isWhite
                ? Border.all(
                    color: const Color(0xFF34C759).withValues(alpha: 0.3),
                  )
                : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                color: isWhite ? const Color(0xFF34C759) : Colors.white,
                size: 22,
              ),
              const Spacer(),
              Text(
                label,
                style: TextStyle(
                  color: isWhite ? const Color(0xFF34C759) : Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              if (isPremium)
                Container(
                  margin: const EdgeInsets.only(top: 2),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF34C759),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'PREMIUM',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuoteQuickCard extends StatelessWidget {
  final AssetModel asset;
  final String title;
  final String priceText;
  final int digits;
  final String badge;
  final Color badgeColor;
  const _QuoteQuickCard({
    required this.asset,
    required this.title,
    required this.priceText,
    required this.digits,
    required this.badge,
    required this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    final isPos = asset.changePercent >= 0;
    final chgColor = isPos ? const Color(0xFF34C759) : const Color(0xFFFF3B30);
    final isCurrencyBadge = badge == r'$' || badge == '€';
    final badgeSize = isCurrencyBadge ? 32.0 : 24.0;
    final badgeFontSize = isCurrencyBadge ? 14.0 : 7.0;
    final theme = Theme.of(context);
    final surface = theme.colorScheme.surface;
    final onSurfaceSecondary = theme.colorScheme.onSurface.withOpacity(0.7);

    return Container(
      width: 104,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: badgeSize,
                height: badgeSize,
                decoration: BoxDecoration(
                  color: badgeColor,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    badge,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: badgeFontSize,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(color: onSurfaceSecondary, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            priceText,
            style: TextStyle(
              color: chgColor,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          StockPriceChangeBadge(asset: asset, fontSize: 16),
        ],
      ),
    );
  }
}

class _PanelButton extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  const _PanelButton({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surface = theme.colorScheme.surface;
    final onSurfaceSecondary = theme.colorScheme.onSurface.withOpacity(0.65);
    final shadowColor = theme.brightness == Brightness.light
        ? Colors.black.withValues(alpha: 0.05)
        : Colors.white.withOpacity(0.04);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? theme.colorScheme.primary : surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: shadowColor, blurRadius: 4)],
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isActive
                  ? theme.colorScheme.onPrimary
                  : onSurfaceSecondary,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

class _FavoriteListCard extends StatelessWidget {
  final String title;
  final List<String> list;
  final bool canAdd;
  final VoidCallback onAdd;
  final ValueChanged<String> onRemove;
  final Function(String symbol, String name) onSelectSymbol;
  final void Function(int oldIndex, int newIndex) onReorder;
  final Map<String, AssetModel> priceCache;

  const _FavoriteListCard({
    required this.title,
    required this.list,
    required this.canAdd,
    required this.onAdd,
    required this.onRemove,
    required this.onSelectSymbol,
    required this.onReorder,
    required this.priceCache,
  });

  @override
  Widget build(BuildContext context) {
    const double cardHorizontalPadding = 18;
    const double cardVerticalPadding = 16;
    const double cardMinHeight = 78;
    const double cardRadius = 14;
    const double symbolNameGap = 4;
    const double priceGap = 8;
    const double symbolFontSize = 17;
    const double nameFontSize = 13;
    const double priceFontSize = 18;
    const double changeFontSize = 14;

    final theme = Theme.of(context);
    final surface = theme.colorScheme.surface;
    final onSurface = theme.colorScheme.onSurface;
    final onSurfaceSecondary = theme.colorScheme.onSurface.withOpacity(0.65);
    final borderColor = theme.brightness == Brightness.light
        ? theme.dividerColor
        : theme.colorScheme.onSurface.withOpacity(0.08);
    final shadowColor = theme.brightness == Brightness.light
        ? Colors.black.withValues(alpha: 0.04)
        : Colors.white.withOpacity(0.03);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: shadowColor, blurRadius: 6)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (title.isNotEmpty)
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              if (title.isNotEmpty) const Spacer(),
              Text(
                '${list.length}/20',
                style: TextStyle(color: onSurfaceSecondary, fontSize: 12),
              ),
              const Spacer(),
              GestureDetector(
                onTap: canAdd ? onAdd : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: canAdd
                        ? theme.colorScheme.primary.withOpacity(0.12)
                        : theme.colorScheme.onSurface.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.edit_outlined,
                        size: 13,
                        color: canAdd
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface.withOpacity(0.5),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Düzenle',
                        style: TextStyle(
                          color: canAdd
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurface.withOpacity(0.6),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (list.isEmpty)
            Text(
              'Henüz hisse eklenmedi.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: onSurfaceSecondary,
                fontSize: 13,
              ),
            )
          else
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: list.length,
              onReorder: onReorder,
              itemBuilder: (context, index) {
                final symbol = list[index];
                final asset = priceCache[symbol];
                final isPos = (asset?.changePercent ?? 0) >= 0;
                final chgColor = isPos
                    ? const Color(0xFF34C759)
                    : const Color(0xFFFF3B30);

                return Dismissible(
                  key: ValueKey(symbol),
                  direction: DismissDirection.horizontal,
                  onDismissed: (_) => onRemove(symbol),
                  background: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.error,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.centerLeft,
                    child: Icon(
                      Icons.delete,
                      color: theme.colorScheme.onError,
                      size: 24,
                    ),
                  ),
                  secondaryBackground: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.error,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.centerRight,
                    child: Icon(
                      Icons.delete,
                      color: theme.colorScheme.onError,
                      size: 24,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        ReorderableDragStartListener(
                          index: index,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: Container(
                              width: 28,
                              height: 44,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.onSurface.withOpacity(
                                  0.08,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 14,
                                    height: 3,
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.onSurface
                                          .withOpacity(0.45),
                                      borderRadius: BorderRadius.circular(1.5),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    width: 14,
                                    height: 3,
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.onSurface
                                          .withOpacity(0.45),
                                      borderRadius: BorderRadius.circular(1.5),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: () =>
                                onSelectSymbol(symbol, asset?.name ?? symbol),
                            child: Container(
                              constraints: const BoxConstraints(
                                minHeight: cardMinHeight,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: cardHorizontalPadding,
                                vertical: cardVerticalPadding,
                              ),
                              decoration: BoxDecoration(
                                color: surface,
                                borderRadius: BorderRadius.circular(cardRadius),
                                border: Border.all(
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.08),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          symbol,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: symbolFontSize,
                                            color: onSurface,
                                          ),
                                        ),
                                        if (asset != null) ...[
                                          const SizedBox(height: symbolNameGap),
                                          Text(
                                            asset.name,
                                            style: TextStyle(
                                              fontSize: nameFontSize,
                                              color: onSurfaceSecondary,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  if (asset != null) ...[
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          '${asset.price.toStringAsFixed(2)} ₺',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: priceFontSize,
                                            color: onSurface,
                                          ),
                                        ),
                                        const SizedBox(height: priceGap),
                                        Text(
                                          '${isPos ? '+' : ''}${asset.changePercent.toStringAsFixed(2)}%',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: changeFontSize,
                                            color: chgColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  const _TabChip({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surface = theme.colorScheme.surface;
    final onSurfaceSecondary = theme.colorScheme.onSurface.withOpacity(0.65);
    final shadowColor = theme.brightness == Brightness.light
        ? Colors.black.withValues(alpha: 0.05)
        : Colors.white.withOpacity(0.04);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isActive ? theme.colorScheme.primary : surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: shadowColor, blurRadius: 4)],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? theme.colorScheme.onPrimary : onSurfaceSecondary,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
