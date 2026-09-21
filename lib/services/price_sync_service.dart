import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/asset_model.dart';
import '../services/home_price_cache.dart';
import '../services/portfolio_service.dart';
import '../services/stock_service.dart';
import '../services/notification_service.dart';

/// Tek timer, tek istek paketi.
///
/// Açılış saatleri (10:00–10:30): 1 dakikada bir günceller.
/// Normal seans saatleri (10:30–18:30): 15 dakikada bir günceller.
/// Kapanış grace period (18:30–18:45): Kapanış fiyatını yakalamak için
///   seans bitiminden sonra en fazla 1 kez daha günceller.
/// Seans dışı: güncelleme yapmaz (kapanış sync yapılmışsa).
class PriceSyncService {
  PriceSyncService._();

  static Timer? _timer;
  static bool _syncing = false;

  /// Uygulamada çalışan aktif sembol listesi için callback.
  /// HomeScreen favorilerini buraya bildirmeli.
  static final ValueNotifier<List<String>> activeFavorites =
      ValueNotifier([]);

  /// Fiyat güncellenince dinleyicilere bildirim gider.
  static final ValueNotifier<int> lastSyncTime = ValueNotifier(0);

  // ─── Başlat ────────────────────────────────────────────────────────────────

  static void start() {
    _timer?.cancel();
    // Her 30 saniyede bir saati kontrol et; interval dinamik ayarlanır
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _tick());
    // Uygulama açılışında da hemen bir kez çalıştır
    _tick();
    // Eğer seans bitti ama kapanış sync'i henüz yapılmadıysa (ör. uygulama
    // akşam açıldı) hemen bir kez çek — Hive'daki eski cache yerine
    // güncel kapanış fiyatı gösterilsin.
    _syncIfClosedWithoutFinalPrice();
  }

  static void _syncIfClosedWithoutFinalPrice() {
    final now = _nowTR();
    if (now.weekday == DateTime.saturday || now.weekday == DateTime.sunday) return;
    final today = DateTime(now.year, now.month, now.day);
    final close = DateTime(now.year, now.month, now.day, 18, 30);
    // Seans bitmişse ve bugün için closing sync yapılmamışsa
    if (now.isAfter(close)) {
      final alreadySynced = _closingSyncDate != null &&
          _closingSyncDate!.year == today.year &&
          _closingSyncDate!.month == today.month &&
          _closingSyncDate!.day == today.day;
      if (!alreadySynced) {
        _closingSyncDate = today;
        _sync();
      }
    }
  }

  static void stop() {
    _timer?.cancel();
    _timer = null;
  }

  // ─── Tick ──────────────────────────────────────────────────────────────────

  static DateTime? _lastSync;

  /// Kapanış sonrası final sync yapıldı mı? (günlük, her gün sıfırlanır)
  static DateTime? _closingSyncDate;

  static void _tick() {
    final now = _nowTR();

    // Hafta sonu → pas geç
    if (now.weekday == DateTime.saturday || now.weekday == DateTime.sunday) {
      return;
    }

    final today    = DateTime(now.year, now.month, now.day);
    final open     = DateTime(now.year, now.month, now.day, 10, 0);
    final midpoint = DateTime(now.year, now.month, now.day, 10, 30);
    final close    = DateTime(now.year, now.month, now.day, 18, 30);
    // Kapanış fiyatının Yahoo'ya yansıması için 5 dakika grace period
    final graceEnd = DateTime(now.year, now.month, now.day, 18, 45);

    // ── Kapanış grace period (18:30 – 18:45): bir kez final sync ──────────
    if (now.isAfter(close) && now.isBefore(graceEnd)) {
      // Bu gün için closing sync henüz yapılmadıysa yap
      final alreadySynced = _closingSyncDate != null &&
          _closingSyncDate!.year == today.year &&
          _closingSyncDate!.month == today.month &&
          _closingSyncDate!.day == today.day;
      if (!alreadySynced) {
        _closingSyncDate = today;
        _sync();
      }
      return;
    }

    // ── Seans dışı → pas geç ───────────────────────────────────────────────
    if (now.isBefore(open) || now.isAfter(graceEnd)) return;

    // ── Seans içi: normal güncelleme ──────────────────────────────────────
    final intervalMinutes = now.isBefore(midpoint) ? 1 : 15;

    // Son senkronizasyondan bu yana yeterli süre geçti mi?
    if (_lastSync != null) {
      final elapsed = now.difference(_lastSync!).inMinutes;
      if (elapsed < intervalMinutes) return;
    }

    _sync();
  }

  // ─── Ana senkronizasyon ────────────────────────────────────────────────────

  static Future<void> _sync() async {
    if (_syncing) return;
    _syncing = true;

    try {
      // 1. Tüm semboller — tekrarsız birleşim
      final symbols = _collectAllSymbols();
      if (symbols.isEmpty) {
        _lastSync = _nowTR();
        return;
      }

      // 2. Tek seferde çek
      final results = await StockService.fetchMultiple(symbols, period: '5d')
          .timeout(const Duration(seconds: 25), onTimeout: () => []);

      if (results.isEmpty) return;

      // 3. Cache'e kaydet
      await HomePriceCache.saveStockPrices(results);

      // 4. Alarm kontrolü
      _checkAlarms(results);

      // 5. Dinleyicilere bildir
      _lastSync = _nowTR();
      lastSyncTime.value = _lastSync!.millisecondsSinceEpoch;
    } catch (_) {
    } finally {
      _syncing = false;
    }
  }

  // ─── Sembol toplama ────────────────────────────────────────────────────────

  static List<String> _collectAllSymbols() {
    final set = <String>{};

    // Favori listeler
    for (final s in activeFavorites.value) {
      if (s.trim().isNotEmpty) set.add(s.toUpperCase());
    }

    // Kayıtlı favori listeleri (A ve B)
    for (final s in PortfolioService.getFavoriteList('listA')) {
      if (s.trim().isNotEmpty) set.add(s.toUpperCase());
    }
    for (final s in PortfolioService.getFavoriteList('listB')) {
      if (s.trim().isNotEmpty) set.add(s.toUpperCase());
    }

    // Alarmlar
    for (final alarm in PortfolioService.getAlarms()) {
      set.add(alarm.symbol.toUpperCase());
    }

    // Takip listesi
    for (final item in PortfolioService.getWatchlist()) {
      set.add(item.symbol.toUpperCase());
    }

    // Portföy
    for (final item in PortfolioService.getPortfolio()) {
      set.add(item.symbol.toUpperCase());
    }

    return set.toList();
  }

  // ─── Alarm kontrolü ────────────────────────────────────────────────────────

  static void _checkAlarms(List<AssetModel> assets) {
    final allAlarms = PortfolioService.getAlarms();
    if (allAlarms.isEmpty) return;

    final alarmMap = <String, List<dynamic>>{};
    for (final alarm in allAlarms) {
      alarmMap.putIfAbsent(alarm.symbol.toUpperCase(), () => []).add(alarm);
    }

    for (final asset in assets) {
      final alarms = alarmMap[asset.symbol.toUpperCase()] ?? [];
      for (final alarm in alarms) {
        final triggered = alarm.alertAbove
            ? asset.price >= alarm.alertPrice
            : asset.price <= alarm.alertPrice;
        if (triggered) {
          NotificationService.showPriceAlert(
            symbol: asset.symbol,
            price: asset.price,
            isAbove: alarm.alertAbove,
          );
          // '1 Kere Çal' modunda alarm tetiklenince otomatik sil
          if (alarm.repeatMode == 'once') {
            PortfolioService.removeAlarmItem(alarm);
          }
        }
      }
    }
  }

  // ─── Yardımcı ──────────────────────────────────────────────────────────────

  static DateTime _nowTR() =>
      DateTime.now().toUtc().add(const Duration(hours: 3));

  /// Dışarıdan zorla senkronizasyon (pull-to-refresh gibi durumlar için).
  static Future<void> forceSync() async {
    _lastSync = null;
    await _sync();
  }
}
