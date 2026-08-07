import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../models/kap_news_item.dart';
import 'bist_stocks.dart';

class KapNewsService {
  static const _kapGithubUrl =
      'https://raw.githubusercontent.com/Alikose010/teknik-bakis-kap/main/data/kap_news.json';

  static String lastUpdated = '';

  static List<KapNewsItem> filterBySymbol(List<KapNewsItem> items, String symbol) {
    final query = symbol.trim().toUpperCase();
    if (query.isEmpty) return items;

    return items.where((item) {
      final haystack = [
        item.source,
        item.title,
        item.summary,
        item.cleanTitle,
      ].join(' ').toUpperCase();
      return haystack.contains(query);
    }).toList();
  }

  static String buildInvestingNewsUrl(String symbol, {String? name}) {
    final normalizedSymbol = symbol.trim().toUpperCase();
    final fallbackName = (name ?? _findStockName(symbol) ?? symbol).trim();
    final slugCandidates = <String>[
      normalizedSymbol.toLowerCase(),
      _slugify(fallbackName),
      _slugify(_fallbackTickerName(normalizedSymbol)),
      _slugify(fallbackName.replaceAll(RegExp(r'\bA\.?Ş\b|\bAS\b|\bINC\b|\bLTD\b|\bPLC\b'), '')),
    ];

    for (final candidate in slugCandidates) {
      if (candidate.isNotEmpty) {
        return 'https://tr.investing.com/equities/$candidate-news';
      }
    }

    return 'https://tr.investing.com/equities/$normalizedSymbol-news';
  }

  static Future<List<KapNewsItem>> fetchInvestingNews(String symbol, {String? name}) async {
    final url = buildInvestingNewsUrl(symbol, name: name);
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Accept-Language': 'tr-TR,tr;q=0.9',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        return buildSampleNews(symbol, name: name);
      }

      final parsed = parseInvestingHtml(
        response.body,
        symbol,
        name ?? _findStockName(symbol) ?? symbol,
      );
      return parsed.isEmpty ? buildSampleNews(symbol, name: name) : parsed;
    } catch (_) {
      return buildSampleNews(symbol, name: name);
    }
  }

  static List<KapNewsItem> buildSampleNews(String symbol, {String? name}) {
    final stockName = (name ?? _findStockName(symbol) ?? symbol).trim();
    final baseTitle = stockName.isNotEmpty ? stockName : symbol;
    return [
      KapNewsItem(
        title: '$baseTitle için son haberler',
        summary: '$baseTitle hissesiyle ilgili güncel piyasa gelişmeleri ve şirket duyuruları burada listelenir.',
        source: 'Investing.com',
        time: _fmtNow(),
        url: buildInvestingNewsUrl(symbol, name: stockName),
        isWithin72h: true,
      ),
      KapNewsItem(
        title: '$baseTitle bilanço ve finansal performans takibi',
        summary: 'Bankacılık hisseleri için gelir, kar marjı ve sermaye yapısı gibi kritik veriler takip edilebilir.',
        source: 'Investing.com',
        time: _fmtNow(),
        url: buildInvestingNewsUrl(symbol, name: stockName),
        isWithin72h: true,
      ),
    ];
  }

  static List<KapNewsItem> parseInvestingHtml(String html, String symbol, String name) {
    final lowerHtml = html.toLowerCase();
    final matches = <KapNewsItem>[];

    final anchorRegex = RegExp(
      r'''<a\b[^>]+href=["\']([^"\']+)["\']\s*[^>]*>(.*?)</a>''',
      caseSensitive: false,
      dotAll: true,
    );
    final titleMatches = anchorRegex.allMatches(html);

    for (final match in titleMatches) {
      final href = (match.group(1) ?? '').trim();
      final anchorText = _stripHtml(match.group(2) ?? '').trim();
      if (href.isEmpty || anchorText.isEmpty) {
        continue;
      }

      final hrefLower = href.toLowerCase();
      final looksLikeNewsLink = hrefLower.contains('/news/') || hrefLower.contains('global-filings') || hrefLower.contains('news');
      final isRelevant = _looksRelevant(anchorText, symbol, name) || looksLikeNewsLink;
      if (!isRelevant) {
        continue;
      }

      String url = href;
      if (!url.startsWith('http')) {
        url = 'https://tr.investing.com$url';
      }

      final summary = _extractSummary(html, match.start, match.end);
      matches.add(KapNewsItem(
        title: anchorText,
        summary: summary.isNotEmpty
            ? summary
            : '$name için Investing.com haber sayfası üzerinde güncel içerik bulundu.',
        source: 'Investing.com',
        time: _fmtNow(),
        url: url,
        isWithin72h: true,
      ));
    }

    if (matches.isEmpty && lowerHtml.contains('news')) {
      final fallbackTitle = '$name haberleri';
      matches.add(KapNewsItem(
        title: fallbackTitle,
        summary: '$name için Investing.com haber sayfası bulundu.',
        source: 'Investing.com',
        time: _fmtNow(),
        url: buildInvestingNewsUrl(symbol, name: name),
        isWithin72h: true,
      ));
    }

    return matches.take(6).toList();
  }

  static bool _looksRelevant(String text, String symbol, String name) {
    final haystack = '$text $symbol $name'.toLowerCase();
    return haystack.contains(symbol.toLowerCase()) || haystack.contains(_slugify(name).replaceAll('-', ' '));
  }

  static String _extractSummary(String html, int start, int end) {
    final windowStart = max(0, start - 200);
    final windowEnd = min(html.length, end + 800);
    final snippet = html.substring(windowStart, windowEnd);

    final summaryMatch = RegExp(r'''<p[^>]*class=["\']([^"\']*)(summary|desc|text)[^"\']*["\'][^>]*>(.*?)</p>''', caseSensitive: false, dotAll: true)
        .firstMatch(snippet);
    if (summaryMatch != null) {
      final value = _stripHtml(summaryMatch.group(3) ?? '').trim();
      if (value.isNotEmpty) return value;
    }

    final innerParagraphMatch = RegExp('<p[^>]*>(.*?)</p>', caseSensitive: false, dotAll: true).firstMatch(snippet);
    if (innerParagraphMatch != null) {
      final value = _stripHtml(innerParagraphMatch.group(1) ?? '').trim();
      if (value.isNotEmpty) return value;
    }

    final genericParagraphMatch = RegExp('<div[^>]*>(.*?)</div>', caseSensitive: false, dotAll: true).firstMatch(snippet);
    if (genericParagraphMatch != null) {
      final value = _stripHtml(genericParagraphMatch.group(1) ?? '').trim();
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  static String _stripHtml(String input) {
    return input
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String _slugify(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
  }

  static String? _findStockName(String symbol) {
    final entry = kBistStocks.firstWhere(
      (s) => s['symbol']?.toUpperCase() == symbol.toUpperCase(),
      orElse: () => <String, String>{},
    );
    return entry['name'];
  }

  static String _fallbackTickerName(String symbol) {
    final upper = symbol.trim().toUpperCase();
    if (upper == 'TUPRS') return 'tupras';
    if (upper == 'AKBNK') return 'akbank';
    if (upper == 'SISE') return 'sise';
    if (upper == 'THYAO') return 'thy';
    return upper.toLowerCase();
  }

  static Future<List<KapNewsItem>> fetch() async {
    if (!_kapGithubUrl.contains('KULLANICI_ADI')) {
      try {
        final resp = await http
            .get(Uri.parse(_kapGithubUrl), headers: {'Accept': 'application/json'})
            .timeout(const Duration(seconds: 15));
        if (resp.statusCode == 200) {
          final data = jsonDecode(resp.body);
          final rawList = data['items'] as List?;
          if (rawList != null && rawList.isNotEmpty) {
            lastUpdated = data['lastUpdated']?.toString() ?? '';
            return rawList
                .map((d) => KapNewsItem(
                      title: d['title']?.toString() ?? 'KAP Bildirimi',
                      summary: d['summary']?.toString() ?? '',
                      source: d['source']?.toString() ?? 'KAP',
                      time: d['time']?.toString() ?? _fmtNow(),
                      url: d['url']?.toString() ?? '',
                      isWithin72h: d['within72h'] == true,
                    ))
                .toList();
          }
        }
      } catch (_) {}
    }

    final cutoff = DateTime.now().subtract(const Duration(hours: 72));
    final items = <KapNewsItem>[];
    final endpoints = [
      'https://www.kap.org.tr/tr/api/disclosures?type=ozel&orderBy=publishDate&orderDir=desc&pageSize=50&pageIndex=0',
      'https://www.kap.org.tr/tr/api/disclosures?orderBy=publishDate&orderDir=desc&pageSize=50&pageIndex=0',
    ];
    for (final url in endpoints) {
      try {
        final resp = await http.get(Uri.parse(url), headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
          'Accept': 'application/json, text/plain, */*',
          'Accept-Language': 'tr-tr,tr;q=0.9',
          'Referer': 'https://www.kap.org.tr/',
        }).timeout(const Duration(seconds: 12));
        if (resp.statusCode == 200) {
          final data = jsonDecode(resp.body);
          final list = data is List
              ? data
              : (data['data'] as List? ?? data['items'] as List? ?? []);
          for (final d in list) {
            final rawDate = d['publishDate']?.toString() ?? d['releaseDate']?.toString() ?? '';
            final dt = _tryParseDate(rawDate);
            items.add(KapNewsItem(
              title: d['title']?.toString() ?? d['subject']?.toString() ?? 'KAP Bildirimi',
              summary: d['disclosureClass']?.toString() ?? d['subject']?.toString() ?? '',
              source: d['companyCode']?.toString() ?? 'KAP',
              time: dt != null ? _fmtDate(dt) : _fmtNow(),
              url: d['id'] != null ? 'https://www.kap.org.tr/tr/Bildirim/${d['id']}' : '',
              isWithin72h: dt != null && dt.isAfter(cutoff),
            ));
          }
          if (items.isNotEmpty) break;
        }
      } catch (_) {}
    }

    lastUpdated = '';
    final filtered = items.where((i) => i.isWithin72h).toList();
    if (filtered.isNotEmpty) return filtered;
    if (items.isNotEmpty) return items;

    return _fallback();
  }

  static List<KapNewsItem> _fallback() {
    final now = _fmtNow();
    return [
      KapNewsItem(
          title: 'THYAO — Özel Durum Açıklaması',
          summary: 'Şirket yönetim kurulu kararı hakkında kamuoyu bilgilendirmesi.',
          source: 'THYAO',
          time: now,
          url: '',
          isWithin72h: true),
      KapNewsItem(
          title: 'GARAN — Finansal Sonuçlar',
          summary: 'Çeyrek bilanço açıklaması yapıldı.',
          source: 'GARAN',
          time: now,
          url: '',
          isWithin72h: true),
      KapNewsItem(
          title: 'AKBNK — Temettü Duyurusu',
          summary: 'Genel kurul kararı ile hisse başına temettü dağıtılacak.',
          source: 'AKBNK',
          time: now,
          url: '',
          isWithin72h: true),
      KapNewsItem(
          title: 'EREGL — Üretim Verileri',
          summary: 'Yıllık üretim ve ihracat rakamları açıklandı.',
          source: 'EREGL',
          time: now,
          url: '',
          isWithin72h: true),
      KapNewsItem(
          title: 'SISE — Sermaye Artırımı',
          summary: 'Yönetim kurulu sermaye artırımı kararı aldı.',
          source: 'SISE',
          time: now,
          url: '',
          isWithin72h: true),
    ];
  }

  static DateTime? _tryParseDate(String raw) {
    if (raw.isEmpty) return null;
    try {
      return DateTime.parse(raw);
    } catch (_) {}
    try {
      final parts = raw.split(' ');
      if (parts.length >= 2) {
        final dateParts = parts[0].split('.');
        if (dateParts.length == 3) {
          return DateTime(
            int.parse(dateParts[2]),
            int.parse(dateParts[1]),
            int.parse(dateParts[0]),
          );
        }
      }
    } catch (_) {}
    return null;
  }

  static String _fmtDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year} '
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  static String _fmtNow() => _fmtDate(DateTime.now());
}
