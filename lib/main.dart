import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'screens/home_screen.dart';
import 'screens/scanner_screen.dart';
import 'screens/analiz_screen.dart';
import 'screens/news_screen.dart';
import 'screens/ipo_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/premium_gate_screen.dart';
import 'widgets/theme_selection_dialog.dart';
import 'services/app_navigation.dart';
import 'services/portfolio_service.dart';
import 'services/notification_service.dart';
import 'services/settings_service.dart';
import 'services/subscription_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await PortfolioService.init();
  await SettingsService.init();
  await SubscriptionService.init();
  await NotificationService.init();
  await NotificationService.requestPermission();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const TeknikBakisApp());
}

class TeknikBakisApp extends StatefulWidget {
  const TeknikBakisApp({super.key});

  @override
  State<TeknikBakisApp> createState() => _TeknikBakisAppState();
}

class _TeknikBakisAppState extends State<TeknikBakisApp> {
  Widget _getInitialScreen() {
    // Sadece ücretli aboneler direkt ana uygulamaya girsin. 
    // Ücretsiz kullanıcılar (deneme sürümündekiler dahil) her açılışta Premium kapısını görsün.
    if (SubscriptionService.isPaidSubscriber) {
      return MainNavigation(key: MainNavigation.navKey);
    }
    // Ücretli değilse → premium gate
    return PremiumGateScreen(
      nextScreen: MainNavigation(key: MainNavigation.navKey),
      embedded: false,
      showGuestOption: !SubscriptionService.hasUsedTrialBefore,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: SettingsService.darkMode,
      builder: (context, isDarkMode, child) {
        return MaterialApp(
          title: 'Teknik Bakış',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            brightness: Brightness.light,
            scaffoldBackgroundColor: const Color(0xFFF2F2F7),
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF34C759),
              secondary: Color(0xFF34C759),
              surface: Colors.white,
              onSurface: Colors.black,
            ),
            textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme),
            useMaterial3: true,
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFFF2F2F7),
              foregroundColor: Colors.black,
              elevation: 0,
              surfaceTintColor: Colors.transparent,
            ),
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            scaffoldBackgroundColor: Colors.black,
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF34C759),
              secondary: Color(0xFF34C759),
              surface: Color(0xFF121212),
              onSurface: Colors.white,
            ),
            textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
            useMaterial3: true,
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              elevation: 0,
              surfaceTintColor: Colors.transparent,
            ),
          ),
          themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
          home: SplashScreen(
            nextScreen: _getInitialScreen(),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Ana navigasyon — GlobalKey ile hisse seçilince Analiz sekmesine yönlendirme
// ─────────────────────────────────────────────────────────────────────────────

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  /// Dışarıdan (HomeScreen vb.) Analiz sekmesine geçiş için global key
  static final GlobalKey<MainNavigationState> navKey =
      GlobalKey<MainNavigationState>();

  /// Ana ekrandan hisse seçilince çağrılır — alt navbar gizlenmez
  static void goToAnaliz(String symbol, String name) {
    navKey.currentState?.goToAnaliz(symbol, name);
  }

  /// Abonelik durumu değişince tüm sekmeleri yeniden build et
  static void refreshSubscription() {
    navKey.currentState?.refreshState();
  }

  @override
  State<MainNavigation> createState() => MainNavigationState();
}

/// Public state — GlobalKey kullanımı için public olmalı
class MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  String _analizSymbol = 'THYAO';
  String _analizName = 'Türk Hava Yolları';

  void goToAnaliz(String symbol, String name) {
    setState(() {
      _analizSymbol = symbol;
      _analizName = name;
      _currentIndex = 2;
    });
  }

  /// Abonelik değişince dışarıdan çağrılır — tüm sekmeleri rebuild et
  void refreshState() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    AppNavigation.registerTabSetter((index) {
      setState(() {
        _currentIndex = index;
      });
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!SettingsService.isThemeSelectedFirstTime) {
        showDialog(
          context: context,
          barrierDismissible: false, // Kullanıcı mutlaka seçim yapmalı
          builder: (ctx) => const ThemeSelectionDialog(),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          const HomeScreen(),
          const ScannerScreen(),
          // Key ile rebuild zorlanır — sembol değişince yeni instance
          AnalizScreen(
            key: ValueKey(_analizSymbol),
            initialSymbol: _analizSymbol,
            initialName: _analizName,
          ),
          const NewsScreen(),
          const IpoScreen(),
          const SettingsScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        backgroundColor: theme.colorScheme.surface,
        selectedItemColor: theme.colorScheme.primary,
        unselectedItemColor: theme.colorScheme.onSurface.withValues(alpha: 0.65),
        type: BottomNavigationBarType.fixed,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        selectedLabelStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
        elevation: 8,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.home_outlined),
            activeIcon: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF34C759).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.home, color: Color(0xFF34C759)),
            ),
            label: 'Anasayfa',
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.search_outlined),
            activeIcon: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF34C759).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.search, color: Color(0xFF34C759)),
            ),
            label: 'Tarama',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_outlined),
            activeIcon: Icon(Icons.bar_chart, color: Color(0xFF34C759)),
            label: 'Analiz',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.article_outlined),
            activeIcon: Icon(Icons.article, color: Color(0xFF34C759)),
            label: 'Haberler',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.rocket_launch_outlined),
            activeIcon: Icon(Icons.rocket_launch, color: Color(0xFF34C759)),
            label: 'Halka Arz',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings, color: Color(0xFF34C759)),
            label: 'Ayarlar',
          ),
        ],
      ),
    );
  }
}
