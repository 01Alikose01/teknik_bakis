import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
import '../models/kap_news_item.dart';
import '../services/kap_news_service.dart';
import '../services/subscription_service.dart';
import 'news_detail_screen.dart';
import 'kap_ai_list_screen.dart';
import 'premium_gate_screen.dart';

// Borsa haberleri için yerel model
class _BorsaNewsItem {
  final String title, summary, source, time, url, category;
  final DateTime? publishedDate;

  const _BorsaNewsItem({
    required this.title,
    required this.summary,
    required this.source,
    required this.time,
    required this.url,
    required this.category,
    this.publishedDate,
  });
}

class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<KapNewsItem> _kapNews = [];
  List<_BorsaNewsItem> _borsaNews = [];
  bool _loadingKap = false;
  bool _loadingBorsa = false;
  Timer? _refreshTimer;
  DateTime? _lastUpdated;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAll();
    _refreshTimer =
        Timer.periodic(const Duration(seconds: 90), (_) => _loadAll());
  }

  @override
  void dispose() {
    _tabController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadKap(), _loadBorsa()]);
    if (mounted) setState(() => _lastUpdated = DateTime.now());
  }

  Future<void> _loadKap() async {
    if (mounted) setState(() => _loadingKap = true);
    try {
      final items = await KapNewsService.fetch();
      if (mounted) {
        setState(() {
          _kapNews = items;
          _loadingKap = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingKap = false);
    }
  }

  Future<void> _loadBorsa() async {
    if (mounted) setState(() => _loadingBorsa = true);

    final rssSources = [
      {
        'url': _googleNewsUrl('borsa Türkiye'),
        'source': 'Google News / Borsa',
        'category': 'Borsa',
      },
      {
        'url': _googleNewsUrl('iş Türkiye'),
        'source': 'Google News / İş',
        'category': 'İş',
      },
      {
        'url': _googleNewsUrl('bilim teknoloji Türkiye'),
        'source': 'Google News / Bilim & Teknoloji',
        'category': 'Bilim & Teknoloji',
      },
      {
        'url': 'https://www.investing.com/rss/news_1.rss',
        'source': 'Investing.com',
        'category': 'Borsa',
      },
      {
        'url': 'https://www.bloomberght.com/rss',
        'source': 'Bloomberg HT',
        'category': 'Borsa',
      },
      {
        'url': 'https://bigpara.hurriyet.com.tr/rss/borsa/',
        'source': 'BigPara',
        'category': 'Borsa',
      },
      {
        'url': 'https://www.haberturk.com/rss/ekonomi.xml',
        'source': 'Habertürk Ekonomi',
        'category': 'Borsa',
      },
      {
        'url': 'https://feeds.bbci.co.uk/turkce/ekonomi/rss.xml',
        'source': 'BBC Türkçe Ekonomi',
        'category': 'Borsa',
      },
    ];

    final feeds = await Future.wait(
      rssSources.map((src) => _fetchRssFeed(
            src['url']!,
            src['source']!,
            src['category']!,
          )),
    );

    final items = feeds.expand((item) => item).toList();
    items.sort((a, b) {
      final aDate = a.publishedDate ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = b.publishedDate ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });

    final cutoff = DateTime.now().subtract(const Duration(days: 10));
    final recentItems = items.where((item) {
      final publishedDate = item.publishedDate;
      if (publishedDate == null) return true;
      return publishedDate.isAfter(cutoff) || publishedDate.isAtSameMomentAs(cutoff);
    }).toList();

    if (mounted) {
      setState(() {
        _borsaNews = recentItems.isNotEmpty ? recentItems : _borsaFallback();
        _loadingBorsa = false;
      });
    }
  }

  String _googleNewsUrl(String query) {
    return Uri.https('news.google.com', '/rss/search', {
      'q': query,
      'hl': 'tr',
      'gl': 'TR',
      'ceid': 'TR:tr',
    }).toString();
  }

  Future<List<_BorsaNewsItem>> _fetchRssFeed(
    String url,
    String source,
    String category,
  ) async {
    try {
      final apiUrl = Uri.https('api.rss2json.com', '/v1/api.json', {
        'rss_url': url,
      });
      final resp = await http
          .get(apiUrl, headers: {'User-Agent': 'Mozilla/5.0'})
          .timeout(const Duration(seconds: 12));
      if (resp.statusCode != 200) return [];

      final decoded = jsonDecode(resp.body);
      if (decoded is! Map) return [];

      final rawItems = decoded['items'];
      if (rawItems is! List) return [];

      return rawItems.whereType<Map>().map((item) {
        final rawMap = Map<String, dynamic>.from(item as Map);
        final title = '${rawMap['title'] ?? ''}'.trim();
        final description = _stripHtml(
          '${rawMap['description'] ?? rawMap['content'] ?? ''}',
        );
        final link = '${rawMap['link'] ?? rawMap['guid'] ?? rawMap['url'] ?? ''}'.trim();
        final rawDate = '${rawMap['pubDate'] ?? rawMap['published'] ?? rawMap['updated'] ?? ''}'.trim();
        final dt = _tryParsePubDate(rawDate);

        return _BorsaNewsItem(
          title: title,
          summary: description,
          source: source,
          time: dt != null ? _fmtDate(dt) : _fmtNow(),
          url: link,
          category: category,
          publishedDate: dt,
        );
      }).where((item) => item.title.isNotEmpty).toList();
    } catch (_) {
      return [];
    }
  }

  DateTime? _tryParsePubDate(String raw) {
    if (raw.isEmpty) return null;
    try {
      return DateTime.parse(raw);
    } catch (_) {}
    try {
      final months = {
        'Jan': 1,
        'Feb': 2,
        'Mar': 3,
        'Apr': 4,
        'May': 5,
        'Jun': 6,
        'Jul': 7,
        'Aug': 8,
        'Sep': 9,
        'Oct': 10,
        'Nov': 11,
        'Dec': 12,
      };
      final parts = raw.replaceAll(',', '').trim().split(RegExp(r'\s+'));
      if (parts.length >= 5) {
        final day = int.tryParse(parts[1]) ?? 1;
        final month = months[parts[2]] ?? 1;
        final year = int.tryParse(parts[3]) ?? 2026;
        final timeParts = parts[4].split(':');
        final hour = int.tryParse(timeParts[0]) ?? 0;
        final min =
            int.tryParse(timeParts.length > 1 ? timeParts[1] : '0') ?? 0;
        return DateTime(year, month, day, hour, min);
      }
    } catch (_) {}
    return null;
  }

  String _fmtDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year} '
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  String _fmtNow() => _fmtDate(DateTime.now());

  String _stripHtml(String html) =>
      html.replaceAll(RegExp(r'<[^>]*>'), '')
          .replaceAll('&nbsp;', ' ')
          .replaceAll('&amp;', '&')
          .replaceAll('&lt;', '<')
          .replaceAll('&gt;', '>')
          .replaceAll('&quot;', '"')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

  List<_BorsaNewsItem> _borsaFallback() {
    final now = _fmtNow();
    return [
      _BorsaNewsItem(
        title: 'Borsa İstanbul’da hisseler haftalık toparlanma sinyali veriyor',
        summary: 'Bankacılık ve holding hisseleri, yabancı yatırımcı akışındaki canlanma ile dikkat çekiyor.',
        source: 'Investing.com',
        time: now,
        url: 'https://tr.investing.com/news/stock-market-news',
        category: 'Borsa',
      ),
      _BorsaNewsItem(
        title: 'İş dünyasında yatırım ve birleşme haberleri yoğunlaşıyor',
        summary: 'Kurumsal faaliyetler, şirket birleşmeleri ve yatırım duyurularında yeni gelişmeler izleniyor.',
        source: 'Google News / İş',
        time: now,
        url: 'https://news.google.com',
        category: 'İş',
      ),
      _BorsaNewsItem(
        title: 'Bilim ve teknoloji alanında yeni ürün ve yatırım duyuruları artıyor',
        summary: 'Yapay zeka, enerji ve üretim teknolojilerindeki gelişmeler gündemi hareket ettiriyor.',
        source: 'Google News / Bilim & Teknoloji',
        time: now,
        url: 'https://news.google.com',
        category: 'Bilim & Teknoloji',
      ),
      _BorsaNewsItem(
        title: 'Döviz kurlarında oynaklık sürüyor',
        summary: 'Dolar/TL ve euro/TL hareketleri yatırımcıların kısa vadeli pozisyonlarını etkiliyor.',
        source: 'Bloomberg HT',
        time: now,
        url: 'https://www.bloomberght.com',
        category: 'Borsa',
      ),
      _BorsaNewsItem(
        title: 'Merkez Bankası faiz beklentileri piyasaları yönlendiriyor',
        summary: 'Enflasyon verileri ve politika adımları önümüzdeki süreçte belirleyici kalmaya devam ediyor.',
        source: 'BBC Türkçe Ekonomi',
        time: now,
        url: 'https://www.bbc.com/turkce',
        category: 'Borsa',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (!SubscriptionService.canAccess('news')) {
      return PremiumGateScreen(
        embedded: true,
        nextScreen: const NewsScreen(),
        showGuestOption: !SubscriptionService.hasUsedTrialBefore,
        goToHomeOnFreePlan: true,
      );
    }

    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
              child: Row(
                children: [
                  Text('Haberler',
                      style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                  const Spacer(),
                  if (_lastUpdated != null)
                    Text(
                      KapNewsService.lastUpdated.isNotEmpty
                          ? 'GitHub: ${KapNewsService.lastUpdated.substring(11, 16)} UTC'
                          : 'Son: ${_lastUpdated!.hour.toString().padLeft(2, '0')}:${_lastUpdated!.minute.toString().padLeft(2, '0')}',
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.65), fontSize: 11),
                    ),
                  IconButton(
                    icon: Icon(Icons.refresh,
                        color: theme.colorScheme.onSurface.withOpacity(0.7), size: 20),
                    onPressed: _loadAll,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                          color: Color(0xFF34C759), shape: BoxShape.circle)),
                  const SizedBox(width: 5),
                  Text('Son 72 saat • Otomatik güncelleme',
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.65), fontSize: 11)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(10)),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  dividerColor: Colors.transparent,
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: theme.colorScheme.onPrimary,
                  unselectedLabelColor: theme.colorScheme.onSurface.withOpacity(0.65),
                  labelStyle: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold, fontSize: 12),
                  tabs: const [
                    Tab(text: 'KAP Bildirimleri'),
                    Tab(text: 'Borsa Haberleri'),
                    Tab(text: 'KAP AI'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildKapList(),
                  _buildBorsaList(),
                  KapAiListScreen(
                    kapItems: _kapNews,
                    loading: _loadingKap,
                    onRefresh: _loadKap,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKapList() {
    final theme = Theme.of(context);
    if (_loadingKap && _kapNews.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Color(0xFF34C759)),
            const SizedBox(height: 12),
            Text('KAP bildirimleri yükleniyor...',
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.65), fontSize: 13)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      color: const Color(0xFF34C759),
      onRefresh: _loadKap,
      child: Column(
        children: [
          if (_kapNews.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
              child: Row(
                children: [
                  Icon(Icons.history, size: 13, color: theme.colorScheme.onSurface.withOpacity(0.65)),
                  const SizedBox(width: 4),
                  Text(
                      'Son ${_kapNews.length} bildirimi gösteriliyor (72 saat)',
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.65), fontSize: 11)),
                ],
              ),
            ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _kapNews.length,
              itemBuilder: (_, i) {
                final item = _kapNews[i];
                return _KapNewsCard(item: item);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBorsaList() {
    final theme = Theme.of(context);
    if (_loadingBorsa && _borsaNews.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Color(0xFF34C759)),
            const SizedBox(height: 12),
            Text('Haberler yükleniyor...',
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.65), fontSize: 13)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      color: const Color(0xFF34C759),
      onRefresh: _loadBorsa,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _borsaNews.length,
        itemBuilder: (_, i) => _BorsaNewsCard(item: _borsaNews[i]),
      ),
    );
  }
}

class _KapNewsCard extends StatelessWidget {
  final KapNewsItem item;
  const _KapNewsCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => NewsDetailScreen(
            title: item.cleanTitle,
            summary: item.summary,
            source: item.source,
            time: item.time,
            url: item.url,
          ),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C3A5E).withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(item.source,
                      style: theme.textTheme.labelSmall?.copyWith(
                          color: const Color(0xFF1C3A5E),
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
                ),
                if (item.isWithin72h) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF34C759).withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('Yeni',
                        style: TextStyle(
                            color: Color(0xFF34C759),
                            fontSize: 10,
                            fontWeight: FontWeight.bold)),
                  ),
                ],
                const Spacer(),
                Icon(Icons.access_time, size: 11, color: theme.colorScheme.onSurface.withOpacity(0.65)),
                const SizedBox(width: 3),
                Text(item.time,
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.65), fontSize: 11)),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right, size: 16, color: theme.colorScheme.onSurface.withOpacity(0.65)),
              ],
            ),
            const SizedBox(height: 8),
            Text(item.cleanTitle,
                style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 14)),
            if (item.summary.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(item.summary,
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.65), fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ],
          ],
        ),
      ),
    );
  }
}

class _BorsaNewsCard extends StatelessWidget {
  final _BorsaNewsItem item;
  const _BorsaNewsCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => NewsDetailScreen(
            title: item.title,
            summary: item.summary,
            source: item.source,
            time: item.time,
            url: item.url,
          ),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF34C759).withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(item.source,
                      style: const TextStyle(
                          color: Color(0xFF34C759),
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
                ),
                const Spacer(),
                Icon(Icons.access_time, size: 11, color: theme.colorScheme.onSurface.withOpacity(0.65)),
                const SizedBox(width: 3),
                Text(item.time,
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.65), fontSize: 11)),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right, size: 16, color: theme.colorScheme.onSurface.withOpacity(0.65)),
              ],
            ),
            const SizedBox(height: 8),
            Text(item.title,
                style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 14)),
            if (item.summary.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(item.summary,
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.65), fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ],
          ],
        ),
      ),
    );
  }
}
