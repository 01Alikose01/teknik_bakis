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
import 'services/portfolio_service.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await PortfolioService.init();
  await NotificationService.init();
  await NotificationService.requestPermission();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const TeknikBakisApp());
}

class TeknikBakisApp extends StatelessWidget {
  const TeknikBakisApp({super.key});

  @override
  Widget build(BuildContext context) {
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
      home: SplashScreen(
        nextScreen: MainNavigation(key: MainNavigation.navKey),
      ),
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

  @override
  Widget build(BuildContext context) {
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
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFF34C759),
        unselectedItemColor: Colors.grey,
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
