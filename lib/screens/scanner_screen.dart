import 'package:flutter/material.dart';
import '../models/asset_model.dart';
import '../services/stock_service.dart';
import '../services/subscription_service.dart';
import '../widgets/stock_quote_panel.dart';
import 'buy_screen.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabController;
  List<String> _activeFilters = [];
  final Set<String> _selectedAiFilters = {};
  List<AssetModel> _results = [];
  bool _scanning = false;
  int _progress = 0;
  int _total = 0;
  String? _errorMsg;
  String _activePeriod = 'G';
  _ScanScope _lastScanScope = _ScanScope.bist500;

  static final List<String> _bist500Symbols =
      kBistStocks.map((e) => e['symbol']!).toList();

  static final List<String> _bist100Symbols =
      kBistStocks.take(100).map((e) => e['symbol']!).toList();

  static List<String> _symbolsForScope(_ScanScope scope) =>
      scope == _ScanScope.bist100 ? _bist100Symbols : _bist500Symbols;

  static String _scopeLabel(_ScanScope scope) =>
      scope == _ScanScope.bist100 ? 'BIST 100' : 'BIST 500';

  static String _scopeSubtitle(_ScanScope scope) =>
      scope == _ScanScope.bist100
          ? 'BIST 100 içindeki hisseler taranır.'
          : 'Borsa İstanbul’daki güncel hisse listesi üzerinden $kBistListedCount hisse taranır.';

  static const List<_FilterDef> _trendFilters = [
    _FilterDef(
      id: 'MACD Bullish',
      label: 'MACD',
      subtitle: 'Koşul: MACD çizgisi sinyal çizgisini yukarı keser → Alım sinyali, pozitif momentum oluşturur.',
      color: Color(0xFF34C759),
      icon: Icons.show_chart,
    ),
    _FilterDef(
      id: 'Golden Cross',
      label: 'EMA Kesişimi',
      subtitle: 'Koşul: Kısa vadeli EMA (örn: EMA 20), uzun vadeli olanı (örn: EMA 50) yukarı yönde kestiğinde \'Golden Cross\' olarak bilinen güçlü bir yükseliş sinyali oluşur.',
      color: Color(0xFF86C232),
      icon: Icons.trending_up,
    ),
    _FilterDef(
      id: 'Death Cross',
      label: 'Death Cross',
      subtitle: 'Koşul: EMA20, EMA50\'yi aşağı yönde kestiğinde güçlü bir düşüş sinyali oluşur.',
      color: Color(0xFFFF6B6B),
      icon: Icons.trending_down,
    ),
    _FilterDef(
      id: 'Supertrend AL',
      label: 'Supertrend AL',
      subtitle: 'Koşul: Supertrend göstergesi yön değiştirerek AL sinyali üretir. Trendin başlangıcını yakalar.',
      color: Color(0xFF4CAF50),
      icon: Icons.bolt,
    ),
    _FilterDef(
      id: 'Supertrend SAT',
      label: 'Supertrend SAT',
      subtitle: 'Koşul: Supertrend göstergesi SAT sinyali üretir. Düşüş trendinin başlangıcını işaret eder.',
      color: Color(0xFFEF5350),
      icon: Icons.bolt_outlined,
    ),
    _FilterDef(
      id: 'Hammer',
      label: '🔨 Hammer',
      subtitle: 'Potansiyel trend dönüşlerinin habercisi olan önemli bir mum çubuğu formasyonudur.',
      color: Color(0xFFFF9800),
      icon: Icons.hardware,
    ),
    _FilterDef(
      id: 'Doji',
      label: '➕ Doji',
      subtitle: 'Borsada açılış ve kapanış fiyatlarının birbirine çok yakın veya eşit olduğu bir mum çubuğu formasyonudur.',
      color: Color(0xFF9C27B0),
      icon: Icons.add_circle_outline,
    ),
    _FilterDef(
      id: 'Morning Star',
      label: '🌟 Morning Star',
      subtitle: 'Düşüş trendinin sonunda görülen ve yukarı yönlü bir dönüşe işaret eden bir mum formasyonudur. (Sabah Yıldızı)',
      color: Color(0xFFFFD700),
      icon: Icons.star_outline,
    ),
    _FilterDef(
      id: 'Bullish Engulfing',
      label: '🐂 Boğa Yutan',
      subtitle: 'Düşüş trendi sonrası gelen pozitif dönüşü temsil eder. İlk mum kırmızı, ikinci mum ise onu yutan yeşil bir mumdur.',
      color: Color(0xFF00C853),
      icon: Icons.arrow_circle_up,
    ),
    _FilterDef(
      id: 'Bearish Engulfing',
      label: '🐻 Ayı Yutan',
      subtitle: 'Yükseliş trendi ardından gelen negatif dönüşü temsil eder. İlk mum yeşil, ikinci mum ise onu yutan kırmızı bir mumdur.',
      color: Color(0xFFD32F2F),
      icon: Icons.arrow_circle_down,
    ),
  ];

  static const List<_FilterDef> _momentumFilters = [
    _FilterDef(
      id: 'RSI 40',
      label: 'RSI 40 Altı',
      subtitle: 'Koşul: RSI değeri 40 ve altına düştüğünde aşırı satım bölgesine yaklaşılıyor demektir. Potansiyel dönüş noktası.',
      color: Color(0xFFAB47BC),
      icon: Icons.show_chart,
    ),
    _FilterDef(
      id: 'KISA VADE TRADE',
      label: 'KISA VADE TRADE',
      subtitle: 'Kısa vade AL/SAT sinyali',
      color: Color(0xFF29B6F6),
      icon: Icons.flash_on,
    ),
    _FilterDef(
      id: 'HACIMLENEN DİP',
      label: '🔥 HACİMLENEN DİP',
      subtitle: 'Koşul: RSI düşük, hacim yükselmiş ve fiyat dip bölgesinde. Premium sinyali.',
      color: Color(0xFFEF6C00),
      icon: Icons.local_fire_department,
    ),
    _FilterDef(
      id: 'DEGER_FILTRESI',
      label: '💎 DEĞER FİLTRESİ',
      subtitle: 'PD/DD < 1.50 · F/K > 0 · F/K < 15',
      color: Color(0xFF00BFA5),
      icon: Icons.diamond,
    ),
    _FilterDef(
      id: 'BB SIKIŞMA',
      label: 'BB SIKIŞMA',
      subtitle: 'Bollinger Bandı Squeeze patlama öncesi oluşum.',
      color: Color(0xFF7C4DFF),
      icon: Icons.compress,
    ),
    _FilterDef(
      id: 'EMA20 > EMA50',
      label: 'EMA20 > EMA50',
      subtitle: 'Koşul: EMA20 çizgisi EMA50 çizgisini yukarı kestikten sonra en az %0.20 üzerine çıkmış olması.',
      color: Color(0xFF2196F3),
      icon: Icons.trending_up,
    ),
    _FilterDef(
      id: 'MA50 = MA200',
      label: 'MA50 = MA200',
      subtitle: 'Koşul: Fiyat MA50\'nin ve MA200\'ün üzerinde kapanış yapmış olan hisseleri süz.',
      color: Color(0xFFE91E63),
      icon: Icons.trending_up,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // App foreground'a gelince (ör: ödeme sonrası dönünce) premium durumu güncele
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      setState(() {}); // hasPremiumAccess'i taze oku
    }
  }

  List<_FilterDef> get _currentFilters =>
      _tabController.index == 0 ? _trendFilters : _momentumFilters;

  bool _isFilterAvailableForFreePlan(String filterId) {
    // Deneme süresi bittikten sonra ücretsiz kullanımda açık olan filtreler
    const freeFilters = {
      'MACD Bullish',  // MACD
      'Golden Cross',  // EMA Kesişimi
      'Death Cross',   // Death Cross
    };
    return freeFilters.contains(filterId);
  }

  bool _canUseFilter(String filterId) {
    // Aktif deneme (10 gün) veya ücretli premium ise tüm filtreler açık
    if (SubscriptionService.hasPremiumAccess) return true;
    // Deneme bitmişse sadece ücretsiz filtreler
    return _isFilterAvailableForFreePlan(filterId);
  }

  bool _matchFilters(AssetModel a, List<String> filterIds) {
    return filterIds.every((filterId) {
      switch (filterId) {
        case 'RSI 40':           return a.isRsiBelow40;
        case 'HACIMLENEN DİP':   return a.isVolumeDip;
        case 'DEGER_FILTRESI':   return a.isValueStock;
        case 'KISA VADE TRADE':  return a.isKisaVadeTrade;
        case 'BB SIKIŞMA':       return a.isBollingerSqueeze;
        case 'EMA20 > EMA50':    return a.isEma20AboveEma50WithMargin;
        case 'MA50 = MA200':     return a.isPriceAboveMa50AndMa200;
        case 'Golden Cross':     return a.isGoldenCross;
        case 'Death Cross':      return a.isDeathCross;
        case 'Supertrend AL':    return a.isSupertrendBuy;
        case 'Supertrend SAT':   return a.isSupertrendSell;
        case 'MACD Bullish':     return a.isMacdBullish;
        case 'Hammer':           return a.isHammer;
        case 'Doji':             return a.isDoji;
        case 'Morning Star':     return a.isMorningStar;
        case 'Bullish Engulfing':return a.isBullishEngulfing;
        case 'Bearish Engulfing':return a.isBearishEngulfing;
        default: return false;
      }
    });
  }

  Future<void> _onFilterCardTap(_FilterDef def, bool isAiTab) async {
    // Ücretsiz planda kısıtlı filtrelere erişim kontrolü
    if (!_canUseFilter(def.id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.lock, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text('"${def.label}" premium özellik. Lütfen plan yükseltin.'),
              ),
            ],
          ),
          backgroundColor: const Color(0xFFFF6B6B),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    if (_scanning) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.white),
              SizedBox(width: 8),
              Text('Tarama devam ediyor, lütfen bitmesini bekleyin.'),
            ],
          ),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (isAiTab) {
      setState(() {
        if (_selectedAiFilters.contains(def.id)) {
          _selectedAiFilters.remove(def.id);
        } else {
          _selectedAiFilters.add(def.id);
        }
      });
      return;
    }

    final result = await _showScanConfirmDialog(filters: [def]);
    if (result != null && mounted) {
      _startScan([def.id], scope: result.scope);
    }
  }

  Future<void> _onMultiScanTap() async {
    if (_scanning) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.white),
              SizedBox(width: 8),
              Text('Tarama devam ediyor, lütfen bitmesini bekleyin.'),
            ],
          ),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // Seçili filtreler arasında erişim izni olmayan kontrol
    final unavailableFilters = _selectedAiFilters
        .where((filterId) => !_canUseFilter(filterId))
        .toList();

    if (unavailableFilters.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.lock, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${unavailableFilters.length} filtre premium. Lütfen plan yükseltin.',
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFFFF6B6B),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    final defs = _momentumFilters
        .where((f) => _selectedAiFilters.contains(f.id))
        .toList();
    final result = await _showScanConfirmDialog(filters: defs);
    if (result != null && mounted) {
      _startScan(_selectedAiFilters.toList(), scope: result.scope);
    }
  }

  Future<_ScanConfirmResult?> _showScanConfirmDialog(
      {required List<_FilterDef> filters}) async {
    if (filters.isEmpty) return null;

    return showDialog<_ScanConfirmResult>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _ScanConfirmDialog(
        filters: filters,
        periodLabel: _periodLabel(_activePeriod),
        bist500Count: _bist500Symbols.length,
        bist100Count: _bist100Symbols.length,
      ),
    );
  }

  Future<void> _startScan(List<String> filterIds,
      {required _ScanScope scope}) async {
    if (filterIds.isEmpty) return;

    // Erişim kontrolü
    final unavailableFilters = filterIds.where((filterId) => !_canUseFilter(filterId)).toList();
    if (unavailableFilters.isNotEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.lock, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${unavailableFilters.length} filtre premium. Lütfen plan yükseltin.',
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFFFF6B6B),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    final symbols = _symbolsForScope(scope);
    setState(() {
      _activeFilters = filterIds;
      _lastScanScope = scope;
      _scanning = true;
      _results = [];
      _progress = 0;
      _total = symbols.length;
      _errorMsg = null;
    });
    try {
      final hasMa200 = filterIds.contains('MA50 = MA200');
      final assets = await StockService.fetchMultiple(
        symbols, period: hasMa200 ? '1y' : '6mo',
        onProgress: (done, total) {
          if (mounted) setState(() => _progress = done);
        },
      );
      final filtered = assets.where((a) => _matchFilters(a, filterIds)).toList();
      if (mounted) setState(() { _results = filtered; _scanning = false; });
    } catch (e) {
      if (mounted) setState(() { _scanning = false; _errorMsg = 'Hata: $e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Başlık
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Row(
                children: [
                  Icon(Icons.menu, color: theme.colorScheme.onSurface.withValues(alpha: 0.7), size: 22),
                  const SizedBox(width: 8),
                  Text('Tarama', style: theme.textTheme.titleLarge?.copyWith(fontSize: 20, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  if (_scanning)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text('$_progress/$_total', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.65), fontSize: 12)),
                    ),
                  if (_scanning)
                    const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF34C759))),
                ],
              ),
            ),

            // Periyot + aktif bilgisi
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
              child: Row(
                children: [
                  Icon(Icons.access_time, color: theme.colorScheme.primary, size: 14),
                  const SizedBox(width: 4),
                  Text('Aktif Periyot: ', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.65), fontSize: 24)),
                  Text(_periodLabel(_activePeriod),
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary, fontSize: 24, fontWeight: FontWeight.bold)),
                ],
              ),
            ),

            // Periyot değiştir bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GestureDetector(
                onTap: _showPeriodSheet,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    color: const Color(0xFF34C759),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.tune, color: theme.colorScheme.onPrimary, size: 16),
                      const SizedBox(width: 8),
                      Text('Periyot Değiştir',
                          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                      const Spacer(),
                      Icon(Icons.keyboard_arrow_down, color: theme.colorScheme.onPrimary, size: 20),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Tab: RADAR / AI SİNYAL — Özel neon tasarım
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _ScannerTabBar(
                controller: _tabController,
                onTap: (_) => setState(() {}),
              ),
            ),

            const SizedBox(height: 4),

            if (_scanning) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: LinearProgressIndicator(
                  value: _total > 0 ? _progress / _total : 0,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  color: const Color(0xFF34C759),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],

            if (_errorMsg != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: Text(_errorMsg!, style: const TextStyle(color: Color(0xFFFF3B30), fontSize: 12)),
              ),

            // Liste: filtreler veya sonuçlar
            Expanded(
              child: _activeFilters.isNotEmpty && _results.isNotEmpty
                  ? _buildResults()
                  : _activeFilters.isNotEmpty && !_scanning && _results.isEmpty
                      ? _buildEmptyResult()
                      : Stack(
                          children: [
                            _buildFilterList(),
                            if (_tabController.index == 1 && _selectedAiFilters.isNotEmpty)
                              Positioned(
                                left: 16,
                                right: 16,
                                bottom: 16,
                                child: _buildScanButton(),
                              ),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyResult() {
    final theme = Theme.of(context);
    final filterName = _activeFilters.isNotEmpty
        ? (_currentFilters
            .where((f) => _activeFilters.contains(f.id))
            .map((f) => f.label.replaceAll(RegExp(r'[🔨➕🌟🐂🐻]'), '').trim())
            .join(', '))
        : 'Seçili';

    final periodMsg = switch (_activePeriod) {
      '4S' => '4 saatlik',
      'G'  => 'günlük',
      'H'  => 'haftalık',
      'A'  => 'aylık',
      _    => _activePeriod,
    };

    final advice = switch (_activePeriod) {
      'G' =>
        'Günlük periyotta $filterName formasyonu için uygun hisse bulunamadı.\n\n'
        'Formasyonlar her gün oluşmaz; piyasa koşullarına bağlı olarak '
        'birkaç gün sonra tekrar tarama yapabilirsiniz. '
        'Haftalık veya aylık periyotta da deneyebilirsiniz — '
        'daha uzun periyotlarda formasyon sinyalleri daha güçlü olabilir.',
      '4S' =>
        '4 saatlik periyotta $filterName formasyonu için uygun hisse bulunamadı.\n\n'
        'Kısa periyotlarda formasyonlar hızlı oluşur ve kaybolur. '
        'Birkaç saat sonra tekrar tarama yapabilir veya '
        'günlük periyoda geçerek daha stabil sinyaller arayabilirsiniz.',
      'H' =>
        'Haftalık periyotta $filterName formasyonu için uygun hisse bulunamadı.\n\n'
        'Haftalık formasyonlar piyasada güçlü dönüş sinyallerine işaret eder. '
        'Bu formasyonun oluşması birkaç hafta alabilir. '
        'Sabırlı olun ve ilerleyen haftalarda taramayı tekrarlayın. '
        'Bu arada günlük periyotta benzer hareketleri takip edebilirsiniz.',
      'A' =>
        'Aylık periyotta $filterName formasyonu için uygun hisse bulunamadı.\n\n'
        'Aylık formasyonlar çok güçlü uzun vadeli sinyallerdir ve nadir oluşur. '
        'Piyasanın genel eğilimi bu formasyonu desteklemiyor olabilir. '
        'Kısa vadeli periyotlarda tarama yaparak fırsatları değerlendirebilirsiniz.',
      _ =>
        '$periodMsg periyotta $filterName formasyonu için uygun hisse bulunamadı.\n\n'
        'Farklı bir formasyon veya periyot deneyebilirsiniz.',
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 48, color: theme.colorScheme.primary),
            const SizedBox(height: 18),
            Text(
              '$periodMsg taramasında sonuç bulunamadı',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            Text(
              advice,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: () => setState(() {
                _activeFilters = [];
                _results = [];
              }),
              icon: const Icon(Icons.arrow_back, size: 16),
              label: const Text('Filtrelere Dön'),
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.colorScheme.primary,
                side: BorderSide(color: theme.colorScheme.primary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanButton() {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: (_scanning ? Colors.grey : const Color(0xFF34C759)).withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: _scanning ? theme.colorScheme.surfaceContainerHighest : const Color(0xFF34C759),
          foregroundColor: theme.colorScheme.onPrimary,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        onPressed: _onMultiScanTap,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_scanning) ...[
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.onPrimary),
              ),
              const SizedBox(width: 8),
              Text(
                'Taranıyor...',
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ] else ...[
              const Icon(Icons.search, size: 20),
              const SizedBox(width: 8),
              Text(
                '${_selectedAiFilters.length} Sinyalle Süz (${_selectedAiFilters.length == 1 ? "Hassas" : "Çoklu Doğruluk"})',
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFilterList() {
    final filters = _currentFilters;
    final isAiTab = _tabController.index == 1;
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(16, 8, 16, isAiTab && _selectedAiFilters.isNotEmpty ? 80 : 16),
      itemCount: filters.length,
      itemBuilder: (_, i) {
        final def = filters[i];
        final isSelected = isAiTab
            ? _selectedAiFilters.contains(def.id)
            : _activeFilters.contains(def.id);
        final isAvailable = _canUseFilter(def.id);
        return _FilterCard(
          def: def,
          isSelected: isSelected,
          isAvailable: isAvailable,
          isPremium: !_isFilterAvailableForFreePlan(def.id),
          onTap: () => _onFilterCardTap(def, isAiTab),
        );
      },
    );
  }

  Widget _buildResults() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${_results.length} hisse bulundu · ${_scopeLabel(_lastScanScope)}',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => setState(() {
                  _activeFilters = [];
                  _results = [];
                }),
                child: Text(
                  '← Filtrelere Dön',
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            itemCount: _results.length,
            itemBuilder: (_, i) => _ResultCard(
              asset: _results[i],
              activeFilters: _activeFilters,
            ),
          ),
        ),
      ],
    );
  }

  void _showPeriodSheet() {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Periyot Seç', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...['4S', 'G', 'H', 'A'].map((p) => ListTile(
              title: Text(_periodLabel(p), style: theme.textTheme.bodyMedium),
              trailing: _activePeriod == p
                  ? const Icon(Icons.check, color: Color(0xFF34C759)) : null,
              onTap: () {
                setState(() => _activePeriod = p);
                Navigator.pop(context);
              },
            )),
          ],
        ),
      ),
    );
  }

  String _periodLabel(String p) {
    switch (p) {
      case '4S': return '4 Saatlik';
      case 'G':  return '1 Gün';
      case 'H':  return '1 Hafta';
      case 'A':  return '1 Ay';
      default:   return p;
    }
  }
}

enum _ScanScope { bist500, bist100 }

class _ScanConfirmResult {
  final _ScanScope scope;
  const _ScanConfirmResult({required this.scope});
}

class _FilterDef {
  final String id, label, subtitle;
  final Color color;
  final IconData icon;
  const _FilterDef({required this.id, required this.label, required this.subtitle,
      required this.color, required this.icon});

  String get cleanLabel =>
      label.replaceAll(RegExp(r'[🔨➕🌟🐂🐻]\s*'), '').trim();
}

// ─────────────────────────────────────────────────────────────────────────────
// Tarama Onay Diyaloğu
// ─────────────────────────────────────────────────────────────────────────────

class _ScanConfirmDialog extends StatefulWidget {
  final List<_FilterDef> filters;
  final String periodLabel;
  final int bist500Count;
  final int bist100Count;

  const _ScanConfirmDialog({
    required this.filters,
    required this.periodLabel,
    required this.bist500Count,
    required this.bist100Count,
  });

  @override
  State<_ScanConfirmDialog> createState() => _ScanConfirmDialogState();
}

class _ScanConfirmDialogState extends State<_ScanConfirmDialog> {
  _ScanScope _scope = _ScanScope.bist500;

  @override
  Widget build(BuildContext context) {
    final filters = widget.filters;
    final primary = filters.first;
    final isMulti = filters.length > 1;
    final accent = isMulti ? const Color(0xFF34C759) : primary.color;

    final theme = Theme.of(context);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.18),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Üst renk şeridi
            Container(
              height: 5,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20)),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                children: [
                  // İkon — kartla aynı stil
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      isMulti ? Icons.bolt : primary.icon,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Başlık
                  Text(
                    isMulti
                        ? '${filters.length} Algoritma Seçildi'
                        : '${primary.cleanLabel} Algoritmasını\nSeçtiniz',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Açıklama
                  Text(
                    isMulti
                        ? 'Seçili algoritmalar birlikte uygulanarak tarama yapılacak.'
                        : primary.subtitle,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 13,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                      height: 1.5,
                    ),
                    maxLines: isMulti ? 2 : 4,
                    overflow: TextOverflow.ellipsis,
                  ),

                  if (isMulti) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      alignment: WrapAlignment.center,
                      children: filters
                          .map((f) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: f.color.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: f.color.withValues(alpha: 0.35)),
                                ),
                                child: Text(
                                  f.cleanLabel,
                                  style: TextStyle(
                                    color: f.color,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
                  ],

                  const SizedBox(height: 16),

                  Text(
                    _ScannerScreenState._scopeSubtitle(_scope),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Tarama kapsamı seçimi
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Tarama Kapsamı',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _ScopeOption(
                          title: 'BIST 500 Standart Tarama',
                          selected: _scope == _ScanScope.bist500,
                          accent: accent,
                          onTap: () =>
                              setState(() => _scope = _ScanScope.bist500),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _ScopeOption(
                          title: 'BIST 100 Hızlı Tarama',
                          selected: _scope == _ScanScope.bist100,
                          accent: accent,
                          onTap: () =>
                              setState(() => _scope = _ScanScope.bist100),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Bilgi satırları
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        _ConfirmInfoRow(
                          icon: Icons.access_time,
                          iconColor: const Color(0xFF34C759),
                          label: 'Periyot',
                          value: widget.periodLabel,
                        ),
                      ],
                    ),
                  ),


                  const SizedBox(height: 18),

                  // Soru
                  Text(
                    'Taramayı başlatmak ister misiniz?',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Butonlar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey[700],
                        side: BorderSide(color: Colors.grey[300]!),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Hayır',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(
                        context,
                        _ScanConfirmResult(scope: _scope),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Evet, Başlat',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScopeOption extends StatelessWidget {
  final String title;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  const _ScopeOption({
    required this.title,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? accent.withValues(alpha: 0.10)
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? accent : theme.colorScheme.surfaceContainerHighest,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: selected ? accent : theme.colorScheme.onSurface.withValues(alpha: 0.85),
              ),
            ),
            if (selected) ...[
              const SizedBox(height: 4),
              Icon(Icons.check_circle, size: 14, color: accent),
            ],
          ],
        ),
      ),
    );
  }
}

class _ConfirmInfoRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _ConfirmInfoRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: 8),
        Text(label,
            style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.72), fontSize: 24)),
        const Spacer(),
        Text(value,
            style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 24,
                fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _FilterCard extends StatelessWidget {
  final _FilterDef def;
  final bool isSelected;
  final bool isAvailable;  // Ücretsiz planda available olup olmadığını gösterir
  final bool isPremium;
  final VoidCallback onTap;
  const _FilterCard({
    required this.def,
    required this.isSelected,
    required this.isAvailable,
    required this.isPremium,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: isAvailable ? onTap : null,
      child: Stack(
        children: [
          Opacity(
            opacity: isAvailable ? 1.0 : 0.4,
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(20),  // 14 → 20 (2x artış)
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: isSelected && isAvailable
                    ? Border.all(color: def.color, width: 2.5)
                    : null,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 64,  // 48 → 64
                    height: 64,  // 48 → 64
                    decoration: BoxDecoration(
                      color: isAvailable ? def.color : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(14),  // 12 → 14
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Icon(
                          def.icon,
                          color: Colors.white,
                          size: 32,  // 24 → 32
                        ),
                        if (!isAvailable)
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.lock,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 18),  // 14 → 18
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          def.label,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                          ),
                        ),
                        const SizedBox(height: 5),  // 3 → 5
                        Text(
                          def.subtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                            fontSize: 13,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (isPremium) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFD700).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: const Color(0xFFFFD700).withValues(alpha: 0.4),
                              ),
                            ),
                            child: Text(
                              '👑 Premium',
                              style: TextStyle(
                                color: theme.colorScheme.onSurface,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                        if (!isAvailable) ...[  // Premium lock göstergesi
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF6B6B).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: const Color(0xFFFF6B6B).withValues(alpha: 0.3),
                              ),
                            ),
                            child: const Text(
                              '🔒 Premium Özellik',
                              style: TextStyle(
                                color: Color(0xFFFF6B6B),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (isAvailable)
                    Icon(Icons.chevron_right, color: theme.colorScheme.onSurface.withValues(alpha: 0.65), size: 24)
                  else
                    Icon(Icons.lock, color: theme.colorScheme.onSurface.withValues(alpha: 0.65), size: 24),
                ],
              ),
            ),
          ),
          // Kral Tacı ve Premium etiket (Premium filtreler için)
          if (isPremium)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    )
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset('king.png', width: 18, height: 18),
                    const SizedBox(width: 6),
                    Text(
                      'Premium',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final AssetModel asset;
  final List<String> activeFilters;
  const _ResultCard({required this.asset, required this.activeFilters});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPos = asset.changePercent >= 0;
    final ema5val   = asset.ema(5);
    final ema20val  = asset.ema(20);
    final ema100val = asset.ema(100);
    final rsiVals   = asset.rsi();
    final currentRsi = rsiVals.isNotEmpty ? rsiVals.last : null;

    final badges = <_Badge>[];
    if (activeFilters.isNotEmpty) {
      for (final filterId in activeFilters) {
        if (filterId == 'RSI 40' && asset.isRsiBelow40 && currentRsi != null) {
          badges.add(_Badge(label: 'RSI ${currentRsi.toStringAsFixed(1)}', color: const Color(0xFFAB47BC)));
        }
        if (filterId == 'HACIMLENEN DİP' && asset.isVolumeDip) {
          badges.add(const _Badge(label: '🔥 HACİMLENEN DİP', color: Color(0xFFEF6C00)));
        }
        if (filterId == 'DEGER_FILTRESI' && asset.isValueStock) {
          badges.add(const _Badge(label: '💎 DEĞER FİLTRESİ', color: Color(0xFF00BFA5)));
        }
        if (filterId == 'KISA VADE TRADE' && asset.isKisaVadeTrade) {
          String label;
          if (asset.isEma8CrossUp) {
            label = '🟢 EMA8 Yukarı Kesti';
          } else if (asset.isEma8CrossDown) {
            label = '🔴 EMA8 Aşağı Kesti';
          } else if (asset.isPriceAboveEma8) {
            label = '📈 EMA8 Üzerinde';
          } else if (asset.isPriceBelowEma8) {
            label = '📉 EMA8 Altında';
          } else {
            label = 'KISA VADE TRADE';
          }
          badges.add(_Badge(label: label, color: const Color(0xFF29B6F6)));
        }
        if (filterId == 'BB SIKIŞMA' && asset.isBollingerSqueeze) {
          badges.add(_Badge(label: asset.bollingerSqueezeStatus, color: const Color(0xFF7C4DFF)));
        }
        if (filterId == 'EMA20 > EMA50' && asset.isEma20AboveEma50WithMargin) {
          badges.add(const _Badge(label: 'EMA20 > EMA50', color: Color(0xFF2196F3)));
        }
        if (filterId == 'MA50 = MA200' && asset.isPriceAboveMa50AndMa200) {
          badges.add(const _Badge(label: 'MA50 = MA200', color: Color(0xFFE91E63)));
        }
        if (filterId == 'Golden Cross' && asset.isGoldenCross) {
          badges.add(const _Badge(label: 'Golden Cross', color: Color(0xFF34C759)));
        }
        if (filterId == 'Death Cross' && asset.isDeathCross) {
          badges.add(const _Badge(label: 'Death Cross', color: Color(0xFFFF3B30)));
        }
        if (filterId == 'Supertrend AL' && asset.isSupertrendBuy) {
          badges.add(const _Badge(label: 'ST AL', color: Color(0xFF34C759)));
        }
        if (filterId == 'Supertrend SAT' && asset.isSupertrendSell) {
          badges.add(const _Badge(label: 'ST SAT', color: Color(0xFFFF3B30)));
        }
        if (filterId == 'MACD Bullish' && asset.isMacdBullish) {
          badges.add(const _Badge(label: 'MACD ↑', color: Color(0xFFFFB300)));
        }
        if (filterId == 'Hammer' && asset.isHammer) {
          badges.add(const _Badge(label: '🔨 Hammer', color: Color(0xFFFF9800)));
        }
        if (filterId == 'Doji' && asset.isDoji) {
          badges.add(const _Badge(label: '➕ Doji', color: Color(0xFF9C27B0)));
        }
        if (filterId == 'Morning Star' && asset.isMorningStar) {
          badges.add(const _Badge(label: '🌟 Morning Star', color: Color(0xFFFFD700)));
        }
        if (filterId == 'Bullish Engulfing' && asset.isBullishEngulfing) {
          badges.add(const _Badge(label: '🐂 Boğa Yutan', color: Color(0xFF00C853)));
        }
        if (filterId == 'Bearish Engulfing' && asset.isBearishEngulfing) {
          badges.add(const _Badge(label: '🐻 Ayı Yutan', color: Color(0xFFD32F2F)));
        }
      }
    } else {
      if (asset.isRsiBelow40 && currentRsi != null) {
        badges.add(_Badge(label: 'RSI ${currentRsi.toStringAsFixed(1)}', color: const Color(0xFFAB47BC)));
      }
      if (asset.isBollingerSqueeze) {
        badges.add(_Badge(label: asset.bollingerSqueezeStatus, color: const Color(0xFF7C4DFF)));
      }
      if (asset.isEma20AboveEma50WithMargin) {
        badges.add(const _Badge(label: 'EMA20 > EMA50', color: Color(0xFF2196F3)));
      }
      if (asset.isPriceAboveMa50AndMa200) {
        badges.add(const _Badge(label: 'MA50 = MA200', color: Color(0xFFE91E63)));
      }
      if (asset.isGoldenCross) badges.add(const _Badge(label: 'Golden Cross', color: Color(0xFF34C759)));
      if (asset.isDeathCross)  badges.add(const _Badge(label: 'Death Cross',  color: Color(0xFFFF3B30)));
      if (asset.isSupertrendBuy)  badges.add(const _Badge(label: 'ST AL',  color: Color(0xFF34C759)));
      if (asset.isSupertrendSell) badges.add(const _Badge(label: 'ST SAT', color: Color(0xFFFF3B30)));
      if (asset.isMacdBullish) badges.add(const _Badge(label: 'MACD ↑', color: Color(0xFFFFB300)));
      if (asset.isHammer)          badges.add(const _Badge(label: '🔨 Hammer',       color: Color(0xFFFF9800)));
      if (asset.isDoji)            badges.add(const _Badge(label: '➕ Doji',         color: Color(0xFF9C27B0)));
      if (asset.isMorningStar)     badges.add(const _Badge(label: '🌟 Morning Star', color: Color(0xFFFFD700)));
      if (asset.isBullishEngulfing)badges.add(const _Badge(label: '🐂 Boğa Yutan',  color: Color(0xFF00C853)));
      if (asset.isBearishEngulfing)badges.add(const _Badge(label: '🐻 Ayı Yutan',   color: Color(0xFFD32F2F)));
    }

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => BuyScreen(asset: asset)),
      ),
      child: Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 8, height: 8,
                  decoration: BoxDecoration(
                    color: isPos ? const Color(0xFF34C759) : const Color(0xFFFF3B30),
                    shape: BoxShape.circle,
                  )),
              const SizedBox(width: 8),
              Expanded(child: Text(asset.symbol,
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, fontSize: 20, color: theme.colorScheme.onSurface) ?? const TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: Colors.white))),
              StockPriceHeader(asset: asset),
            ],
          ),
          if (asset.name != asset.symbol)
            Padding(
              padding: const EdgeInsets.only(left: 16, top: 1),
              child: Text(asset.name, style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis),
            ),
          const SizedBox(height: 10),
          StockQuotePanel(asset: asset),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _InfoRow(icon: Icons.bar_chart, iconColor: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      label: 'Hacim', value: _fmtVol(asset.avgVolume)),                  const SizedBox(height: 5),
                  _InfoRow(icon: Icons.arrow_upward, iconColor: const Color(0xFF34C759),
                      label: '52H Yüksek', value: '${asset.high52w.toStringAsFixed(2)} ₺'),
                  const SizedBox(height: 5),
                  _InfoRow(icon: Icons.arrow_downward, iconColor: const Color(0xFFFF3B30),
                      label: '52H Düşük', value: '${asset.low52w.toStringAsFixed(2)} ₺'),
                ]),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('EMA Durumu', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.65))),
                const SizedBox(height: 4),
                if (ema5val.isNotEmpty)   _EmaRow(label: 'EMA5',   emaVal: ema5val.last,   price: asset.price),
                if (ema20val.isNotEmpty)  _EmaRow(label: 'EMA20',  emaVal: ema20val.last,  price: asset.price),
                if (ema100val.isNotEmpty) _EmaRow(label: 'EMA100', emaVal: ema100val.last, price: asset.price),
              ]),
            ],
          ),
          if (badges.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 3),
                  child: Text(
                    'Eşleşen Süzgeçler: ',
                    style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: badges.map((b) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: b.color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: b.color.withValues(alpha: 0.4)),
                      ),
                      child: Text(b.label, style: TextStyle(color: b.color, fontSize: 11, fontWeight: FontWeight.w700)),
                    )).toList(),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    ),  // GestureDetector kapanışı
    );
  }

  String _fmtVol(double v) {
    if (v >= 1e9) return '${(v / 1e9).toStringAsFixed(1)}B';
    if (v >= 1e6) return '${(v / 1e6).toStringAsFixed(1)}M';
    if (v >= 1e3) return '${(v / 1e3).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon; final Color iconColor; final String label, value;
  const _InfoRow({required this.icon, required this.iconColor, required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: iconColor, size: 14), const SizedBox(width: 3),
      Text('$label  ', style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.65), fontSize: 12, fontWeight: FontWeight.w600)),
      Text(value, style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 12, fontWeight: FontWeight.w700)),
    ]);
  }
}

class _EmaRow extends StatelessWidget {
  final String label; final double emaVal, price;
  const _EmaRow({required this.label, required this.emaVal, required this.price});
  @override
  Widget build(BuildContext context) {
    final above = price > emaVal;
    return Padding(padding: const EdgeInsets.only(bottom: 3), child: Row(mainAxisSize: MainAxisSize.min, children: [
      Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w600)),
      const SizedBox(width: 3),
      Icon(above ? Icons.arrow_upward : Icons.arrow_downward, size: 12,
          color: above ? const Color(0xFF34C759) : const Color(0xFFFF3B30)),
      const SizedBox(width: 2),
      Text(emaVal.toStringAsFixed(2), style: TextStyle(
          color: above ? const Color(0xFF34C759) : const Color(0xFFFF3B30),
          fontSize: 12, fontWeight: FontWeight.w700)),
    ]));
  }
}

class _Badge { final String label; final Color color; const _Badge({required this.label, required this.color}); }

// ─────────────────────────────────────────────────────────────────────────────
// Özel RADAR / AI SİNYAL Tab Bar — neon tasarım
// ─────────────────────────────────────────────────────────────────────────────

class _ScannerTabBar extends StatefulWidget {
  final TabController controller;
  final void Function(int) onTap;
  const _ScannerTabBar({required this.controller, required this.onTap});

  @override
  State<_ScannerTabBar> createState() => _ScannerTabBarState();
}

class _ScannerTabBarState extends State<_ScannerTabBar> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(() => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    final idx = widget.controller.index;
    final theme = Theme.of(context);
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
          ),
        ],
      ),
      child: Row(
        children: [
          // RADAR
          Expanded(
            child: GestureDetector(
              onTap: () {
                widget.controller.animateTo(0);
                widget.onTap(0);
              },
              child: Container(
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.horizontal(left: Radius.circular(14)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Radar ikonu — mavi neon daireler
                    SizedBox(
                      width: 36,
                      height: 36,
                      child: CustomPaint(
                        painter: _RadarPainter(
                          color: idx == 0
                              ? const Color(0xFF00BFFF)
                              : Colors.grey.shade400,
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'RADAR',
                      style: TextStyle(
                        color: idx == 0
                            ? theme.colorScheme.onSurface
                            : theme.colorScheme.onSurface.withValues(alpha: 0.55),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Dikey ayraç
          Container(
            width: 1,
            height: 50,
            color: theme.colorScheme.outline,
          ),

          // AI SİNYAL
          Expanded(
            child: GestureDetector(
              onTap: () {
                widget.controller.animateTo(1);
                widget.onTap(1);
              },
              child: Container(
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.horizontal(right: Radius.circular(14)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Şimşek ikonu — sarı/turuncu neon
                    Icon(
                      Icons.bolt,
                      size: 36,
                      color: idx == 1
                          ? const Color(0xFFFFB800)
                          : Colors.grey.shade400,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'AI SİNYAL',
                      style: TextStyle(
                        color: idx == 1
                            ? theme.colorScheme.onSurface
                            : theme.colorScheme.onSurface.withValues(alpha: 0.55),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Radar ikonu — CustomPainter ile neon mavi eşmerkezli daireler
class _RadarPainter extends CustomPainter {
  final Color color;
  const _RadarPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // 3 daire
    canvas.drawCircle(center, size.width * 0.45, paint);
    canvas.drawCircle(center, size.width * 0.30, paint);
    canvas.drawCircle(center, size.width * 0.15, paint);

    // Çapraz çizgiler (hedef nişangahı)
    canvas.drawLine(Offset(center.dx, center.dy - size.height * 0.45),
        Offset(center.dx, center.dy + size.height * 0.45), paint);
    canvas.drawLine(Offset(center.dx - size.width * 0.45, center.dy),
        Offset(center.dx + size.width * 0.45, center.dy), paint);

    // Merkez nokta
    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 2.5, dotPaint);
  }

  @override
  bool shouldRepaint(_RadarPainter old) => old.color != color;
}

