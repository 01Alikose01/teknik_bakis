import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore'daki fundamentals cache'inden temel verileri okur.
///
/// Koleksiyon: fundamentals/{ticker}
/// Yazar: Cloud Function (backend — günde 3x BilancoVeri'den çeker)
/// Okur: Tüm kullanıcılar buradan (BilancoVeri'ye tek istek atmaz)
///
/// Yapı:
///   fundamentals/THYAO
///     ├── pe:             3.17
///     ├── pb:             0.41
///     ├── ev_ebitda:      5.02
///     ├── roe:            15.03
///     ├── roa:            6.63
///     ├── dividend_yield: 2.33
///     ├── float_ratio:    50.34
///     ├── market_cap_mn_try: 421245.0
///     └── updatedAt:      Timestamp
class FundamentalsCacheService {
  static final _db = FirebaseFirestore.instance;
  static const _col = 'fundamentals';

  // In-memory cache — aynı seansta Firestore'a tekrar okuma yapmayı önler
  static final Map<String, _Cached> _cache = {};
  static const Duration _memCacheTtl = Duration(hours: 1);

  /// Tek hisse için temel verileri Firestore cache'inden okur.
  /// Cache miss veya eski veri ise Firestore'dan taze çeker.
  /// Firestore erişilemezse boş map döner — uygulama durmuyor.
  static Future<Map<String, double>> getFundamentals(String ticker) async {
    final key = ticker.toUpperCase();

    // 1. In-memory cache kontrolü
    final mem = _cache[key];
    if (mem != null &&
        DateTime.now().difference(mem.fetchedAt) < _memCacheTtl) {
      return mem.data;
    }

    // 2. Firestore'dan çek
    try {
      final doc = await _db
          .collection(_col)
          .doc(key)
          .get()
          .timeout(const Duration(seconds: 6));

      if (!doc.exists || doc.data() == null) return {};

      final data = _parseDoc(doc.data()!);
      _cache[key] = _Cached(data: data, fetchedAt: DateTime.now());
      return data;
    } catch (_) {
      return {};
    }
  }

  /// Tüm hisselerin fundamentallarını tek seferde çeker (bulk).
  /// Analiz ekranı açılmadan önce ön yükleme için kullanılabilir.
  static Future<Map<String, Map<String, double>>> getAllFundamentals() async {
    try {
      final snapshot = await _db
          .collection(_col)
          .get()
          .timeout(const Duration(seconds: 15));

      final result = <String, Map<String, double>>{};
      for (final doc in snapshot.docs) {
        final data = _parseDoc(doc.data());
        if (data.isNotEmpty) {
          result[doc.id] = data;
          _cache[doc.id] = _Cached(data: data, fetchedAt: DateTime.now());
        }
      }
      return result;
    } catch (_) {
      return {};
    }
  }

  static Map<String, double> _parseDoc(Map<String, dynamic> raw) {
    return {
      'pe':                _d(raw['pe']),
      'pb':                _d(raw['pb']),
      'ev_ebitda':         _d(raw['ev_ebitda']),
      'roe':               _d(raw['roe']),
      'roa':               _d(raw['roa']),
      'dividend_yield':    _d(raw['dividend_yield']),
      'float_ratio':       _d(raw['float_ratio']),
      'market_cap_mn_try': _d(raw['market_cap_mn_try']),
    };
  }

  static double _d(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  static void clearCache() => _cache.clear();
}

class _Cached {
  final Map<String, double> data;
  final DateTime fetchedAt;
  const _Cached({required this.data, required this.fetchedAt});
}
