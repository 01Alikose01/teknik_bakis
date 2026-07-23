import 'package:hive_flutter/hive_flutter.dart';
import '../models/portfolio_model.dart';

class PortfolioService {
  static const String _portfolioBox = 'portfolio';
  static const String _watchlistBox = 'watchlist';

  static Box<PortfolioItem> get portfolioBox =>
      Hive.box<PortfolioItem>(_portfolioBox);
  static Box<WatchlistItem> get watchlistBox =>
      Hive.box<WatchlistItem>(_watchlistBox);

  static Future<void> init() async {
    Hive.registerAdapter(PortfolioItemAdapter());
    Hive.registerAdapter(WatchlistItemAdapter());
    await Hive.openBox<PortfolioItem>(_portfolioBox);
    await Hive.openBox<WatchlistItem>(_watchlistBox);
  }

  // Portföy işlemleri
  static Future<void> addPortfolioItem(PortfolioItem item) async {
    await portfolioBox.add(item);
  }

  static Future<void> deletePortfolioItem(int index) async {
    await portfolioBox.deleteAt(index);
  }

  static List<PortfolioItem> getPortfolio() => portfolioBox.values.toList();

  // Watchlist işlemleri
  static Future<void> addToWatchlist(WatchlistItem item) async {
    // Aynı sembol zaten varsa ekleme
    final exists = watchlistBox.values.any((w) => w.symbol == item.symbol);
    if (!exists) await watchlistBox.add(item);
  }

  static Future<void> removeFromWatchlist(String symbol) async {
    final key = watchlistBox.keys.firstWhere(
      (k) => watchlistBox.get(k)?.symbol == symbol,
      orElse: () => null,
    );
    if (key != null) await watchlistBox.delete(key);
  }

  static bool isInWatchlist(String symbol) =>
      watchlistBox.values.any((w) => w.symbol == symbol);

  static List<WatchlistItem> getWatchlist() => watchlistBox.values.toList();

  static Future<void> updateWatchlistAlert(
      String symbol, double? alertPrice, bool alertAbove) async {
    final key = watchlistBox.keys.firstWhere(
      (k) => watchlistBox.get(k)?.symbol == symbol,
      orElse: () => null,
    );
    if (key != null) {
      final item = watchlistBox.get(key)!;
      item.alertPrice = alertPrice;
      item.alertAbove = alertAbove;
      await item.save();
    }
  }
}
