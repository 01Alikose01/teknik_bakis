import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/asset_model.dart';

/// Anlık fiyat verilerini Hive'a serialize ederek saklar.
/// HomeScreen açılışında önce bu cache gösterilir, arka planda güncellenir.
class HomePriceCache {
  static const String _boxName = 'homePriceCache';
  static const String _quickKey = 'quickPrices';
  static const String _favoriteKey = 'favoritePrices';

  static Box? _box;

  static Future<void> init() async {
    _box = await Hive.openBox(_boxName);
  }

  static Box get _b {
    assert(_box != null, 'HomePriceCache.init() çağrılmadı');
    return _box!;
  }

  // ─── Serialize ─────────────────────────────────────────────────────────────

  static Map<String, dynamic> _assetToJson(AssetModel a) => {
        's': a.symbol,
        'n': a.name,
        'p': a.price,
        'c': a.changePercent,
        'pc': a.previousClose,
        'o': a.open,
        'h': a.high,
        'l': a.low,
      };

  static AssetModel _assetFromJson(Map<String, dynamic> j) => AssetModel(
        symbol: j['s'] as String,
        name: j['n'] as String,
        price: (j['p'] as num).toDouble(),
        changePercent: (j['c'] as num).toDouble(),
        previousClose: (j['pc'] as num? ?? 0).toDouble(),
        open: (j['o'] as num? ?? 0).toDouble(),
        high: (j['h'] as num? ?? 0).toDouble(),
        low: (j['l'] as num? ?? 0).toDouble(),
        prices: [],
        volumes: [],
      );

  // ─── Quick prices (BIST 100, Dolar, Altın vb.) ─────────────────────────────

  static Future<void> saveQuickPrices(Map<String, AssetModel?> map) async {
    final encoded = <String, String>{};
    for (final e in map.entries) {
      if (e.value != null) {
        encoded[e.key] = jsonEncode(_assetToJson(e.value!));
      }
    }
    await _b.put(_quickKey, encoded);
  }

  static Map<String, AssetModel> loadQuickPrices() {
    final raw = _b.get(_quickKey);
    if (raw == null) return {};
    final map = (raw as Map).cast<String, String>();
    final result = <String, AssetModel>{};
    for (final e in map.entries) {
      try {
        result[e.key] = _assetFromJson(jsonDecode(e.value) as Map<String, dynamic>);
      } catch (_) {}
    }
    return result;
  }

  // ─── Favorite prices (THYAO, GARAN vb.) ────────────────────────────────────

  static Future<void> saveFavoritePrices(List<AssetModel> assets) async {
    final encoded = assets.map((a) => jsonEncode(_assetToJson(a))).toList();
    await _b.put(_favoriteKey, encoded);
  }

  static List<AssetModel> loadFavoritePrices() {
    final raw = _b.get(_favoriteKey);
    if (raw == null) return [];
    final list = (raw as List).cast<String>();
    final result = <AssetModel>[];
    for (final s in list) {
      try {
        result.add(_assetFromJson(jsonDecode(s) as Map<String, dynamic>));
      } catch (_) {}
    }
    return result;
  }
}
