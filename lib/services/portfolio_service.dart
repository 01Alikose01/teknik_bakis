import 'package:hive_flutter/hive_flutter.dart';
import '../models/portfolio_model.dart';

class PortfolioService {
  static const String _portfolioBox = 'portfolio';
  static const String _watchlistBox = 'watchlist';
  static const String _favoriteBox = 'favoriteLists';
  static const String _alarmBox = 'alarms';

  static const List<String> defaultFavoriteListA = ['THYAO', 'GARAN', 'AKBNK', 'SISE', 'ARCLK'];
  static const List<String> defaultFavoriteListB = ['ISCTR', 'ASELS', 'ORTAK', 'KRDMD', 'YKBNK'];

  static Box<PortfolioItem> get portfolioBox =>
      Hive.box<PortfolioItem>(_portfolioBox);
  static Box<WatchlistItem> get watchlistBox =>
      Hive.box<WatchlistItem>(_watchlistBox);
  static Box get favoriteBox => Hive.box(_favoriteBox);
  static Box<AlarmItem> get alarmBox =>
      Hive.box<AlarmItem>(_alarmBox);

  static Future<void> init() async {
    Hive.registerAdapter(PortfolioItemAdapter());
    Hive.registerAdapter(WatchlistItemAdapter());
    Hive.registerAdapter(AlarmItemAdapter());
    await Hive.openBox<PortfolioItem>(_portfolioBox);
    await Hive.openBox<WatchlistItem>(_watchlistBox);
    await Hive.openBox(_favoriteBox);
    await Hive.openBox<AlarmItem>(_alarmBox);
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

  static List<String> getFavoriteList(String key) {
    if (!favoriteBox.containsKey(key)) {
      if (key == 'listA') return List<String>.from(defaultFavoriteListA);
      if (key == 'listB') return List<String>.from(defaultFavoriteListB);
      return [];
    }

    final stored = favoriteBox.get(key);
    if (stored is List) {
      return stored.whereType<String>().toList(growable: false);
    }
    return [];
  }

  static Future<void> saveFavoriteLists(
      List<String> listA, List<String> listB) async {
    await favoriteBox.put('listA', List<String>.from(listA));
    await favoriteBox.put('listB', List<String>.from(listB));
  }

  static Future<void> addAlarm(AlarmItem alarm) async {
    await alarmBox.add(alarm);
  }

  static Future<void> removeAlarm(int key) async {
    await alarmBox.delete(key);
  }

  static Future<void> removeAlarmItem(AlarmItem alarm) async {
    await alarm.delete();
  }

  static List<AlarmItem> getAlarms() => alarmBox.values.toList();

  static List<AlarmItem> getAlarmsForSymbol(String symbol) =>
      alarmBox.values.where((a) => a.symbol == symbol).toList();

  static int getAlarmCount() => alarmBox.length;
}
