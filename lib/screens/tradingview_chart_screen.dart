import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../models/asset_model.dart';
import '../services/stock_service.dart';

class TradingViewChartScreen extends StatefulWidget {
  final AssetModel asset;
  final String category;
  final String symbol;
  final bool initialCandles;
  final String periodLabel;

  const TradingViewChartScreen({
    super.key,
    required this.asset,
    required this.category,
    required this.symbol,
    required this.initialCandles,
    required this.periodLabel,
  });

  @override
  State<TradingViewChartScreen> createState() => _TradingViewChartScreenState();
}

class _TradingViewChartScreenState extends State<TradingViewChartScreen> {
  late String _selectedRange;
  bool _loading = false;
  AssetModel? _asset;
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _selectedRange = _normalizeRange(widget.periodLabel);
    _asset = widget.asset;
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent('Mozilla/5.0 (Linux; Android 12; Pixel 5) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36')
      ..setBackgroundColor(const Color(0xFF07111F))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (url) async {
            await _injectYahooUiCleanup();
          },
          onWebResourceError: (error) {
            debugPrint('Yahoo Finance WebView error: ${error.description}');
          },
        ),
      );
    _loadChart();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshPrice());
  }

  Future<void> _refreshPrice() async {
    setState(() => _loading = true);
    final map = _rangeToPeriodInterval(_selectedRange);
    final refreshed = await _fetchAsset(widget.category, widget.symbol, map['period']!, map['interval']!);
    if (!mounted) return;
    setState(() {
      _asset = refreshed ?? _asset;
    });
    await _loadChart();
    if (!mounted) return;
    setState(() {
      _loading = false;
    });
  }

  String _normalizeRange(String label) {
    switch (label) {
      case '1S':
      case '4S':
      case 'G':
      case 'H':
      case 'A':
      case '1Y':
      case '5Y':
        return label;
      default:
        return 'G';
    }
  }

  Map<String, String> _rangeToPeriodInterval(String range) {
    switch (range) {
      case '1S':
        return {'period': '1d', 'interval': '5m'};
      case '4S':
        return {'period': '5d', 'interval': '15m'};
      case 'G':
        return {'period': '1mo', 'interval': '1d'};
      case 'H':
        return {'period': '3mo', 'interval': '1wk'};
      case 'A':
      case '1A':
        return {'period': '1y', 'interval': '1mo'};
      case '1Y':
        return {'period': '2y', 'interval': '1mo'};
      case '5Y':
        return {'period': '5y', 'interval': '1mo'};
      default:
        return {'period': '1mo', 'interval': '1d'};
    }
  }

  Future<AssetModel?> _fetchAsset(String category, String symbol, String period, String interval) async {
    if (category == 'gold') {
      return StockService.fetchGold(period: period, interval: interval);
    }
    if (category == 'dollar') {
      return StockService.fetchDollar(period: period, interval: interval);
    }
    if (category == 'goldgram') {
      return StockService.fetchGoldGram(period: period, interval: interval);
    }
    if (category == 'silvertl') {
      return StockService.fetchSilverTl(period: period, interval: interval);
    }
    if (category == 'palladiumtl') {
      return StockService.fetchPalladiumTl(period: period, interval: interval);
    }
    if (category == 'platinumtl') {
      return StockService.fetchPlatinumTl(period: period, interval: interval);
    }
    if (category == 'euro') {
      return StockService.fetchEuro(period: period, interval: interval);
    }
    if (category == 'bist100') {
      return StockService.fetchIndex('XU100.IS', 'BIST 100', 'BIST 100', period: period, interval: interval);
    }
    if (category == 'bist30') {
      return StockService.fetchIndex('XU030.IS', 'BIST 30', 'BIST 30', period: period, interval: interval);
    }
    return StockService.fetchStock(symbol, period: period, interval: interval);
  }

  Future<void> _loadChart() async {
    final url = _resolveYahooUrl(widget.symbol, widget.category);
    debugPrint('Loading Yahoo Finance URL: $url');
    await _controller.loadRequest(Uri.parse(url));
  }

  Future<void> _injectYahooUiCleanup() async {
    final js = '''
      if (!window.__yahooChartCleanup) {
        window.__yahooChartCleanup = true;
        function cleanupYahoo() {
          const chart = document.querySelector('div[data-test="qsp-chart"]') ||
                        document.querySelector('#Col1-0-Chart-Proxy') ||
                        document.querySelector('[data-test="fin-chart"]') ||
                        document.querySelector('.yfin-chart');
          if (chart) {
            const root = chart.closest('section') || chart.closest('div[data-test="qsp-chart"]') || chart.parentElement || chart;
            if (root) {
              Array.from(root.parentElement.children || []).forEach(child => {
                if (child !== root) {
                  child.style.display = 'none';
                  child.style.visibility = 'hidden';
                  child.style.height = '0';
                  child.style.padding = '0';
                  child.style.margin = '0';
                }
              });
              root.style.position = 'fixed';
              root.style.top = '0';
              root.style.left = '0';
              root.style.right = '0';
              root.style.bottom = '0';
              root.style.width = '100vw';
              root.style.height = '100vh';
              root.style.margin = '0';
              root.style.padding = '0';
              root.style.zIndex = '9999';
              root.style.background = '#000';
              root.style.overflow = 'hidden';
            }
          }
          ['header','footer','nav','div[data-test="qsp-chart-hdr"]','div[data-test="qsp-chart-footer"]','div[data-testid="chart-toolbar"]','div[data-test="quote-header"]','div[id^="Col"]'].forEach(selector => {
            document.querySelectorAll(selector).forEach(el => {
              el.style.display = 'none';
              el.style.visibility = 'hidden';
              el.style.height = '0';
              el.style.padding = '0';
              el.style.margin = '0';
            });
          });
          const body = document.body;
          const html = document.documentElement;
          [body, html].forEach(el => {
            if (el) {
              el.style.margin = '0';
              el.style.padding = '0';
              el.style.height = '100vh';
              el.style.width = '100vw';
              el.style.overflow = 'hidden';
              el.style.background = '#000';
            }
          });
        }
        cleanupYahoo();
        setInterval(cleanupYahoo, 1400);
      }
    ''';
    await _controller.runJavaScript(js);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${widget.symbol} • Yahoo Finance'),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _loadChart,
            icon: const Icon(Icons.refresh, color: Colors.white70),
            tooltip: 'Grafiği yenile',
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(child: WebViewWidget(controller: _controller)),
          if (_loading)
            const Center(child: CircularProgressIndicator(color: Color(0xFF34C759))),
        ],
      ),
    );
  }

  String _resolveYahooUrl(String symbol, String category) {
    final trimmed = symbol.trim().toUpperCase();
    switch (category) {
      case 'bist':
        return 'https://finance.yahoo.com/quote/$trimmed.IS/chart?p=$trimmed.IS&interval=1d&range=1mo&chartType=candlestick';
      case 'bist100':
        return 'https://finance.yahoo.com/quote/XU100.IS/chart?p=XU100.IS&interval=1d&range=1mo&chartType=candlestick';
      case 'bist30':
        return 'https://finance.yahoo.com/quote/XU030.IS/chart?p=XU030.IS&interval=1d&range=1mo&chartType=candlestick';
      default:
        return 'https://finance.yahoo.com/quote/$trimmed/chart?p=$trimmed&interval=1d&range=1mo&chartType=candlestick';
    }
  }
}
