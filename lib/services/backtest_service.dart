import '../models/asset_model.dart';
import 'stock_service.dart';

/// Tek bir backtest işleminin sonucunu taşır.
class BacktestTrade {
  final int entryIndex;     // Sinyal gününün indeksi (prices listesinde)
  final double entryPrice;  // Alış fiyatı
  final double exitPrice;   // Satış fiyatı
  final int holdDays;       // Kaç gün tutuldu
  final double returnPct;   // Getiri yüzdesi

  const BacktestTrade({
    required this.entryIndex,
    required this.entryPrice,
    required this.exitPrice,
    required this.holdDays,
    required this.returnPct,
  });

  bool get isWin => returnPct >= 0;
}

/// Tüm backtest sonucunu özetler.
class BacktestResult {
  final String symbol;
  final String signalId;
  final String signalLabel;
  final String period;        // "1y" / "2y" / "6mo"
  final int holdDays;         // Tutma süresi (gün)
  final List<BacktestTrade> trades;

  const BacktestResult({
    required this.symbol,
    required this.signalId,
    required this.signalLabel,
    required this.period,
    required this.holdDays,
    required this.trades,
  });

  int get totalTrades => trades.length;
  int get winTrades   => trades.where((t) => t.isWin).length;
  int get lossTrades  => trades.where((t) => !t.isWin).length;

  double get winRate =>
      totalTrades == 0 ? 0 : (winTrades / totalTrades) * 100;

  double get avgReturn =>
      trades.isEmpty
          ? 0
          : trades.map((t) => t.returnPct).reduce((a, b) => a + b) / trades.length;

  double get bestReturn =>
      trades.isEmpty ? 0 : trades.map((t) => t.returnPct).reduce((a, b) => a > b ? a : b);

  double get worstReturn =>
      trades.isEmpty ? 0 : trades.map((t) => t.returnPct).reduce((a, b) => a < b ? a : b);

  double get avgHoldDays =>
      trades.isEmpty
          ? holdDays.toDouble()
          : trades.map((t) => t.holdDays).reduce((a, b) => a + b) / trades.length;

  /// Kümülatif getiri (tüm trade'lerin zincirleme çarpımı)
  double get cumulativeReturn {
    if (trades.isEmpty) return 0;
    double factor = 1.0;
    for (final t in trades) {
      factor *= (1 + t.returnPct / 100);
    }
    return (factor - 1) * 100;
  }
}

class BacktestService {
  /// Verilen sinyal için tarihsel backtest çalıştırır.
  ///
  /// [symbol]    — BIST hisse sembolü (örn. "THYAO")
  /// [signalId]  — scanner_screen'deki filtre ID'si (örn. "MACD Bullish")
  /// [period]    — Yahoo Finance range ("6mo", "1y", "2y")
  /// [holdDays]  — sinyal sonrası kaç gün tutulacak (varsayılan: 5)
  static Future<BacktestResult?> run({
    required String symbol,
    required String signalId,
    required String signalLabel,
    String period = '1y',
    int holdDays = 5,
  }) async {
    // 2 yıllık günlük veri çek
    final asset = await StockService.fetchStock(
      symbol,
      period: period,
      interval: '1d',
    );
    if (asset == null || asset.prices.length < 60) return null;

    final trades  = <BacktestTrade>[];
    final prices  = asset.prices;

    // Her gün için sinyal hesapla — window kaydırmalı
    // Minimum 50 bar geçmişe ihtiyaç var (EMA50 için)
    const minHistory = 60;
    int i = minHistory;

    while (i < prices.length - holdDays) {
      // O güne kadar olan veriyle geçici bir AssetModel oluştur
      final slice = _sliceAsset(asset, i + 1);
      final signalFired = _checkSignal(slice, signalId);

      if (signalFired) {
        final entryPrice = prices[i];
        final exitPrice  = prices[i + holdDays];
        if (entryPrice > 0 && exitPrice > 0) {
          final ret = ((exitPrice - entryPrice) / entryPrice) * 100;
          trades.add(BacktestTrade(
            entryIndex: i,
            entryPrice: entryPrice,
            exitPrice: exitPrice,
            holdDays: holdDays,
            returnPct: ret,
          ));
        }
        // Aynı sinyal tekrar tetiklenmesin — holdDays kadar atla
        i += holdDays;
      } else {
        i++;
      }
    }

    return BacktestResult(
      symbol: symbol,
      signalId: signalId,
      signalLabel: signalLabel,
      period: period,
      holdDays: holdDays,
      trades: trades,
    );
  }

  /// AssetModel'i verilen index'e kadar keser (pencere kaydırma için)
  static AssetModel _sliceAsset(AssetModel a, int end) {
    final p = a.prices.sublist(0, end);
    final v = a.volumes.length >= end ? a.volumes.sublist(0, end) : a.volumes;
    final o = a.opens.length >= end  ? a.opens.sublist(0, end)   : a.opens;
    final h = a.highs.length >= end  ? a.highs.sublist(0, end)   : a.highs;
    final l = a.lows.length >= end   ? a.lows.sublist(0, end)    : a.lows;

    return AssetModel(
      symbol: a.symbol,
      name: a.name,
      price: p.last,
      changePercent: 0,
      previousClose: p.length >= 2 ? p[p.length - 2] : p.last,
      open: o.isNotEmpty ? o.last : p.last,
      high: h.isNotEmpty ? h.last : p.last,
      low:  l.isNotEmpty ? l.last : p.last,
      prices:  p,
      volumes: v,
      opens:   o,
      highs:   h,
      lows:    l,
    );
  }

  /// Sinyali AssetModel üzerinde kontrol eder
  static bool _checkSignal(AssetModel a, String signalId) {
    switch (signalId) {
      case 'MACD Bullish':        return a.isMacdBullish;
      case 'MACD Bear':           return a.isMacdBearish;
      case 'Golden Cross':        return a.isGoldenCross;
      case 'Death Cross':         return a.isDeathCross;
      case 'RSI 40':              return a.isRsiBelow40;
      case 'RSI_TEPE':            return a.isRsiAbove70;
      case 'Supertrend AL':       return a.isSupertrendBuy;
      case 'Supertrend SAT':      return a.isSupertrendSell;
      case 'HACIMLENEN DİP':      return a.isVolumeDip;
      case 'POZITIF_UYUMSUZLUK':  return a.isBullishDivergence;
      case 'BEARISH_DIV':         return a.isBearishDivergence;
      case 'BB SIKIŞMA':          return a.isBollingerSqueeze;
      case 'EMA20 > EMA50':       return a.isEma20AboveEma50WithMargin;
      case 'MA50 = MA200':        return a.isPriceAboveMa50AndMa200;
      case 'HACIM_KIRILIM':       return a.isVolumeBreakout;
      case 'DONCHIAN_20':         return a.isDonchian20Breakout;
      case 'TOBO_AL':             return a.isToboPattern;
      case 'ALCALAN_UCGEN':       return a.isAscendingTriangleBuy;
      case 'ASC_TRIANGLE':        return a.isAscendingTriangleSell;
      case 'Hammer':              return a.isHammer;
      case 'Doji':                return a.isDoji;
      case 'Morning Star':        return a.isMorningStar;
      case 'Bullish Engulfing':   return a.isBullishEngulfing;
      case 'Bearish Engulfing':   return a.isBearishEngulfing;
      case 'KISA VADE TRADE':     return a.isKisaVadeTrade;
      case 'DEGER_FILTRESI':      return a.isValueStock;
      default:                    return false;
    }
  }

  /// Periyot etiketleri
  static String periodLabel(String period) {
    switch (period) {
      case '6mo': return '6 Ay';
      case '1y':  return '1 Yıl';
      case '2y':  return '2 Yıl';
      default:    return period;
    }
  }

  /// Tutma süresi etiketleri
  static String holdLabel(int days) {
    if (days == 1)  return '1 Gün';
    if (days == 3)  return '3 Gün';
    if (days == 5)  return '5 Gün';
    if (days == 10) return '10 Gün';
    if (days == 20) return '20 Gün';
    return '$days Gün';
  }
}
