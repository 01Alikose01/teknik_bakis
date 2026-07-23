import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/asset_model.dart';
import 'bist_stocks.dart';
export 'bist_stocks.dart';

class StockService {
  static const String _baseUrl =
      'https://query1.finance.yahoo.com/v8/finance/chart';

  // Tek hisse güncel fiyat + tarihsel veri
  static Future<AssetModel?> fetchStock(String symbol,
      {String period = '3mo'}) async {
    try {
      final yahooSymbol = '$symbol.IS';
      final url = Uri.parse('$_baseUrl/$yahooSymbol?interval=1d&range=$period');
      final response = await http
          .get(url, headers: {'User-Agent': 'Mozilla/5.0'})
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body);
      final result = data['chart']?['result'];
      if (result == null || result.isEmpty) return null;

      final meta = result[0]['meta'];
      final closePrices =
          result[0]['indicators']?['quote']?[0]?['close'] as List?;
      final openPrices =
          result[0]['indicators']?['quote']?[0]?['open'] as List?;
      final highPrices =
          result[0]['indicators']?['quote']?[0]?['high'] as List?;
      final lowPrices =
          result[0]['indicators']?['quote']?[0]?['low'] as List?;
      final volumeData =
          result[0]['indicators']?['quote']?[0]?['volume'] as List?;
      if (closePrices == null || closePrices.isEmpty) return null;

      final prices = closePrices
          .where((e) => e != null)
          .map<double>((e) => (e as num).toDouble())
          .toList();

      final opens = openPrices != null
          ? openPrices.map<double>((e) => e != null ? (e as num).toDouble() : 0.0).toList()
          : <double>[];
      final highs = highPrices != null
          ? highPrices.map<double>((e) => e != null ? (e as num).toDouble() : 0.0).toList()
          : <double>[];
      final lows = lowPrices != null
          ? lowPrices.map<double>((e) => e != null ? (e as num).toDouble() : 0.0).toList()
          : <double>[];

      final volumes = volumeData != null
          ? volumeData
              .where((e) => e != null)
              .map<double>((e) => (e as num).toDouble())
              .toList()
          : List<double>.filled(prices.length, 0);

      final currentPrice =
          (meta['regularMarketPrice'] as num?)?.toDouble() ?? prices.last;

      // Bir önceki günün kapanış fiyatı — değişim hesabı için kullanılır
      final prevClose =
          (meta['previousClose'] as num?)?.toDouble() ??
          (meta['chartPreviousClose'] as num?)?.toDouble();

      // Yahoo'nun anlık günlük değişim yüzdesi (önceki kapanışa göre)
      final directChangePct =
          (meta['regularMarketChangePercent'] as num?)?.toDouble();

      // Fallback hesaplama — prevClose kullan, o da yoksa prices listesinden al
      double changePercent;
      if (directChangePct != null) {
        changePercent = directChangePct;
      } else {
        final effectivePrev = prevClose ??
            (prices.length >= 2 ? prices[prices.length - 2] : null);
        changePercent = (effectivePrev != null && effectivePrev != 0)
            ? ((currentPrice - effectivePrev) / effectivePrev) * 100
            : 0.0;
      }

      // Günlük açılış fiyatı — prevClose ile AYNI DEĞİL
      final openPrice =
          (meta['regularMarketOpen'] as num?)?.toDouble() ?? 0.0;
      final highPrice =
          (meta['regularMarketDayHigh'] as num?)?.toDouble() ?? currentPrice;
      final lowPrice =
          (meta['regularMarketDayLow'] as num?)?.toDouble() ?? currentPrice;

      final allPrices = [...prices];
      if (allPrices.isNotEmpty && allPrices.last != currentPrice) {
        allPrices.add(currentPrice);
      }

      final stock = kBistStocks.firstWhere(
        (s) => s['symbol'] == symbol,
        orElse: () => {'symbol': symbol, 'name': symbol},
      );

      return AssetModel(
        symbol: symbol,
        name: stock['name'] ?? symbol,
        price: currentPrice,
        changePercent: changePercent,
        open: openPrice,
        high: highPrice,
        low: lowPrice,
        prices: allPrices,
        opens: opens,
        highs: highs,
        lows: lows,
        volumes: volumes,
      );
    } catch (_) {
      return null;
    }
  }

  // Çoklu hisse toplu çekme (tarama için)
  static Future<List<AssetModel>> fetchMultiple(
    List<String> symbols, {
    String period = '3mo',
    void Function(int done, int total)? onProgress,
  }) async {
    final results = <AssetModel>[];
    for (int i = 0; i < symbols.length; i++) {
      final asset = await fetchStock(symbols[i], period: period);
      if (asset != null) results.add(asset);
      onProgress?.call(i + 1, symbols.length);
      await Future.delayed(const Duration(milliseconds: 100));
    }
    return results;
  }

  // Altın (ONS/USD)
  static Future<AssetModel?> fetchGold() async {
    try {
      final url = Uri.parse('$_baseUrl/GC%3DF?interval=1d&range=3mo');
      final response = await http
          .get(url, headers: {'User-Agent': 'Mozilla/5.0'})
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body);
      final result = data['chart']?['result'];
      if (result == null || result.isEmpty) return null;
      final meta = result[0]['meta'];
      final closePrices =
          result[0]['indicators']?['quote']?[0]?['close'] as List?;
      if (closePrices == null || closePrices.isEmpty) return null;
      final prices = closePrices
          .where((e) => e != null)
          .map<double>((e) => (e as num).toDouble())
          .toList();
      final currentPrice =
          (meta['regularMarketPrice'] as num?)?.toDouble() ?? prices.last;
      final prevClose =
          (meta['previousClose'] as num?)?.toDouble() ??
          (meta['chartPreviousClose'] as num?)?.toDouble();
      final directChg = (meta['regularMarketChangePercent'] as num?)?.toDouble();
      final prevFromList = prices.length >= 2 ? prices[prices.length - 2] : null;
      final effectivePrev = prevClose ?? prevFromList ?? prices.last;
      final changePercent = directChg ??
          (effectivePrev != 0
              ? ((currentPrice - effectivePrev) / effectivePrev) * 100
              : 0.0);
      return AssetModel(
          symbol: 'ALTIN',
          name: 'Altın (USD/oz)',
          price: currentPrice,
          changePercent: changePercent,
          prices: prices,
          volumes: []);
    } catch (_) {
      return null;
    }
  }

  // Dolar/TL
  static Future<AssetModel?> fetchDollar() async {
    try {
      final url = Uri.parse('$_baseUrl/USDTRY%3DX?interval=1d&range=3mo');
      final response = await http
          .get(url, headers: {'User-Agent': 'Mozilla/5.0'})
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body);
      final result = data['chart']?['result'];
      if (result == null || result.isEmpty) return null;
      final meta = result[0]['meta'];
      final closePrices =
          result[0]['indicators']?['quote']?[0]?['close'] as List?;
      if (closePrices == null || closePrices.isEmpty) return null;
      final prices = closePrices
          .where((e) => e != null)
          .map<double>((e) => (e as num).toDouble())
          .toList();
      final currentPrice =
          (meta['regularMarketPrice'] as num?)?.toDouble() ?? prices.last;
      final prevClose =
          (meta['previousClose'] as num?)?.toDouble() ??
          (meta['chartPreviousClose'] as num?)?.toDouble();
      final directChgD = (meta['regularMarketChangePercent'] as num?)?.toDouble();
      final prevFromListD = prices.length >= 2 ? prices[prices.length - 2] : null;
      final effectivePrevD = prevClose ?? prevFromListD ?? prices.last;
      final changePercent = directChgD ??
          (effectivePrevD != 0
              ? ((currentPrice - effectivePrevD) / effectivePrevD) * 100
              : 0.0);
      return AssetModel(
          symbol: 'DOLAR',
          name: 'Dolar/TL',
          price: currentPrice,
          changePercent: changePercent,
          prices: prices,
          volumes: []);
    } catch (_) {
      return null;
    }
  }

  // BIST endeks verisi
  static Future<AssetModel?> fetchIndex(
      String yahooSymbol, String displaySymbol, String name) async {
    try {
      final url =
          Uri.parse('$_baseUrl/$yahooSymbol?interval=1d&range=5d');
      final response = await http
          .get(url, headers: {'User-Agent': 'Mozilla/5.0'})
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body);
      final result = data['chart']?['result'];
      if (result == null || result.isEmpty) return null;
      final meta = result[0]['meta'];
      final closePrices =
          result[0]['indicators']?['quote']?[0]?['close'] as List?;
      if (closePrices == null || closePrices.isEmpty) return null;
      final prices = closePrices
          .where((e) => e != null)
          .map<double>((e) => (e as num).toDouble())
          .toList();
      final currentPrice =
          (meta['regularMarketPrice'] as num?)?.toDouble() ?? prices.last;
      final prevClose = (meta['previousClose'] as num?)?.toDouble() ??
          (meta['chartPreviousClose'] as num?)?.toDouble();
      final directChgI = (meta['regularMarketChangePercent'] as num?)?.toDouble();
      final prevFromListI = prices.length >= 2 ? prices[prices.length - 2] : null;
      final effectivePrevI = prevClose ?? prevFromListI ?? prices.last;
      final changePercent = directChgI ??
          (effectivePrevI != 0
              ? ((currentPrice - effectivePrevI) / effectivePrevI) * 100
              : 0.0);
      return AssetModel(
          symbol: displaySymbol,
          name: name,
          price: currentPrice,
          changePercent: changePercent,
          prices: prices,
          volumes: []);
    } catch (_) {
      return null;
    }
  }

  // Gram Altın TL
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
      // Doğrudan Yahoo'dan gelen changePercent daha güvenilir
      final goldChange = goldUsd['changePercent'] ?? 0.0;
      final usdChange  = usdTry['changePercent'] ?? 0.0;
      // Gram altın değişimi ≈ ONS değişimi + USD/TRY değişimi (yaklaşık)
      final change = prevGram != 0
          ? ((gramPrice - prevGram) / prevGram) * 100
          : (goldChange + usdChange);
      return AssetModel(
          symbol: 'ALTIN/GR',
          name: 'Gram Altın (₺)',
          price: gramPrice,
          changePercent: change,
          prices: [],
          volumes: []);
    } catch (_) {
      return null;
    }
  }

  // Gram Gümüş TL
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
      final silverChange = silverUsd['changePercent'] ?? 0.0;
      final usdChange2   = usdTry['changePercent'] ?? 0.0;
      final change = prevGram != 0
          ? ((gramPrice - prevGram) / prevGram) * 100
          : (silverChange + usdChange2);
      return AssetModel(
          symbol: 'GUMUS/GR',
          name: 'Gram Gümüş (₺)',
          price: gramPrice,
          changePercent: change,
          prices: [],
          volumes: []);
    } catch (_) {
      return null;
    }
  }

  // Euro/TL
  static Future<AssetModel?> fetchEuro() async {
    try {
      final spot = await _fetchSpot('EURTRY%3DX');
      if (spot == null) return null;
      final change = spot['changePercent'] ??
          (spot['prev']! != 0
              ? ((spot['price']! - spot['prev']!) / spot['prev']!) * 100
              : 0.0);
      return AssetModel(
          symbol: 'EURO',
          name: 'Euro/TL',
          price: spot['price']!,
          changePercent: change,
          prices: [],
          volumes: []);
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, double>?> _fetchSpot(String yahooSymbol) async {
    try {
      final url =
          Uri.parse('$_baseUrl/$yahooSymbol?interval=1d&range=5d');
      final resp = await http
          .get(url, headers: {'User-Agent': 'Mozilla/5.0'})
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) return null;
      final data = jsonDecode(resp.body);
      final result = data['chart']?['result'];
      if (result == null || result.isEmpty) return null;
      final meta = result[0]['meta'];
      final current = (meta['regularMarketPrice'] as num?)?.toDouble();
      if (current == null) return null;
      // Yahoo doğrudan changePercent veriyor — en güvenilir kaynak
      final directChange =
          (meta['regularMarketChangePercent'] as num?)?.toDouble();
      final prev = (meta['previousClose'] as num?)?.toDouble() ??
          (meta['chartPreviousClose'] as num?)?.toDouble();
      // Kapanış listesinden de prev hesapla (fallback)
      double? prevFromList;
      final closes =
          result[0]['indicators']?['quote']?[0]?['close'] as List?;
      if (closes != null && closes.length >= 2) {
        final filtered = closes.where((e) => e != null).toList();
        if (filtered.length >= 2) {
          prevFromList =
              (filtered[filtered.length - 2] as num).toDouble();
        }
      }
      final effectivePrev =
          prev ?? prevFromList ?? current;
      return {
        'price': current,
        'prev': effectivePrev,
        'changePercent': directChange ??
            (effectivePrev != 0
                ? ((current - effectivePrev) / effectivePrev) * 100
                : 0.0),
      };
    } catch (_) {
      return null;
    }
  }
}
