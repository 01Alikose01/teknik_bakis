import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/asset_model.dart';

class StockChart extends StatelessWidget {
  final AssetModel asset;
  final Set<String> activeIndicators;
  final bool showCandles;

  const StockChart({
    super.key,
    required this.asset,
    required this.activeIndicators,
    this.showCandles = false,
  });

  @override
  Widget build(BuildContext context) {
    final prices = asset.prices;
    if (prices.isEmpty) {
      return const SizedBox(
        height: 160,
        child: Center(child: Text('Veri yok', style: TextStyle(color: Colors.grey))),
      );
    }

    final showEma20 = activeIndicators.contains('EMA 20');
    final showEma50 = activeIndicators.contains('EMA 50');
    final showSupertrend = activeIndicators.contains('Supertrend');
    final showRsi = activeIndicators.contains('RSI 30');
    final showMacd = activeIndicators.contains('MACD');

    final ema20 = showEma20 ? asset.ema(20) : <double>[];
    final ema50 = showEma50 ? asset.ema(50) : <double>[];
    final rsiValues = showRsi ? asset.rsi() : <double>[];
    final macdData = showMacd ? asset.macd() : <String, List<double>>{};
    final stData = showSupertrend ? asset.supertrend() : <String, List<double>>{};

    final priceSpots = List.generate(prices.length, (i) => FlSpot(i.toDouble(), prices[i]));
    final minPrice = prices.reduce((a, b) => a < b ? a : b) * 0.97;
    final maxPrice = prices.reduce((a, b) => a > b ? a : b) * 1.03;

    final lineBars = <LineChartBarData>[
      // Fiyat
      LineChartBarData(
        spots: priceSpots,
        isCurved: true,
        color: const Color(0xFF00C853),
        barWidth: 2,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(
          show: true,
          color: const Color(0xFF00C853).withValues(alpha: 0.08),
        ),
      ),
    ];

    if (showEma20 && ema20.isNotEmpty) {
      final offset = prices.length - ema20.length;
      lineBars.add(LineChartBarData(
        spots: List.generate(ema20.length, (i) => FlSpot((i + offset).toDouble(), ema20[i])),
        isCurved: true,
        color: const Color(0xFF1E88E5),
        barWidth: 1.5,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(show: false),
      ));
    }

    if (showEma50 && ema50.isNotEmpty) {
      final offset = prices.length - ema50.length;
      lineBars.add(LineChartBarData(
        spots: List.generate(ema50.length, (i) => FlSpot((i + offset).toDouble(), ema50[i])),
        isCurved: true,
        color: const Color(0xFFFF6F00),
        barWidth: 1.5,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(show: false),
      ));
    }

    // Supertrend çizgisi
    List<FlSpot> stBullSpots = [];
    List<FlSpot> stBearSpots = [];
    if (showSupertrend && stData['trend'] != null && stData['trend']!.isNotEmpty) {
      final trend = stData['trend']!;
      final dir = stData['direction']!;
      final offset = prices.length - trend.length;
      for (int i = 0; i < trend.length; i++) {
        final spot = FlSpot((i + offset).toDouble(), trend[i]);
        if (dir[i] == 1) {
          stBullSpots.add(spot);
        } else {
          stBearSpots.add(spot);
        }
      }
      if (stBullSpots.isNotEmpty) {
        lineBars.add(LineChartBarData(
          spots: stBullSpots,
          isCurved: false,
          color: const Color(0xFF00C853),
          barWidth: 2,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(show: false),
          dashArray: [4, 4],
        ));
      }
      if (stBearSpots.isNotEmpty) {
        lineBars.add(LineChartBarData(
          spots: stBearSpots,
          isCurved: false,
          color: const Color(0xFFE53935),
          barWidth: 2,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(show: false),
          dashArray: [4, 4],
        ));
      }
    }

    final legendItems = <_Legend>[
      const _Legend(color: Color(0xFF00C853), label: 'Fiyat'),
      if (showEma20) const _Legend(color: Color(0xFF1E88E5), label: 'EMA20'),
      if (showEma50) const _Legend(color: Color(0xFFFF6F00), label: 'EMA50'),
      if (showSupertrend) ...[
        const _Legend(color: Color(0xFF00C853), label: 'ST Al'),
        const _Legend(color: Color(0xFFE53935), label: 'ST Sat'),
      ],
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 200,
          child: showCandles
              ? _CandleChart(asset: asset)
              : LineChart(
                  LineChartData(
                    minY: minPrice,
                    maxY: maxPrice,
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: (maxPrice - minPrice) / 4,
                      getDrawingHorizontalLine: (_) =>
                          const FlLine(color: Colors.white10, strokeWidth: 1),
                    ),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      show: true,
                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 52,
                          getTitlesWidget: (value, meta) => Text(
                            value.toStringAsFixed(1),
                            style: const TextStyle(color: Colors.grey, fontSize: 9),
                          ),
                        ),
                      ),
                    ),
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipColor: (_) => const Color(0xFF333355),
                      ),
                    ),
                    lineBarsData: lineBars,
                  ),
                ),
        ),
        if (asset.volumes.isNotEmpty) ...[
          const SizedBox(height: 4),
          _VolumeChart(volumes: asset.volumes),
        ],
        if (!showCandles && legendItems.length > 1) ...[
          const SizedBox(height: 6),
          Wrap(spacing: 12, runSpacing: 4, children: legendItems),
        ],
        if (rsiValues.isNotEmpty) ...[
          const SizedBox(height: 12),
          _SectionLabel(label: 'RSI (14)', color: const Color(0xFFAB47BC)),
          const SizedBox(height: 4),
          _RsiChart(rsiValues: rsiValues),
        ],
        if (macdData.isNotEmpty && (macdData['macd']?.isNotEmpty ?? false)) ...[
          const SizedBox(height: 12),
          _SectionLabel(label: 'MACD (12,26,9)', color: const Color(0xFFFFB300)),
          const SizedBox(height: 4),
          _MacdChart(macdData: macdData),
        ],
      ],
    );
  }
}

class _CandleChart extends StatelessWidget {
  final AssetModel asset;
  const _CandleChart({required this.asset});

  @override
  Widget build(BuildContext context) {
    final count = [
      asset.prices.length,
      asset.opens.length,
      asset.highs.length,
      asset.lows.length,
    ].reduce((a, b) => a < b ? a : b);

    if (count <= 0) {
      return const SizedBox(
        height: 200,
        child: Center(child: Text('Mum verisi yok', style: TextStyle(color: Colors.grey))),
      );
    }

    final highs = asset.highs.take(count).toList();
    final lows = asset.lows.take(count).toList();
    final opens = asset.opens.take(count).toList();
    final closes = asset.prices.take(count).toList();

    final minY = lows.reduce((a, b) => a < b ? a : b) * 0.995;
    final maxY = highs.reduce((a, b) => a > b ? a : b) * 1.005;
    final range = maxY - minY;

    final barGroups = List.generate(count, (i) {
      final open = opens[i];
      final close = closes[i];
      final high = highs[i];
      final low = lows[i];
      final isUp = close >= open;
      final bodyTop = isUp ? close : open;
      final bodyBottom = isUp ? open : close;

      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            fromY: low,
            toY: high,
            color: isUp ? const Color(0xFF00C853) : const Color(0xFFE53935),
            width: 1.2,
            borderRadius: BorderRadius.zero,
          ),
          BarChartRodData(
            fromY: bodyBottom,
            toY: bodyTop,
            color: isUp ? const Color(0xFF00C853) : const Color(0xFFE53935),
            width: 8,
            borderRadius: BorderRadius.circular(2),
          ),
        ],
      );
    });

    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          minY: minY == maxY ? minY - 1 : minY,
          maxY: maxY == minY ? maxY + 1 : maxY,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: range == 0 ? 1 : range / 4,
            getDrawingHorizontalLine: (_) => const FlLine(color: Colors.white10, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            show: true,
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 52,
                getTitlesWidget: (value, meta) => Text(
                  value.toStringAsFixed(1),
                  style: const TextStyle(color: Colors.grey, fontSize: 9),
                ),
              ),
            ),
          ),
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => const Color(0xFF333355),
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final idx = group.x.toInt();
                final open = opens[idx];
                final high = highs[idx];
                final low = lows[idx];
                final close = closes[idx];
                return BarTooltipItem(
                  'O: ${open.toStringAsFixed(2)}\nH: ${high.toStringAsFixed(2)}\nL: ${low.toStringAsFixed(2)}\nC: ${close.toStringAsFixed(2)}',
                  const TextStyle(color: Colors.white, fontSize: 11),
                );
              },
            ),
          ),
          barGroups: barGroups,
        ),
      ),
    );
  }
}

class _VolumeChart extends StatelessWidget {
  final List<double> volumes;
  const _VolumeChart({required this.volumes});

  @override
  Widget build(BuildContext context) {
    final maxVol = volumes.reduce((a, b) => a > b ? a : b);
    return SizedBox(
      height: 40,
      child: BarChart(
        BarChartData(
          maxY: maxVol * 1.2,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: const FlTitlesData(show: false),
          barTouchData: BarTouchData(enabled: false),
          barGroups: List.generate(volumes.length, (i) {
            return BarChartGroupData(x: i, barRods: [
              BarChartRodData(
                toY: volumes[i],
                color: const Color(0xFF00C853).withValues(alpha: 0.5),
                width: 4,
                borderRadius: BorderRadius.circular(1),
              ),
            ]);
          }),
        ),
      ),
    );
  }
}

class _RsiChart extends StatelessWidget {
  final List<double> rsiValues;
  const _RsiChart({required this.rsiValues});

  @override
  Widget build(BuildContext context) {
    final spots = List.generate(rsiValues.length, (i) => FlSpot(i.toDouble(), rsiValues[i]));
    return SizedBox(
      height: 80,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: 100,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 30,
            getDrawingHorizontalLine: (v) => FlLine(
              color: v == 30 || v == 70 ? Colors.white24 : Colors.white10,
              strokeWidth: v == 30 || v == 70 ? 1 : 0.5,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            show: true,
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: 30,
                getTitlesWidget: (value, meta) {
                  if (value == 30 || value == 70) {
                    return Text(value.toInt().toString(),
                        style: const TextStyle(color: Colors.grey, fontSize: 9));
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => const Color(0xFF333355),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: const Color(0xFFAB47BC),
              barWidth: 1.5,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(show: false),
            ),
          ],
        ),
      ),
    );
  }
}

class _MacdChart extends StatelessWidget {
  final Map<String, List<double>> macdData;
  const _MacdChart({required this.macdData});

  @override
  Widget build(BuildContext context) {
    final macdLine = macdData['macd'] ?? [];
    final signal = macdData['signal'] ?? [];
    final hist = macdData['hist'] ?? [];
    if (macdLine.isEmpty) return const SizedBox.shrink();

    final allVals = [...macdLine, ...signal];
    final minY = allVals.reduce((a, b) => a < b ? a : b) * 1.2;
    final maxY = allVals.reduce((a, b) => a > b ? a : b) * 1.2;
    final sigOffset = macdLine.length - signal.length;
    final histOffset = macdLine.length - hist.length;

    final macdSpots = List.generate(macdLine.length, (i) => FlSpot(i.toDouble(), macdLine[i]));
    final signalSpots = List.generate(signal.length, (i) => FlSpot((i + sigOffset).toDouble(), signal[i]));
    final histGroups = List.generate(hist.length, (i) {
      final val = hist[i];
      return BarChartGroupData(x: i + histOffset, barRods: [
        BarChartRodData(
          toY: val,
          color: val >= 0
              ? const Color(0xFF00C853).withValues(alpha: 0.7)
              : const Color(0xFFE53935).withValues(alpha: 0.7),
          width: 4,
          borderRadius: BorderRadius.circular(1),
        ),
      ]);
    });

    return SizedBox(
      height: 80,
      child: Stack(children: [
        BarChart(BarChartData(
          minY: minY,
          maxY: maxY,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: const FlTitlesData(show: false),
          barTouchData: BarTouchData(enabled: false),
          barGroups: histGroups,
        )),
        LineChart(LineChartData(
          minY: minY,
          maxY: maxY,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: (maxY - minY) / 2,
            getDrawingHorizontalLine: (_) => const FlLine(color: Colors.white10, strokeWidth: 0.5),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            show: true,
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (v, m) => Text(v.toStringAsFixed(1),
                    style: const TextStyle(color: Colors.grey, fontSize: 9)),
              ),
            ),
          ),
          lineTouchData: const LineTouchData(enabled: false),
          lineBarsData: [
            LineChartBarData(
              spots: macdSpots,
              isCurved: false,
              color: const Color(0xFFFFB300),
              barWidth: 1.5,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(show: false),
            ),
            LineChartBarData(
              spots: signalSpots,
              isCurved: false,
              color: const Color(0xFFE53935),
              barWidth: 1,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(show: false),
            ),
          ],
        )),
      ]),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final Color color;
  const _SectionLabel({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
    ]);
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 12, height: 2, color: color),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10)),
    ]);
  }
}
