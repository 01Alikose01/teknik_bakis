import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/backtest_service.dart';
import '../services/subscription_service.dart';
import '../services/app_navigation.dart';

class BacktestScreen extends StatefulWidget {
  final String symbol;
  final String symbolName;
  final String signalId;
  final String signalLabel;

  const BacktestScreen({
    super.key,
    required this.symbol,
    required this.symbolName,
    required this.signalId,
    required this.signalLabel,
  });

  @override
  State<BacktestScreen> createState() => _BacktestScreenState();
}

class _BacktestScreenState extends State<BacktestScreen> {
  String _period   = '1y';
  int    _holdDays = 5;

  bool              _loading = false;
  BacktestResult?   _result;
  String?           _error;

  // Periyot ve tutma seçenekleri
  static const List<_Option<String>> _periods = [
    _Option('6 Ay',  '6mo'),
    _Option('1 Yıl', '1y'),
    _Option('2 Yıl', '2y'),
  ];

  static const List<_Option<int>> _holds = [
    _Option('3 Gün',  3),
    _Option('5 Gün',  5),
    _Option('10 Gün', 10),
    _Option('20 Gün', 20),
  ];

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    if (!SubscriptionService.hasPremiumAccess) return;
    setState(() { _loading = true; _result = null; _error = null; });

    try {
      final result = await BacktestService.run(
        symbol:      widget.symbol,
        signalId:    widget.signalId,
        signalLabel: widget.signalLabel,
        period:      _period,
        holdDays:    _holdDays,
      );
      if (mounted) {
        setState(() {
          _result  = result;
          _loading = false;
          if (result == null) _error = 'Yeterli tarihsel veri bulunamadı.';
        });
      }
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = 'Veri alınamadı: $e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme   = Theme.of(context);
    final isDark  = theme.brightness == Brightness.dark;
    final onSurf  = theme.colorScheme.onSurface;
    final sub     = onSurf.withValues(alpha: 0.60);

    // Premium değilse gate göster
    if (!SubscriptionService.hasPremiumAccess) {
      return _PremiumGate(isDark: isDark, onUpgrade: () {
        Navigator.pop(context);
        AppNavigation.goToSettings();
      });
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.symbol} — Test',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            Text(
              widget.signalLabel,
              style: TextStyle(fontSize: 12, color: sub),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: theme.scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: [

            // ── Parametre seçici ──────────────────────────────────────────
            _SectionLabel(label: 'Test Dönemi', isDark: isDark),
            const SizedBox(height: 6),
            _ChipRow<String>(
              options:  _periods,
              selected: _period,
              onSelect: (v) { setState(() => _period = v); _run(); },
              isDark:   isDark,
            ),

            const SizedBox(height: 14),
            _SectionLabel(label: 'Tutma Süresi', isDark: isDark),
            const SizedBox(height: 6),
            _ChipRow<int>(
              options:  _holds,
              selected: _holdDays,
              onSelect: (v) { setState(() => _holdDays = v); _run(); },
              isDark:   isDark,
            ),

            const SizedBox(height: 20),

            // ── İçerik ───────────────────────────────────────────────────
            if (_loading)
              _LoadingView(isDark: isDark)
            else if (_error != null)
              _ErrorView(message: _error!, isDark: isDark, onRetry: _run)
            else if (_result != null)
              _ResultView(result: _result!, isDark: isDark)
            else
              const SizedBox.shrink(),

            const SizedBox(height: 32),

            // Yasal uyarı
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.orange.withValues(alpha: 0.10)
                    : Colors.orange.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.orange.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded,
                      color: Colors.orange.shade400, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Geçmiş performans gelecekteki sonuçları garanti etmez. '
                      'Bu analiz yatırım tavsiyesi değildir.',
                      style: TextStyle(
                        color: isDark
                            ? Colors.orange.shade300
                            : Colors.orange.shade800,
                        fontSize: 12,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sonuç görünümü
// ─────────────────────────────────────────────────────────────────────────────

class _ResultView extends StatelessWidget {
  final BacktestResult result;
  final bool isDark;

  const _ResultView({required this.result, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final theme  = Theme.of(context);
    final onSurf = theme.colorScheme.onSurface;
    final sub    = onSurf.withValues(alpha: 0.55);

    if (result.totalTrades == 0) {
      return _EmptyTrades(isDark: isDark);
    }

    final winColor  = isDark ? const Color(0xFF34C759) : const Color(0xFF1B8A3C);
    final lossColor = isDark ? const Color(0xFFFF5252) : const Color(0xFFD32F2F);
    final cardBg    = theme.colorScheme.surface;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [

        // ── Özet kartları ─────────────────────────────────────────────────
        Row(children: [
          _StatCard(
            label: 'Sinyal Sayısı',
            value: '${result.totalTrades}',
            icon: Icons.bar_chart_rounded,
            color: const Color(0xFF5C6BC0),
            isDark: isDark,
          ),
          const SizedBox(width: 10),
          _StatCard(
            label: 'Başarı Oranı',
            value: '%${result.winRate.toStringAsFixed(0)}',
            icon: Icons.emoji_events_rounded,
            color: result.winRate >= 50 ? winColor : lossColor,
            isDark: isDark,
          ),
        ]),

        const SizedBox(height: 10),

        Row(children: [
          _StatCard(
            label: 'Ort. Getiri',
            value: '${result.avgReturn >= 0 ? '+' : ''}${result.avgReturn.toStringAsFixed(1)}%',
            icon: Icons.trending_up_rounded,
            color: result.avgReturn >= 0 ? winColor : lossColor,
            isDark: isDark,
          ),
          const SizedBox(width: 10),
          _StatCard(
            label: 'Ort. Süre',
            value: '${result.avgHoldDays.toStringAsFixed(0)} gün',
            icon: Icons.timer_outlined,
            color: const Color(0xFF26C6DA),
            isDark: isDark,
          ),
        ]),

        const SizedBox(height: 10),

        Row(children: [
          _StatCard(
            label: 'En İyi İşlem',
            value: '+${result.bestReturn.toStringAsFixed(1)}%',
            icon: Icons.arrow_upward_rounded,
            color: winColor,
            isDark: isDark,
          ),
          const SizedBox(width: 10),
          _StatCard(
            label: 'En Kötü İşlem',
            value: '${result.worstReturn.toStringAsFixed(1)}%',
            icon: Icons.arrow_downward_rounded,
            color: lossColor,
            isDark: isDark,
          ),
        ]),

        const SizedBox(height: 20),

        // ── Kazanma / Kaybetme bar chart ─────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Kazanan / Kaybeden İşlemler',
                style: TextStyle(
                  color: onSurf,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${result.winTrades} kazanan · ${result.lossTrades} kaybeden',
                style: TextStyle(color: sub, fontSize: 12),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 28,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Row(children: [
                    if (result.winTrades > 0)
                      Flexible(
                        flex: result.winTrades,
                        child: Container(color: winColor),
                      ),
                    if (result.lossTrades > 0)
                      Flexible(
                        flex: result.lossTrades,
                        child: Container(color: lossColor),
                      ),
                  ]),
                ),
              ),
              const SizedBox(height: 10),
              Row(children: [
                _LegendDot(color: winColor),
                const SizedBox(width: 5),
                Text('Kazanan (${result.winTrades})',
                    style: TextStyle(color: winColor, fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(width: 16),
                _LegendDot(color: lossColor),
                const SizedBox(width: 5),
                Text('Kaybeden (${result.lossTrades})',
                    style: TextStyle(color: lossColor, fontSize: 12, fontWeight: FontWeight.w600)),
              ]),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // ── İşlem getirileri bar chart ────────────────────────────────────
        if (result.trades.isNotEmpty)
          _TradeReturnChart(result: result, isDark: isDark),

        const SizedBox(height: 16),

        // ── İşlem listesi ────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'İşlem Detayları',
                style: TextStyle(
                  color: onSurf,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Sinyal günü alış → ${result.holdDays} gün sonra satış',
                style: TextStyle(color: sub, fontSize: 12),
              ),
              const SizedBox(height: 10),
              ...result.trades.asMap().entries.map((e) {
                final idx   = e.key + 1;
                final trade = e.value;
                final isPos = trade.returnPct >= 0;
                final clr   = isPos ? winColor : lossColor;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: clr.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Center(
                          child: Text(
                            '$idx',
                            style: TextStyle(
                              color: clr,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Alış: ${trade.entryPrice.toStringAsFixed(2)} ₺  →  '
                              'Satış: ${trade.exitPrice.toStringAsFixed(2)} ₺',
                              style: TextStyle(color: onSurf, fontSize: 12),
                            ),
                            Text(
                              '${trade.holdDays} gün tutuldu',
                              style: TextStyle(color: sub, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${isPos ? '+' : ''}${trade.returnPct.toStringAsFixed(1)}%',
                        style: TextStyle(
                          color: clr,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Getiri bar chart
// ─────────────────────────────────────────────────────────────────────────────

class _TradeReturnChart extends StatelessWidget {
  final BacktestResult result;
  final bool isDark;

  const _TradeReturnChart({required this.result, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final theme  = Theme.of(context);
    final onSurf = theme.colorScheme.onSurface;
    final sub    = onSurf.withValues(alpha: 0.55);

    // 20'den fazla işlem varsa son 20'yi göster
    final trades = result.trades.length > 20
        ? result.trades.sublist(result.trades.length - 20)
        : result.trades;

    final winColor  = isDark ? const Color(0xFF34C759) : const Color(0xFF1B8A3C);
    final lossColor = isDark ? const Color(0xFFFF5252) : const Color(0xFFD32F2F);
    final zeroLine  = isDark
        ? Colors.white.withValues(alpha: 0.25)
        : Colors.black.withValues(alpha: 0.15);

    final bars = trades.asMap().entries.map((e) {
      final ret = e.value.returnPct;
      return BarChartGroupData(
        x: e.key,
        barRods: [
          BarChartRodData(
            toY: ret,
            color: ret >= 0 ? winColor : lossColor,
            width: 10,
            borderRadius: ret >= 0
                ? const BorderRadius.vertical(top: Radius.circular(4))
                : const BorderRadius.vertical(bottom: Radius.circular(4)),
          ),
        ],
      );
    }).toList();

    final maxAbs = trades
        .map((t) => t.returnPct.abs())
        .fold<double>(1.0, (a, b) => a > b ? a : b);
    final bound = (maxAbs * 1.25).ceilToDouble();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'İşlem Başına Getiri (%)',
            style: TextStyle(
              color: onSurf,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          if (result.trades.length > 20)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text('Son 20 işlem gösteriliyor',
                  style: TextStyle(color: sub, fontSize: 11)),
            ),
          const SizedBox(height: 16),
          SizedBox(
            height: 150,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: bound,
                minY: -bound,
                barGroups: bars,
                baselineY: 0,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: bound / 2,
                  getDrawingHorizontalLine: (val) => FlLine(
                    color: val == 0
                        ? zeroLine
                        : (isDark
                            ? Colors.white.withValues(alpha: 0.07)
                            : Colors.black.withValues(alpha: 0.06)),
                    strokeWidth: val == 0 ? 1.2 : 0.8,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  show: true,
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      interval: bound / 2,
                      getTitlesWidget: (val, _) => Text(
                        '${val.toInt()}%',
                        style: TextStyle(color: sub, fontSize: 10),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => isDark
                        ? const Color(0xFF2A2A2A)
                        : Colors.white,
                    tooltipRoundedRadius: 8,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final val = rod.toY;
                      return BarTooltipItem(
                        '${val >= 0 ? '+' : ''}${val.toStringAsFixed(1)}%',
                        TextStyle(
                          color: val >= 0 ? winColor : lossColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Yardımcı küçük widget'lar
// ─────────────────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool isDark;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final theme  = Theme.of(context);
    final onSurf = theme.colorScheme.onSurface;
    final sub    = onSurf.withValues(alpha: 0.55);

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: isDark ? 0.18 : 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value,
                      style: TextStyle(
                          color: onSurf,
                          fontSize: 15,
                          fontWeight: FontWeight.bold)),
                  Text(label,
                      style: TextStyle(color: sub, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  const _LegendDot({required this.color});

  @override
  Widget build(BuildContext context) => Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final bool isDark;
  const _SectionLabel({required this.label, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _ChipRow<T> extends StatelessWidget {
  final List<_Option<T>> options;
  final T selected;
  final void Function(T) onSelect;
  final bool isDark;

  const _ChipRow({
    required this.options,
    required this.selected,
    required this.onSelect,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: options.map((opt) {
        final isSel  = opt.value == selected;
        final selClr = const Color(0xFF34C759);
        final bg = isSel
            ? selClr
            : theme.colorScheme.surface;
        final fg = isSel
            ? Colors.white
            : theme.colorScheme.onSurface.withValues(alpha: 0.70);

        return Expanded(
          child: GestureDetector(
            onTap: () => onSelect(opt.value),
            child: Container(
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(vertical: 9),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(10),
                border: isSel
                    ? null
                    : Border.all(
                        color: theme.dividerColor.withValues(alpha: 0.5),
                      ),
              ),
              child: Center(
                child: Text(
                  opt.label,
                  style: TextStyle(
                    color: fg,
                    fontSize: 13,
                    fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _Option<T> {
  final String label;
  final T value;
  const _Option(this.label, this.value);
}

class _LoadingView extends StatelessWidget {
  final bool isDark;
  const _LoadingView({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final sub = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55);
    return SizedBox(
      height: 200,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Color(0xFF34C759), strokeWidth: 2.5),
          const SizedBox(height: 16),
          Text(
            'Tarihsel veriler analiz ediliyor...',
            style: TextStyle(color: sub, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            'Bu işlem birkaç saniye sürebilir',
            style: TextStyle(color: sub.withValues(alpha: 0.6), fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final bool isDark;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.isDark, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final sub = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55);
    return SizedBox(
      height: 180,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline_rounded,
              color: isDark ? const Color(0xFFFF5252) : const Color(0xFFD32F2F),
              size: 40),
          const SizedBox(height: 12),
          Text(message,
              style: TextStyle(color: sub, fontSize: 13),
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Tekrar Dene'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF34C759),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyTrades extends StatelessWidget {
  final bool isDark;
  const _EmptyTrades({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final sub = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55);
    return SizedBox(
      height: 180,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded,
              color: sub, size: 40),
          const SizedBox(height: 12),
          Text(
            'Bu dönemde sinyal oluşmadı',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Farklı dönem veya tutma süresi seçmeyi deneyin.',
            style: TextStyle(color: sub, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _PremiumGate extends StatelessWidget {
  final bool isDark;
  final VoidCallback onUpgrade;
  const _PremiumGate({required this.isDark, required this.onUpgrade});

  @override
  Widget build(BuildContext context) {
    final theme  = Theme.of(context);
    final onSurf = theme.colorScheme.onSurface;
    final sub    = onSurf.withValues(alpha: 0.60);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: theme.scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF34C759).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.science_rounded,
                color: Color(0xFF34C759),
                size: 38,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Strateji Backtest',
              style: TextStyle(
                color: onSurf,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Teknik sinyallerin geçmişte ne kadar doğru çalıştığını '
              'test etmek için Premium aboneliğe ihtiyaç var.',
              style: TextStyle(color: sub, fontSize: 14, height: 1.55),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onUpgrade,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF34C759),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13)),
                ),
                child: const Text('Premium\'a Geç',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
