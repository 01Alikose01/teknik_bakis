import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/asset_model.dart';
import 'bist_stocks.dart';
export 'bist_stocks.dart';

class StockService {
  static const String _baseUrl =
      'https://query1.finance.yahoo.com/v8/finance/chart';

  /// Günlük kotasyon: fiyat, OHLC ve değişim % tek kaynaktan.
  static _DailyQuote _extractDailyQuote(
    Map<String, dynamic> meta,
    List<double> closes,
    List<double> opens,
    List<double> highs,
    List<double> lows,
  ) {
    final price =
        (meta['regularMarketPrice'] as num?)?.toDouble() ??
        (closes.isNotEmpty ? closes.last : 0.0);

    final previousClose = _resolvePreviousClose(meta, closes, price);

    final open = _todayOpen(meta, opens);
    final high = _todayHigh(meta, highs, price);
    final low = _todayLow(meta, lows, price);

    final rawChangePercent = (meta['regularMarketChangePercent'] as num?)
        ?.toDouble();
    final fallbackChangePercent = previousClose != 0
        ? ((price - previousClose) / previousClose) * 100
        : 0.0;
    final changePercent = rawChangePercent ?? fallbackChangePercent;

    return _DailyQuote(
      price: price,
      open: open,
      high: high,
      low: low,
      previousClose: previousClose,
      changePercent: changePercent,
    );
  }

  static double _resolvePreviousClose(
    Map<String, dynamic> meta,
    List<double> closes,
    double price,
  ) {
    final fromMeta = (meta['previousClose'] as num?)?.toDouble();
    if (fromMeta != null && fromMeta > 0) return fromMeta;
    if (closes.isEmpty) return price;

    final lastClose = closes.last;
    final priceIncluded = (lastClose - price).abs() < 0.0001;
    if (priceIncluded && closes.length >= 2) {
      return closes[closes.length - 2];
    }
    return lastClose;
  }

  static double _todayOpen(Map<String, dynamic> meta, List<double> opens) {
    if (opens.isNotEmpty && opens.last > 0) return opens.last;
    return (meta['regularMarketOpen'] as num?)?.toDouble() ?? 0.0;
  }

  static double _todayHigh(
    Map<String, dynamic> meta,
    List<double> highs,
    double price,
  ) {
    final fromMeta = (meta['regularMarketDayHigh'] as num?)?.toDouble();
    if (fromMeta != null && fromMeta > 0) return fromMeta;
    if (highs.isNotEmpty && highs.last > 0) return highs.last;
    return price;
  }

  static double _todayLow(
    Map<String, dynamic> meta,
    List<double> lows,
    double price,
  ) {
    final fromMeta = (meta['regularMarketDayLow'] as num?)?.toDouble();
    if (fromMeta != null && fromMeta > 0) return fromMeta;
    if (lows.isNotEmpty && lows.last > 0) return lows.last;
    return price;
  }

  static List<double> _toDoubleList(List? raw, {bool dropNulls = false}) {
    if (raw == null) return [];
    if (dropNulls) {
      return raw
          .where((e) => e != null)
          .map<double>((e) => (e as num).toDouble())
          .toList();
    }
    return raw
        .map<double>((e) => e != null ? (e as num).toDouble() : 0.0)
        .toList();
  }

  static Future<Map<String, dynamic>?> _fetchChartJson(
    String yahooSymbol,
    String range, {
    String interval = '1d',
  }) async {
    try {
      final url = Uri.parse(
        '$_baseUrl/$yahooSymbol?interval=$interval&range=$range',
      );
      final response = await http
          .get(url, headers: {'User-Agent': 'Mozilla/5.0'})
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body);
      final result = data['chart']?['result'];
      if (result == null || result.isEmpty) return null;
      return result[0] as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> _fetchQuoteSummaryJson(
    String yahooSymbol, {
    String modules = 'financialData,defaultKeyStatistics',
  }) async {
    try {
      final url = Uri.parse(
        'https://query1.finance.yahoo.com/v10/finance/quoteSummary/$yahooSymbol?modules=$modules',
      );
      final response = await http
          .get(url, headers: {'User-Agent': 'Mozilla/5.0'})
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static double _parseYahooRawValue(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    if (value is Map<String, dynamic>) {
      final raw = value['raw'];
      if (raw is num) return raw.toDouble();
    }
    return 0;
  }

  static Map<String, double> _extractFundamentals(
    Map<String, dynamic>? summaryJson,
  ) {
    if (summaryJson == null) return {'pdDd': 0, 'fk': 0};
    final result = (summaryJson['quoteSummary']?['result'] as List?)?.first;
    if (result == null) return {'pdDd': 0, 'fk': 0};

    final financialData = result['financialData'] as Map<String, dynamic>?;
    final defaultKeyStats =
        result['defaultKeyStatistics'] as Map<String, dynamic>?;

    final pdDd = _parseYahooRawValue(
      financialData?['priceToBook'] ?? defaultKeyStats?['priceToBook'],
    );
    final trailingPe = _parseYahooRawValue(
      financialData?['trailingPE'] ?? defaultKeyStats?['trailingPE'],
    );
    final forwardPe = _parseYahooRawValue(
      financialData?['forwardPE'] ?? defaultKeyStats?['forwardPE'],
    );
    final fk = trailingPe > 0
        ? trailingPe
        : forwardPe > 0
        ? forwardPe
        : 0.0;

    return {'pdDd': pdDd, 'fk': fk};
  }

  static AssetModel? _assetFromChart(
    Map<String, dynamic> chartResult, {
    required String symbol,
    required String name,
    double pdDd = 0,
    double fk = 0,
  }) {
    final meta = chartResult['meta'] as Map<String, dynamic>;
    final quote = chartResult['indicators']?['quote']?[0];
    if (quote == null) return null;

    final closes = _toDoubleList(quote['close'] as List?, dropNulls: true);
    if (closes.isEmpty) return null;

    final opens = _toDoubleList(quote['open'] as List?);
    final highs = _toDoubleList(quote['high'] as List?);
    final lows = _toDoubleList(quote['low'] as List?);
    final volumes = _toDoubleList(quote['volume'] as List?, dropNulls: true);

    final q = _extractDailyQuote(meta, closes, opens, highs, lows);

    final allPrices = [...closes];
    if (allPrices.last != q.price) allPrices.add(q.price);

    return AssetModel(
      symbol: symbol,
      name: name,
      price: q.price,
      changePercent: q.changePercent,
      previousClose: q.previousClose,
      open: q.open,
      high: q.high,
      low: q.low,
      prices: allPrices,
      opens: opens,
      highs: highs,
      lows: lows,
      volumes: volumes.isNotEmpty
          ? volumes
          : List<double>.filled(allPrices.length, 0),
    );
  }

  static Future<AssetModel?> fetchStock(
    String symbol, {
    String period = '3mo',
    String interval = '1d',
  }) async {
    try {
      final chartFuture = _fetchChartJson(
        '$symbol.IS',
        period,
        interval: interval,
      );
      final summaryFuture = _fetchQuoteSummaryJson('$symbol.IS');
      final results = await Future.wait([chartFuture, summaryFuture]);

      final chart = results[0];
      final quoteSummary = results[1];
      if (chart == null) return null;

      final fundamentals = _extractFundamentals(quoteSummary);
      final stock = kBistStocks.firstWhere(
        (s) => s['symbol'] == symbol,
        orElse: () => {'symbol': symbol, 'name': symbol},
      );

      return _assetFromChart(
        chart,
        symbol: symbol,
        name: stock['name'] ?? symbol,
        pdDd: fundamentals['pdDd'] ?? 0,
        fk: fundamentals['fk'] ?? 0,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<List<AssetModel>> fetchMultiple(
    List<String> symbols, {
    String period = '3mo',
    String interval = '1d',
    void Function(int done, int total)? onProgress,
  }) async {
    final results = <AssetModel>[];
    const batchSize = 12;
    int done = 0;

    for (int i = 0; i < symbols.length; i += batchSize) {
      final batch = symbols.skip(i).take(batchSize).toList();
      final batchResults = await Future.wait(
        batch.map(
          (symbol) => fetchStock(symbol, period: period, interval: interval),
        ),
      );

      for (final asset in batchResults) {
        if (asset != null) results.add(asset);
        done++;
        onProgress?.call(done, symbols.length);
      }

      if (i + batchSize < symbols.length) {
        await Future.delayed(const Duration(milliseconds: 120));
      }
    }
    return results;
  }

  static Future<AssetModel?> fetchGold() async {
    try {
      final chart = await _fetchChartJson('GC%3DF', '3mo');
      if (chart == null) return null;
      return _assetFromChart(chart, symbol: 'ALTIN', name: 'Altın (USD/oz)');
    } catch (_) {
      return null;
    }
  }

  static Future<AssetModel?> fetchDollar() async {
    try {
      final chart = await _fetchChartJson('USDTRY%3DX', '3mo');
      if (chart == null) return null;
      return _assetFromChart(chart, symbol: 'DOLAR', name: 'Dolar/TL');
    } catch (_) {
      return null;
    }
  }

  static Future<AssetModel?> fetchIndex(
    String yahooSymbol,
    String displaySymbol,
    String name,
  ) async {
    try {
      final chart = await _fetchChartJson(yahooSymbol, '5d');
      if (chart == null) return null;
      return _assetFromChart(chart, symbol: displaySymbol, name: name);
    } catch (_) {
      return null;
    }
  }

  static Future<AssetModel?> fetchGoldGram() async {
    try {
      final results = await Future.wait([
        _fetchSpot('GC%3DF'),
        _fetchSpot('USDTRY%3DX'),
      ]);
      final goldUsd = results[0];
      final usdTry = results[1];
      if (goldUsd == null || usdTry == null) return null;
      final gramPrice = (goldUsd['price']! / 31.1035) * usdTry['price']!;
      final prevGram = (goldUsd['prev']! / 31.1035) * usdTry['prev']!;
      final change = prevGram != 0
          ? ((gramPrice - prevGram) / prevGram) * 100
          : (goldUsd['changePercent']! + usdTry['changePercent']!);
      return AssetModel(
        symbol: 'ALTIN/GR',
        name: 'Gram Altın (₺)',
        price: gramPrice,
        changePercent: change,
        previousClose: prevGram,
        open:
            ((goldUsd['open'] ?? goldUsd['price'])! / 31.1035) *
            (usdTry['open'] ?? usdTry['price'])!,
        high:
            ((goldUsd['high'] ?? goldUsd['price'])! / 31.1035) *
            (usdTry['high'] ?? usdTry['price'])!,
        low:
            ((goldUsd['low'] ?? goldUsd['price'])! / 31.1035) *
            (usdTry['low'] ?? usdTry['price'])!,
        prices: [],
        volumes: [],
      );
    } catch (_) {
      return null;
    }
  }

  static Future<AssetModel?> fetchSilverGram() async {
    try {
      final results = await Future.wait([
        _fetchSpot('SI%3DF'),
        _fetchSpot('USDTRY%3DX'),
      ]);
      final silverUsd = results[0];
      final usdTry = results[1];
      if (silverUsd == null || usdTry == null) return null;
      final gramPrice = (silverUsd['price']! / 31.1035) * usdTry['price']!;
      final prevGram = (silverUsd['prev']! / 31.1035) * usdTry['prev']!;
      final change = prevGram != 0
          ? ((gramPrice - prevGram) / prevGram) * 100
          : (silverUsd['changePercent']! + usdTry['changePercent']!);
      return AssetModel(
        symbol: 'GUMUS/GR',
        name: 'Gram Gümüş (₺)',
        price: gramPrice,
        changePercent: change,
        previousClose: prevGram,
        open:
            ((silverUsd['open'] ?? silverUsd['price'])! / 31.1035) *
            (usdTry['open'] ?? usdTry['price'])!,
        high:
            ((silverUsd['high'] ?? silverUsd['price'])! / 31.1035) *
            (usdTry['high'] ?? usdTry['price'])!,
        low:
            ((silverUsd['low'] ?? silverUsd['price'])! / 31.1035) *
            (usdTry['low'] ?? usdTry['price'])!,
        prices: [],
        volumes: [],
      );
    } catch (_) {
      return null;
    }
  }

  static Future<AssetModel?> _fetchMetalTl({
    required String yahooSymbol,
    required String symbol,
    required String name,
  }) async {
    try {
      final results = await Future.wait([
        _fetchSpot(yahooSymbol),
        _fetchSpot('USDTRY%3DX'),
      ]);
      final metalUsd = results[0];
      final usdTry = results[1];
      if (metalUsd == null || usdTry == null) return null;

      final gramPrice = (metalUsd['price']! / 31.1035) * usdTry['price']!;
      final prevGram = (metalUsd['prev']! / 31.1035) * usdTry['prev']!;
      final change = prevGram != 0
          ? ((gramPrice - prevGram) / prevGram) * 100
          : (metalUsd['changePercent']! + usdTry['changePercent']!);

      return AssetModel(
        symbol: symbol,
        name: name,
        price: gramPrice,
        changePercent: change,
        previousClose: prevGram,
        open:
            ((metalUsd['open'] ?? metalUsd['price'])! / 31.1035) *
            (usdTry['open'] ?? usdTry['price'])!,
        high:
            ((metalUsd['high'] ?? metalUsd['price'])! / 31.1035) *
            (usdTry['high'] ?? usdTry['price'])!,
        low:
            ((metalUsd['low'] ?? metalUsd['price'])! / 31.1035) *
            (usdTry['low'] ?? usdTry['price'])!,
        prices: [],
        volumes: [],
      );
    } catch (_) {
      return null;
    }
  }

  static Future<AssetModel?> fetchSilverTl() => _fetchMetalTl(
    yahooSymbol: 'SI%3DF',
    symbol: 'GUMUS/TL',
    name: 'Gümüş/TL',
  );

  static Future<AssetModel?> fetchPalladiumTl() => _fetchMetalTl(
    yahooSymbol: 'PA%3DF',
    symbol: 'PALADYUM/TL',
    name: 'Paladyum/TL',
  );

  static Future<AssetModel?> fetchPlatinumTl() => _fetchMetalTl(
    yahooSymbol: 'PL%3DF',
    symbol: 'PLATIN/TL',
    name: 'Platin/TL',
  );

  static Future<AssetModel?> fetchEuro() async {
    try {
      final spot = await _fetchSpot('EURTRY%3DX');
      if (spot == null) return null;
      return AssetModel(
        symbol: 'EURO',
        name: 'Euro/TL',
        price: spot['price']!,
        changePercent: spot['changePercent']!,
        previousClose: spot['prev']!,
        open: spot['open'] ?? spot['price']!,
        high: spot['high'] ?? spot['price']!,
        low: spot['low'] ?? spot['price']!,
        prices: [],
        volumes: [],
      );
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, double>?> _fetchSpot(String yahooSymbol) async {
    try {
      final chart = await _fetchChartJson(yahooSymbol, '5d');
      if (chart == null) return null;

      final meta = chart['meta'] as Map<String, dynamic>;
      final quote = chart['indicators']?['quote']?[0];
      final closes = _toDoubleList(quote?['close'] as List?, dropNulls: true);
      final opens = _toDoubleList(quote?['open'] as List?);
      final highs = _toDoubleList(quote?['high'] as List?);
      final lows = _toDoubleList(quote?['low'] as List?);

      if (closes.isEmpty) return null;

      final q = _extractDailyQuote(meta, closes, opens, highs, lows);

      return {
        'price': q.price,
        'prev': q.previousClose,
        'changePercent': q.changePercent,
        'open': q.open,
        'high': q.high,
        'low': q.low,
      };
    } catch (_) {
      return null;
    }
  }
}

class _DailyQuote {
  final double price;
  final double open;
  final double high;
  final double low;
  final double previousClose;
  final double changePercent;

  const _DailyQuote({
    required this.price,
    required this.open,
    required this.high,
    required this.low,
    required this.previousClose,
    required this.changePercent,
  });
}
