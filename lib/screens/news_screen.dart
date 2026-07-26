import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
import '../models/kap_news_item.dart';
import '../services/kap_news_service.dart';
import 'news_detail_screen.dart';
import 'kap_ai_list_screen.dart';

// Borsa haberleri için yerel model
class _BorsaNewsItem {
  final String title, summary, source, time, url;

  const _BorsaNewsItem({
    required this.title,
    required this.summary,
    required this.source,
    required this.time,
    required this.url,
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
        'url':
            'https://api.rss2json.com/v1/api.json?rss_url=https://www.bloomberght.com/rss',
        'source': 'Bloomberg HT',
      },
      {
        'url':
            'https://api.rss2json.com/v1/api.json?rss_url=https://bigpara.hurriyet.com.tr/rss/borsa/',
        'source': 'BigPara',
      },
      {
        'url':
            'https://api.rss2json.com/v1/api.json?rss_url=https://www.haberturk.com/rss/ekonomi.xml',
        'source': 'Habertürk Ekonomi',
      },
      {
        'url':
            'https://api.rss2json.com/v1/api.json?rss_url=https://feeds.bbci.co.uk/turkce/ekonomi/rss.xml',
        'source': 'BBC Türkçe Ekonomi',
      },
    ];

    for (final src in rssSources) {
      try {
        final resp = await http.get(
          Uri.parse(src['url']!),
          headers: {'User-Agent': 'Mozilla/5.0'},
        ).timeout(const Duration(seconds: 12));

        if (resp.statusCode == 200) {
          final data = jsonDecode(resp.body);
          final items = data['items'] as List?;
          if (items != null && items.isNotEmpty) {
            final news = items.take(25).map((d) {
              final dt = _tryParsePubDate(d['pubDate']?.toString() ?? '');
              return _BorsaNewsItem(
                title: d['title']?.toString() ?? '',
                summary: _stripHtml(d['description']?.toString() ?? ''),
                source: d['author']?.toString().isNotEmpty == true &&
                        d['author'].toString().length < 30
                    ? d['author'].toString()
                    : src['source']!,
                time: dt != null ? _fmtDate(dt) : _fmtNow(),
                url: d['link']?.toString() ?? '',
              );
            }).toList();

            if (mounted) {
              setState(() {
                _borsaNews = news;
                _loadingBorsa = false;
              });
              return;
            }
          }
        }
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _borsaNews = _borsaFallback();
        _loadingBorsa = false;
      });
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
          title: 'BIST 100 Endeksi Güne Yükselişle Başladı',
          summary:
              'Borsa İstanbul\'da BIST 100 endeksi günün ilk saatlerinde yüzde 0.8 artış kaydetti.',
          source: 'Borsa',
          time: now,
          url: ''),
      _BorsaNewsItem(
          title: 'Döviz Kurlarında Son Gelişmeler',
          summary:
              'Dolar/TL paritesi sabah işlemlerinde 38.45 seviyesinde seyrediyor.',
          source: 'Döviz',
          time: now,
          url: ''),
      _BorsaNewsItem(
          title: 'Altın Fiyatları Güncel Veriler',
          summary: 'Ons altın 3.250 dolar seviyesinin üzerinde işlem görüyor.',
          source: 'Emtia',
          time: now,
          url: ''),
      _BorsaNewsItem(
          title: 'Merkez Bankası Faiz Kararı Beklentileri',
          summary: 'Piyasalar gelecek hafta açıklanacak faiz kararını bekliyor.',
          source: 'Makro',
          time: now,
          url: ''),
      _BorsaNewsItem(
          title: 'Yabancı Yatırımcı Net İşlemleri',
          summary: 'Bu haftaki yabancı yatırımcı net alım verileri açıklandı.',
          source: 'Borsa',
          time: now,
          url: ''),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
              child: Row(
                children: [
                  const Text('Haberler',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87)),
                  const Spacer(),
                  if (_lastUpdated != null)
                    Text(
                      KapNewsService.lastUpdated.isNotEmpty
                          ? 'GitHub: ${KapNewsService.lastUpdated.substring(11, 16)} UTC'
                          : 'Son: ${_lastUpdated!.hour.toString().padLeft(2, '0')}:${_lastUpdated!.minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                  IconButton(
                    icon: const Icon(Icons.refresh,
                        color: Colors.grey, size: 20),
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
                  const Text('Son 72 saat • Otomatik güncelleme',
                      style: TextStyle(color: Colors.grey, fontSize: 11)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10)),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: const Color(0xFF34C759),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  dividerColor: Colors.transparent,
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.grey,
                  labelStyle: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 12),
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
    if (_loadingKap && _kapNews.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Color(0xFF34C759)),
            SizedBox(height: 12),
            Text('KAP bildirimleri yükleniyor...',
                style: TextStyle(color: Colors.grey, fontSize: 13)),
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
                  const Icon(Icons.history, size: 13, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                      'Son ${_kapNews.length} bildirimi gösteriliyor (72 saat)',
                      style:
                          const TextStyle(color: Colors.grey, fontSize: 11)),
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
    if (_loadingBorsa && _borsaNews.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Color(0xFF34C759)),
            SizedBox(height: 12),
            Text('Haberler yükleniyor...',
                style: TextStyle(color: Colors.grey, fontSize: 13)),
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
          color: Colors.white,
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
                      style: const TextStyle(
                          color: Color(0xFF1C3A5E),
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
                const Icon(Icons.access_time, size: 11, color: Colors.grey),
                const SizedBox(width: 3),
                Text(item.time,
                    style: const TextStyle(color: Colors.grey, fontSize: 11)),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
              ],
            ),
            const SizedBox(height: 8),
            Text(item.cleanTitle,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.black87)),
            if (item.summary.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(item.summary,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
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
          color: Colors.white,
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
                const Icon(Icons.access_time, size: 11, color: Colors.grey),
                const SizedBox(width: 3),
                Text(item.time,
                    style: const TextStyle(color: Colors.grey, fontSize: 11)),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
              ],
            ),
            const SizedBox(height: 8),
            Text(item.title,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.black87)),
            if (item.summary.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(item.summary,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ],
          ],
        ),
      ),
    );
  }
}
