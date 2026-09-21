import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

class SettingsService {
  static const String _boxName = 'settings';
  static const String _darkModeKey = 'darkMode';

  static late Box<dynamic> _box;
  static final ValueNotifier<bool> darkMode = ValueNotifier(false);

  static Future<void> init() async {
    _box = await Hive.openBox<dynamic>(_boxName);
    darkMode.value = _box.get(_darkModeKey, defaultValue: false) as bool;
    _loadNotificationSettings();
  }

  static Future<void> setDarkMode(bool value) async {
    await _box.put(_darkModeKey, value);
    darkMode.value = value;
  }

  static bool get isDarkMode => darkMode.value;

  // İlk kurulumda tema seçimi için
  static const String _kThemeSelected = 'themeSelectedOnFirstLaunch';

  static bool get isThemeSelectedFirstTime =>
      _box.get(_kThemeSelected, defaultValue: false) as bool;

  static Future<void> markThemeSelected() async {
    await _box.put(_kThemeSelected, true);
  }

  // ─── Uygulama İçi Bildirim Ayarları ──────────────────────────────────────

  static const String _kInAppAlarmNotification = 'inAppAlarmNotification';
  static const String _kInAppIpoNotification = 'inAppIpoNotification';

  static final ValueNotifier<bool> inAppAlarmNotification = ValueNotifier(true);
  static final ValueNotifier<bool> inAppIpoNotification = ValueNotifier(true);

  /// Uygulama başladığında çağrılır — init() içinde zaten tetikleniyor.
  static void _loadNotificationSettings() {
    inAppAlarmNotification.value =
        _box.get(_kInAppAlarmNotification, defaultValue: true) as bool;
    inAppIpoNotification.value =
        _box.get(_kInAppIpoNotification, defaultValue: true) as bool;
  }

  static Future<void> setInAppAlarmNotification(bool value) async {
    await _box.put(_kInAppAlarmNotification, value);
    inAppAlarmNotification.value = value;
  }

  static Future<void> setInAppIpoNotification(bool value) async {
    await _box.put(_kInAppIpoNotification, value);
    inAppIpoNotification.value = value;
  }

  // ─── Öğretici Tooltip Bayrakları ─────────────────────────────────────────

  /// TradingView butonu tooltip'i gösterildi mi?
  static const String _kTradingViewTooltipSeen = 'tradingViewTooltipSeen';

  static bool get isTradingViewTooltipSeen =>
      _box.get(_kTradingViewTooltipSeen, defaultValue: false) as bool;

  static Future<void> markTradingViewTooltipSeen() async {
    await _box.put(_kTradingViewTooltipSeen, true);
  }

  /// "Stratejiyi Test Et" butonu tooltip'i gösterildi mi?
  static const String _kBacktestTooltipSeen = 'backtestTooltipSeen';

  static bool get isBacktestTooltipSeen =>
      _box.get(_kBacktestTooltipSeen, defaultValue: false) as bool;

  static Future<void> markBacktestTooltipSeen() async {
    await _box.put(_kBacktestTooltipSeen, true);
  }
}
