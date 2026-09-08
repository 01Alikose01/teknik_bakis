import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

class TradingViewScreen extends StatefulWidget {
  final String symbol;
  final String name;

  const TradingViewScreen({
    super.key,
    required this.symbol,
    required this.name,
  });

  @override
  State<TradingViewScreen> createState() => _TradingViewScreenState();
}

class _TradingViewScreenState extends State<TradingViewScreen> {
  late WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    // Hem dikey hem yatay kullanıma izin ver
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _initWebView();
  }

  @override
  void dispose() {
    // Ekrandan çıkınca sadece dikey moda geri dön
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  void _initWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF131722))
      ..setUserAgent(
        'Mozilla/5.0 (Linux; Android 13; Pixel 7) '
        'AppleWebKit/537.36 (KHTML, like Gecko) '
        'Chrome/120.0.0.0 Mobile Safari/537.36',
      )
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) {
          if (mounted) setState(() => _loading = true);
        },
        onPageFinished: (_) {
          if (mounted) setState(() => _loading = false);
        },
        onWebResourceError: (_) {
          if (mounted) setState(() => _loading = false);
        },
      ))
      ..loadRequest(Uri.parse(_buildUrl()));
  }

  /// TradingView Türkçe tam grafik URL'si
  /// locale=tr  → TradingView'da Türkçe arayüz
  /// style=1    → Mum grafik (Candlestick)
  /// theme=dark → Karanlık tema
  String _buildUrl() {
    final sym = Uri.encodeComponent('BIST:${widget.symbol}');
    return 'https://tr.tradingview.com/chart/'
        '?symbol=$sym'
        '&interval=D'
        '&style=1'
        '&theme=dark'
        '&locale=tr'
        '&hide_top_toolbar=0'
        '&hide_side_toolbar=0'
        '&allow_symbol_change=1'
        '&save_image=0'
        '&withdateranges=1';
  }

  @override
  Widget build(BuildContext context) {
    const surface = Color(0xFF1C1C1E);

    return Scaffold(
      backgroundColor: const Color(0xFF131722),
      appBar: AppBar(
        backgroundColor: surface,
        foregroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.symbol,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            Text(
              widget.name,
              style: const TextStyle(color: Colors.white60, fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70, size: 20),
            tooltip: 'Yenile',
            onPressed: () => _controller.reload(),
          ),
          IconButton(
            icon: const Icon(Icons.fullscreen, color: Colors.white70, size: 22),
            tooltip: 'Yatay Tam Ekran',
            onPressed: () {
              SystemChrome.setPreferredOrientations([
                DeviceOrientation.landscapeLeft,
                DeviceOrientation.landscapeRight,
              ]);
            },
          ),
        ],
      ),
      // SafeArea tüm kenarları (üst/alt/sol/sağ) sistem UI'ından korur.
      // Özellikle yatay modda sağdaki navigasyon butonları (üçgen/daire/kare)
      // WebView içeriğinin üzerine binmesini bu şekilde engelleriz.
      body: SafeArea(
        top: false,    // AppBar zaten üstü kaplıyor
        left: true,    // Yatay modda sol sistem UI
        right: true,   // Yatay modda sağ sistem butonları (üçgen/daire/kare)
        bottom: true,  // Alt gezinme çubuğu
        child: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (_loading)
              const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF34C759),
                  strokeWidth: 2,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
