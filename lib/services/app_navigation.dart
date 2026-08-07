/// Uygulama genelinde ana navigasyon tab kontrolü için yardımcı servis.
class AppNavigation {
  static void Function(int index)? _setTab;

  static void registerTabSetter(void Function(int index) setter) {
    _setTab = setter;
  }

  static void goToHome() => _setTab?.call(0);
  static void goToAnaliz() => _setTab?.call(2);
}
