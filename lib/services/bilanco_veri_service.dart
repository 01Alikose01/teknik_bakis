import 'dart:convert';
import 'package:http/http.dart' as http;

/// BilancoVeri.com açık API'sinden BIST şirketlerinin temel verilerini çeker.
/// API anahtarı gerektirmez. Veri kaynağı: KAP / Borsa İstanbul.
/// Fiyatlar en az 15 dk gecikmelidir — temel analiz için uygundur.
///
/// Atıf: "Veri: KAP/Borsa İstanbul, derleyen BilancoVeri.com"
class BilancoVeriService {
  static const String _baseUrl = 'https://bilancoveri.com/api/v1';

  // Basit in-memory cache — aynı seansta tekrar istek atmayı önler
  static final Map<String, _CachedFundamentals> _cache = {};
  static const Duration _cacheTtl = Duration(hours: 6);

  /// Tek bir hissenin temel verilerini getirir.
  /// Dönen map: {'pe': double, 'pb': double, 'roe': double, 'roa': double,
  ///              'ev_ebitda': double, 'dividend_yield': double, 'float_ratio': double}
  /// Hata/offline durumunda boş map döner — caller null kontrolü yapar.
  static Future<Map<String, double>> fetchFundamentals(String ticker) async {
    final key = ticker.toLowerCase();

    // Cache kontrolü
    final cached = _cache[key];
    if (cached != null &&
        DateTime.now().difference(cached.fetchedAt) < _cacheTtl) {
      return cached.data;
    }

    try {
      final url = Uri.parse('$_baseUrl/hisse/$key.json');
      final response = await http
          .get(url, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return {};

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final company = json['company'] as Map<String, dynamic>?;
      if (company == null) return {};

      final data = {
        'pe':                _toDouble(company['pe']),
        'pb':                _toDouble(company['pb']),
        'roe':               _toDouble(company['roe']),
        'roa':               _toDouble(company['roa']),
        'ev_ebitda':         _toDouble(company['ev_ebitda']),
        'dividend_yield':    _toDouble(company['dividend_yield']),
        'float_ratio':       _toDouble(company['float_ratio']),
        'market_cap_mn_try': _toDouble(company['market_cap_mn_try']),
      };

      _cache[key] = _CachedFundamentals(data: data, fetchedAt: DateTime.now());
      return data;
    } catch (_) {
      return {};
    }
  }

  /// Cache'i temizle (test veya manuel yenileme için)
  static void clearCache() => _cache.clear();

  static double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}

class _CachedFundamentals {
  final Map<String, double> data;
  final DateTime fetchedAt;
  const _CachedFundamentals({required this.data, required this.fetchedAt});
}
