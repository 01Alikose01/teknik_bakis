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
}
