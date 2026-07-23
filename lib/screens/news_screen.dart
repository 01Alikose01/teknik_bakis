import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
import 'news_detail_screen.dart';
import 'kap_ai_list_screen.dart';

// ─────────────────────────────────────────────
// Model
// ─────────────────────────────────────────────

class _NewsItem {
  final String title, summary, source, time, url;
  final bool isWithin72h;

  const _NewsItem({
    required this.title,
    required this.summary,
    required this.source,
    required this.time,
    required this.url,
    this.isWithin72h = true,
  });
}

// ─────────────────────────────────────────────
// Ana Haberler Ekranı
// ─────────────────────────────────────────────

class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<_NewsItem> _kapNews = [];
  List<_NewsItem> _borsaNews = [];
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

  // GitHub Raw URL — repo kurulduktan sonra KULLANICI_ADI güncelle
  static const _kapGithubUrl =
      'https://raw.githubusercontent.com/Alikose010/teknik-bakis-kap/main/data/kap_news.json';

  String _kapLastUpdated = '';

  // ── KAP Bildirimleri — GitHub Raw JSON → KAP API fallback ─────────────────
  Future<void> _loadKap() async {
    if (mounted) setState(() => _loadingKap = true);

    // 1. GitHub Raw JSON dene (her 10 dk güncellenir)
    if (!_kapGithubUrl.contains('KULLANICI_ADI')) {
      try {
        final resp = await http
            .get(Uri.parse(_kapGithubUrl),
                headers: {'Accept': 'application/json'})
            .timeout(const Duration(seconds: 15));
        if (resp.statusCode == 200) {
          final data = jsonDecode(resp.body);
          final rawList = data['items'] as List?;
          if (rawList != null && rawList.isNotEmpty) {
            final items = rawList
                .map((d) => _NewsItem(
                      title: d['title']?.toString() ?? 'KAP Bildirimi',
                      summary: d['summary']?.toString() ?? '',
                      source: d['source']?.toString() ?? 'KAP',
                      time: d['time']?.toString() ?? _fmtNow(),
                      url: d['url']?.toString() ?? '',
                      isWithin72h: d['within72h'] == true,
                    ))
                .toList();
            if (mounted) {
              setState(() {
                _kapNews = items;
                _loadingKap = false;
                _kapLastUpdated = data['lastUpdated']?.toString() ?? '';
              });
            }
            return;
          }
        }
      } catch (_) {}
    }

    // 2. KAP API direkt dene
    final cutoff = DateTime.now().subtract(const Duration(hours: 72));
    final items = <_NewsItem>[];
    final endpoints = [
      'https://www.kap.org.tr/tr/api/disclosures?type=ozel&orderBy=publishDate&orderDir=desc&pageSize=50&pageIndex=0',
      'https://www.kap.org.tr/tr/api/disclosures?orderBy=publishDate&orderDir=desc&pageSize=50&pageIndex=0',
    ];
    for (final url in endpoints) {
      try {
        final resp = await http.get(Uri.parse(url), headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
          'Accept': 'application/json, text/plain, */*',
          'Accept-Language': 'tr-TR,tr;q=0.9',
          'Referer': 'https://www.kap.org.tr/',
        }).timeout(const Duration(seconds: 12));
        if (resp.statusCode == 200) {
          final data = jsonDecode(resp.body);
          final list = data is List
              ? data
              : (data['data'] as List? ?? data['items'] as List? ?? []);
          for (final d in list) {
            final rawDate = d['publishDate']?.toString() ??
                d['releaseDate']?.toString() ?? '';
            final dt = _tryParseDate(rawDate);
            items.add(_NewsItem(
              title: d['title']?.toString() ??
                  d['subject']?.toString() ?? 'KAP Bildirimi',
              summary: d['disclosureClass']?.toString() ??
                  d['subject']?.toString() ?? '',
              source: d['companyCode']?.toString() ?? 'KAP',
              time: dt != null ? _fmtDate(dt) : _fmtNow(),
              url: d['id'] != null
                  ? 'https://www.kap.org.tr/tr/Bildirim/${d['id']}'
                  : '',
              isWithin72h: dt != null && dt.isAfter(cutoff),
            ));
          }
          if (items.isNotEmpty) break;
        }
      } catch (_) {}
    }
    final filtered = items.where((i) => i.isWithin72h).toList();
    final result = filtered.isNotEmpty ? filtered : items;
    if (result.isNotEmpty && mounted) {
      setState(() { _kapNews = result; _loadingKap = false; });
      return;
    }

    // 3. Fallback demo
    if (mounted) {
      setState(() { _kapNews = _kapFallback(); _loadingKap = false; });
    }
  }

  // ── Borsa Haberleri — çoklu RSS kaynağı ────────────────────────────────────
  Future<void> _loadBorsa() async {
    if (mounted) setState(() => _loadingBorsa = true);

    // Öncelik sırasıyla denenecek RSS kaynakları
    final rssSources = [
      {
        'url': 'https://api.rss2json.com/v1/api.json?rss_url=https://www.bloomberght.com/rss',
        'source': 'Bloomberg HT',
      },
      {
        'url': 'https://api.rss2json.com/v1/api.json?rss_url=https://bigpara.hurriyet.com.tr/rss/borsa/',
        'source': 'BigPara',
      },
      {
        'url': 'https://api.rss2json.com/v1/api.json?rss_url=https://www.haberturk.com/rss/ekonomi.xml',
        'source': 'Habertürk Ekonomi',
      },
      {
        'url': 'https://api.rss2json.com/v1/api.json?rss_url=https://feeds.bbci.co.uk/turkce/ekonomi/rss.xml',
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
              return _NewsItem(
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
              setState(() { _borsaNews = news; _loadingBorsa = false; });
              return;
            }
          }
        }
      } catch (_) {}
    }

    // Fallback
    if (mounted) {
      setState(() {
        _borsaNews = _borsaFallback();
        _loadingBorsa = false;
      });
    }
  }

  // ── Yardımcılar ────────────────────────────────────────────────────────────
  DateTime? _tryParseDate(String raw) {
    if (raw.isEmpty) return null;
    try { return DateTime.parse(raw); } catch (_) {}
    // "10.07.2026 14:30" formatı
    try {
      final parts = raw.split(' ');
      if (parts.length >= 2) {
        final dateParts = parts[0].split('.');
        if (dateParts.length == 3) {
          return DateTime(
            int.parse(dateParts[2]), int.parse(dateParts[1]),
            int.parse(dateParts[0]),
          );
        }
      }
    } catch (_) {}
    return null;
  }

  DateTime? _tryParsePubDate(String raw) {
    if (raw.isEmpty) return null;
    try { return DateTime.parse(raw); } catch (_) {}
    // RFC 2822: "Thu, 10 Jul 2026 10:30:00 +0300"
    try {
      final months = {
        'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4, 'May': 5, 'Jun': 6,
        'Jul': 7, 'Aug': 8, 'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12,
      };
      final parts = raw.replaceAll(',', '').trim().split(RegExp(r'\s+'));
      if (parts.length >= 5) {
        final day = int.tryParse(parts[1]) ?? 1;
        final month = months[parts[2]] ?? 1;
        final year = int.tryParse(parts[3]) ?? 2026;
        final timeParts = parts[4].split(':');
        final hour = int.tryParse(timeParts[0]) ?? 0;
        final min  = int.tryParse(timeParts.length > 1 ? timeParts[1] : '0') ?? 0;
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

  // ── Fallback verileri ───────────────────────────────────────────────────────
  List<_NewsItem> _kapFallback() {
    final now = _fmtNow();
    return [
      _NewsItem(title: 'THYAO — Özel Durum Açıklaması',
          summary: 'Şirket yönetim kurulu kararı hakkında kamuoyu bilgilendirmesi.',
          source: 'THYAO', time: now, url: '', isWithin72h: true),
      _NewsItem(title: 'GARAN — Finansal Sonuçlar',
          summary: 'Çeyrek bilanço açıklaması yapıldı.',
          source: 'GARAN', time: now, url: '', isWithin72h: true),
      _NewsItem(title: 'AKBNK — Temettü Duyurusu',
          summary: 'Genel kurul kararı ile hisse başına temettü dağıtılacak.',
          source: 'AKBNK', time: now, url: '', isWithin72h: true),
      _NewsItem(title: 'EREGL — Üretim Verileri',
          summary: 'Yıllık üretim ve ihracat rakamları açıklandı.',
          source: 'EREGL', time: now, url: '', isWithin72h: true),
      _NewsItem(title: 'SISE — Sermaye Artırımı',
          summary: 'Yönetim kurulu sermaye artırımı kararı aldı.',
          source: 'SISE', time: now, url: '', isWithin72h: true),
    ];
  }

  List<_NewsItem> _borsaFallback() {
    final now = _fmtNow();
    return [
      _NewsItem(title: 'BIST 100 Endeksi Güne Yükselişle Başladı',
          summary: 'Borsa İstanbul\'da BIST 100 endeksi günün ilk saatlerinde yüzde 0.8 artış kaydetti.',
          source: 'Borsa', time: now, url: ''),
      _NewsItem(title: 'Döviz Kurlarında Son Gelişmeler',
          summary: 'Dolar/TL paritesi sabah işlemlerinde 38.45 seviyesinde seyrediyor.',
          source: 'Döviz', time: now, url: ''),
      _NewsItem(title: 'Altın Fiyatları Güncel Veriler',
          summary: 'Ons altın 3.250 dolar seviyesinin üzerinde işlem görüyor.',
          source: 'Emtia', time: now, url: ''),
      _NewsItem(title: 'Merkez Bankası Faiz Kararı Beklentileri',
          summary: 'Piyasalar gelecek hafta açıklanacak faiz kararını bekliyor.',
          source: 'Makro', time: now, url: ''),
      _NewsItem(title: 'Yabancı Yatırımcı Net İşlemleri',
          summary: 'Bu haftaki yabancı yatırımcı net alım verileri açıklandı.',
          source: 'Borsa', time: now, url: ''),
    ];
  }

  // ── Build ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: SafeArea(
        child: Column(
          children: [
            // Başlık
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
              child: Row(
                children: [
                  const Text('Haberler',
                      style: TextStyle(fontSize: 22,
                          fontWeight: FontWeight.bold, color: Colors.black87)),
                  const Spacer(),
                  if (_lastUpdated != null)
                    Text(
                      _kapLastUpdated.isNotEmpty
                          ? 'GitHub: ${_kapLastUpdated.substring(11, 16)} UTC'
                          : 'Son: ${_lastUpdated!.hour.toString().padLeft(2, '0')}:${_lastUpdated!.minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.grey, size: 20),
                    onPressed: _loadAll,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

            // Canlı gösterge
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Container(width: 7, height: 7,
                      decoration: const BoxDecoration(
                          color: Color(0xFF34C759), shape: BoxShape.circle)),
                  const SizedBox(width: 5),
                  const Text('Son 72 saat • Otomatik güncelleme',
                      style: TextStyle(color: Colors.grey, fontSize: 11)),
                ],
              ),
            ),

            // Tab bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                    color: Colors.white, borderRadius: BorderRadius.circular(10)),
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
                  const KapAiListScreen(),
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
                  Text('Son ${_kapNews.length} bildirimi gösteriliyor (72 saat)',
                      style: const TextStyle(color: Colors.grey, fontSize: 11)),
                ],
              ),
            ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _kapNews.length,
              itemBuilder: (_, i) {
                final item = _kapNews[i];
                // ***SEMBOL*** formatını temizle
                final cleanTitle = item.title
                    .replaceAll(RegExp(r'^\*+[A-Z0-9]+\*+\s*'), '')
                    .trim();
                final cleanItem = _NewsItem(
                  title: cleanTitle.isNotEmpty ? cleanTitle : item.title,
                  summary: item.summary,
                  source: item.source,
                  time: item.time,
                  url: item.url,
                  isWithin72h: item.isWithin72h,
                );
                return _NewsCard(item: cleanItem, isKap: true);
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Borsa listesi ────────────────────────────────────────────────────────────
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
        itemBuilder: (_, i) => _NewsCard(item: _borsaNews[i], isKap: false),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Haber Kartı
// ─────────────────────────────────────────────

class _NewsCard extends StatelessWidget {
  final _NewsItem item;
  final bool isKap;
  const _NewsCard({required this.item, required this.isKap});

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
                // Kaynak rozeti
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isKap
                        ? const Color(0xFF1C3A5E).withValues(alpha: 0.10)
                        : const Color(0xFF34C759).withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    item.source,
                    style: TextStyle(
                        color: isKap
                            ? const Color(0xFF1C3A5E)
                            : const Color(0xFF34C759),
                        fontSize: 11,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                // KAP için 72h rozeti
                if (isKap && item.isWithin72h) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF34C759).withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('Yeni',
                        style: TextStyle(color: Color(0xFF34C759),
                            fontSize: 10, fontWeight: FontWeight.bold)),
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
            Text(item.title,
                style: const TextStyle(fontWeight: FontWeight.bold,
                    fontSize: 14, color: Colors.black87)),
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
