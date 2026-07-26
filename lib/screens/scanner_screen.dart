import 'package:flutter/material.dart';
import '../models/asset_model.dart';
import '../services/stock_service.dart';
import '../widgets/stock_quote_panel.dart';
import 'buy_screen.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> with SingleTickerProviderStateMixin {
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
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<_FilterDef> get _currentFilters =>
      _tabController.index == 0 ? _trendFilters : _momentumFilters;

  bool _matchFilters(AssetModel a, List<String> filterIds) {
    return filterIds.every((filterId) {
      switch (filterId) {
        case 'RSI 40':           return a.isRsiBelow40;
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
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Başlık
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Row(
                children: [
                  const Icon(Icons.menu, color: Colors.black54, size: 22),
                  const SizedBox(width: 8),
                  const Text('Tarama', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
                  const Spacer(),
                  if (_scanning)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text('$_progress/$_total', style: const TextStyle(color: Colors.grey, fontSize: 12)),
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
                  const Icon(Icons.access_time, color: Color(0xFF34C759), size: 14),
                  const SizedBox(width: 4),
                  const Text('Aktif Periyot: ', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  Text(_periodLabel(_activePeriod),
                      style: const TextStyle(color: Color(0xFF34C759), fontSize: 12, fontWeight: FontWeight.bold)),
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
                      const Icon(Icons.tune, color: Colors.white, size: 16),
                      const SizedBox(width: 8),
                      const Text('Periyot Değiştir',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                      const Spacer(),
                      const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 20),
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
                  backgroundColor: Colors.grey.shade200,
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

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFF34C759).withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.search_off,
                  color: Color(0xFF34C759), size: 36),
            ),
            const SizedBox(height: 16),
            Text(
              '$periodMsg taramasında sonuç bulunamadı',
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.black87),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 6)],
              ),
              child: Text(
                advice,
                style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 13,
                    height: 1.6),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => setState(() {
                _activeFilters = [];
                _results = [];
              }),
              icon: const Icon(Icons.arrow_back, size: 16),
              label: const Text('Filtrelere Dön'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF34C759),
                side: const BorderSide(color: Color(0xFF34C759)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanButton() {
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
          backgroundColor: _scanning ? Colors.grey : const Color(0xFF34C759),
          foregroundColor: Colors.white,
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
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
              const SizedBox(width: 8),
              const Text(
                'Taranıyor...',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ] else ...[
              const Icon(Icons.search, size: 20),
              const SizedBox(width: 8),
              Text(
                '${_selectedAiFilters.length} Sinyalle Süz (${_selectedAiFilters.length == 1 ? "Hassas" : "Çoklu Doğruluk"})',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
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
        return _FilterCard(
          def: def,
          isSelected: isSelected,
          onTap: () => _onFilterCardTap(def, isAiTab),
        );
      },
    );
  }

  Widget _buildResults() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: [
              Text(
                  '${_results.length} hisse bulundu · ${_scopeLabel(_lastScanScope)}',
                  style: const TextStyle(color: Colors.grey, fontSize: 12)),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() { _activeFilters = []; _results = []; }),
                child: const Text('← Filtrelere Dön',
                    style: TextStyle(color: Color(0xFF34C759), fontSize: 12, fontWeight: FontWeight.w600)),
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
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Periyot Seç', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...['4S', 'G', 'H', 'A'].map((p) => ListTile(
              title: Text(_periodLabel(p)),
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

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
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
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
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
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.black54,
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

                  // Tarama kapsamı seçimi
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Tarama Kapsamı',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
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
                      color: const Color(0xFFF2F2F7),
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
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
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
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? accent.withValues(alpha: 0.10)
              : const Color(0xFFF2F2F7),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? accent : Colors.grey.shade300,
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
                color: selected ? accent : Colors.black87,
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
    return Row(
      children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: 8),
        Text(label,
            style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const Spacer(),
        Text(value,
            style: const TextStyle(
                color: Colors.black87,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _FilterCard extends StatelessWidget {
  final _FilterDef def;
  final bool isSelected;
  final VoidCallback onTap;
  const _FilterCard({required this.def, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: isSelected ? Border.all(color: def.color, width: 2) : null,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)],
        ),
        child: Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: def.color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(def.icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(def.label, style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87)),
                  const SizedBox(height: 3),
                  Text(def.subtitle, style: const TextStyle(color: Colors.grey, fontSize: 11),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
          ],
        ),
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
        color: Colors.white,
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
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.black87))),
              StockPriceHeader(asset: asset),
            ],
          ),
          if (asset.name != asset.symbol)
            Padding(
              padding: const EdgeInsets.only(left: 16, top: 1),
              child: Text(asset.name, style: const TextStyle(color: Colors.grey, fontSize: 11),
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
                  _InfoRow(icon: Icons.bar_chart, iconColor: Colors.grey,
                      label: 'Hacim', value: _fmtVol(asset.avgVolume)),
                  const SizedBox(height: 5),
                  _InfoRow(icon: Icons.arrow_upward, iconColor: const Color(0xFF34C759),
                      label: '52H Yüksek', value: '${asset.high52w.toStringAsFixed(2)} ₺'),
                  const SizedBox(height: 5),
                  _InfoRow(icon: Icons.arrow_downward, iconColor: const Color(0xFFFF3B30),
                      label: '52H Düşük', value: '${asset.low52w.toStringAsFixed(2)} ₺'),
                ]),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                const Text('EMA Durumu', style: TextStyle(color: Colors.grey, fontSize: 11)),
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
                    style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold),
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
                      child: Text(b.label, style: TextStyle(color: b.color, fontSize: 10, fontWeight: FontWeight.bold)),
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
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, color: iconColor, size: 13), const SizedBox(width: 3),
    Text('$label  ', style: const TextStyle(color: Colors.grey, fontSize: 11)),
    Text(value, style: const TextStyle(color: Colors.black87, fontSize: 11, fontWeight: FontWeight.w600)),
  ]);
}

class _EmaRow extends StatelessWidget {
  final String label; final double emaVal, price;
  const _EmaRow({required this.label, required this.emaVal, required this.price});
  @override
  Widget build(BuildContext context) {
    final above = price > emaVal;
    return Padding(padding: const EdgeInsets.only(bottom: 3), child: Row(mainAxisSize: MainAxisSize.min, children: [
      Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
      const SizedBox(width: 3),
      Icon(above ? Icons.arrow_upward : Icons.arrow_downward, size: 11,
          color: above ? const Color(0xFF34C759) : const Color(0xFFFF3B30)),
      const SizedBox(width: 2),
      Text(emaVal.toStringAsFixed(2), style: TextStyle(
          color: above ? const Color(0xFF34C759) : const Color(0xFFFF3B30),
          fontSize: 11, fontWeight: FontWeight.w600)),
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
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: Colors.white,
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
                            ? Colors.black87
                            : Colors.grey.shade400,
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
            color: Colors.grey.shade200,
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
                            ? Colors.black87
                            : Colors.grey.shade400,
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
