import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/borsa_news_item.dart';

class BorsaNewsService {
  static const List<Map<String, String>> _rssSources = [
    {
      'url': 'https://news.google.com/rss/search?q=borsa%20T%C3%BCrkiye&hl=tr&gl=TR&ceid=TR:tr',
      'source': 'Google News / Borsa',
      'category': 'Borsa',
    },
    {
      'url': 'https://news.google.com/rss/search?q=i%C5%9F%20T%C3%BCrkiye&hl=tr&gl=TR&ceid=TR:tr',
      'source': 'Google News / İş',
      'category': 'İş',
    },
    {
      'url': 'https://news.google.com/rss/search?q=bilim%20teknoloji%20T%C3%BCrkiye&hl=tr&gl=TR&ceid=TR:tr',
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

  static const Set<String> _stopWords = {
    've',
    'ile',
    'bir',
    'bu',
    'icin',
    'için',
    'son',
    'ilgili',
    'olan',
    'olarak',
    'daha',
    'gibi',
    'kadar',
    'gore',
    'göre',
    'ancak',
    'uzerine',
    'üzerine',
    'açiklandi',
    'aciklandi',
    'edildi',
    'etti',
    'ettiğini',
    'ettigi',
    'turkiye',
    'türkiye',
    'duyurdu',
    'acikladi',
    'açıkladı',
    'imzaladi',
    'imzaladı',
    'onayladi',
    'onayladı',
    'yapti',
    'yaptı',
    'anlasti',
    'anlaştı',
    'tamamladi',
    'tamamladı',
    'baslatti',
    'başlattı',
    'sundu',
    'bildirdi',
  };

  static Future<List<BorsaNewsItem>> fetchLatest() async {
    final feeds = await Future.wait(
      _rssSources.map(
        (src) => _fetchRssFeed(
          src['url']!,
          src['source']!,
          src['category']!,
        ),
      ),
    );

    final items = feeds.expand((item) => item).toList()
      ..sort((a, b) {
        final aDate = a.publishedDate ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.publishedDate ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });

    final deduped = _dedupe(items);
    final cutoff = DateTime.now().subtract(const Duration(days: 10));
    final recentItems = deduped.where((item) {
      final publishedDate = item.publishedDate;
      if (publishedDate == null) return true;
      return publishedDate.isAfter(cutoff) ||
          publishedDate.isAtSameMomentAs(cutoff);
    }).toList();

    return recentItems.isNotEmpty ? recentItems : _fallback();
  }

  static Future<List<BorsaNewsItem>> _fetchRssFeed(
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
        final link =
            '${rawMap['link'] ?? rawMap['guid'] ?? rawMap['url'] ?? ''}'.trim();
        final rawDate =
            '${rawMap['pubDate'] ?? rawMap['published'] ?? rawMap['updated'] ?? ''}'
                .trim();
        final dt = _tryParsePubDate(rawDate);

        return BorsaNewsItem(
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

  static List<BorsaNewsItem> _dedupe(List<BorsaNewsItem> items) {
    final unique = <BorsaNewsItem>[];
    for (final candidate in items) {
      final duplicateIndex = unique.indexWhere(
        (existing) => _isDuplicate(candidate, existing),
      );
      if (duplicateIndex == -1) {
        unique.add(candidate);
        continue;
      }

      final existing = unique[duplicateIndex];
      if (_preferCandidate(candidate, existing)) {
        unique[duplicateIndex] = candidate;
      }
    }
    return unique;
  }

  static bool _isDuplicate(BorsaNewsItem a, BorsaNewsItem b) {
    // 1. Kesin URL eşleşmesi — en güvenilir kontrol
    if (a.url.isNotEmpty && b.url.isNotEmpty && a.url == b.url) return true;

    final titleA = _canonicalTitle(a.title);
    final titleB = _canonicalTitle(b.title);
    if (titleA.isEmpty || titleB.isEmpty) return false;

    final summaryA = _canonicalText(a.summary);
    final summaryB = _canonicalText(b.summary);
    final closeInTime = _isCloseInTime(a.publishedDate, b.publishedDate);
    final titleSimilarity = _tokenSimilarity(titleA, titleB);
    final summarySimilarity = _tokenSimilarity(summaryA, summaryB);
    final summaryLooksSame = _textContains(summaryA, summaryB) ||
        _textContains(summaryB, summaryA) ||
        summarySimilarity >= 0.78;

    if (titleA == titleB && (closeInTime || summaryLooksSame)) {
      return true;
    }

    if (closeInTime && titleSimilarity >= 0.92) {
      return true;
    }

    if (closeInTime && titleSimilarity >= 0.82 && summaryLooksSame) {
      return true;
    }

    return false;
  }

  static bool _preferCandidate(BorsaNewsItem candidate, BorsaNewsItem existing) {
    final candidateHasDate = candidate.publishedDate != null;
    final existingHasDate = existing.publishedDate != null;
    if (candidateHasDate != existingHasDate) return candidateHasDate;

    if (candidate.summary.length != existing.summary.length) {
      return candidate.summary.length > existing.summary.length;
    }

    if (candidate.title.length != existing.title.length) {
      return candidate.title.length > existing.title.length;
    }

    final candidateDate =
        candidate.publishedDate ?? DateTime.fromMillisecondsSinceEpoch(0);
    final existingDate =
        existing.publishedDate ?? DateTime.fromMillisecondsSinceEpoch(0);
    return candidateDate.isAfter(existingDate);
  }

  static bool _isCloseInTime(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    return a.difference(b).inHours.abs() <= 6;
  }

  static double _tokenSimilarity(String a, String b) {
    final setA = _tokenize(a);
    final setB = _tokenize(b);
    if (setA.isEmpty || setB.isEmpty) return 0;
    final intersection = setA.intersection(setB).length;
    final union = {...setA, ...setB}.length;
    return union == 0 ? 0 : intersection / union;
  }

  static Set<String> _tokenize(String value) {
    return _canonicalText(value)
        .split(' ')
        .where((token) => token.length >= 3 && !_stopWords.contains(token))
        .toSet();
  }

  static bool _textContains(String longer, String shorter) {
    if (longer.isEmpty || shorter.isEmpty) return false;
    if (shorter.length < 32) return false;
    return longer.contains(shorter);
  }

  static String _canonicalTitle(String value) {
    var normalized = _canonicalText(value);
    normalized = normalized.replaceAll(
      RegExp(
        r'\b(son dakika|canli|canlı|video|foto galeri|analiz|yorum|guncel|güncel)\b',
      ),
      ' ',
    );

    final dashParts = normalized
        .split(RegExp(r'\s+-\s+'))
        .where((part) => part.trim().isNotEmpty)
        .toList();
    if (dashParts.length > 1) {
      normalized = dashParts.first;
    }

    return normalized.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static String _canonicalText(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r"'[a-zçğışöü]{1,4}(?=\s|$)"), '')
        .replaceAll('â', 'a')
        .replaceAll('î', 'i')
        .replaceAll('û', 'u')
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll(RegExp(r'https?://\S+'), ' ')
        .replaceAll(RegExp(r'&[a-z]+;'), ' ')
        .replaceAll(RegExp(r'[^a-z0-9çğıöşü\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static DateTime? _tryParsePubDate(String raw) {
    if (raw.isEmpty) return null;
    try {
      return DateTime.parse(raw).toLocal();
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
        final year = int.tryParse(parts[3]) ?? DateTime.now().year;
        final timeParts = parts[4].split(':');
        final hour = int.tryParse(timeParts[0]) ?? 0;
        final min = int.tryParse(timeParts.length > 1 ? timeParts[1] : '0') ?? 0;

        int offsetMinutes = 0;
        if (parts.length >= 6) {
          final tz = parts[5].trim().toUpperCase();
          if (tz == 'GMT' || tz == 'UTC' || tz == 'Z') {
            offsetMinutes = 0;
          } else if (RegExp(r'^[+-]\d{4}$').hasMatch(tz)) {
            final sign = tz[0] == '+' ? 1 : -1;
            final tzHour = int.tryParse(tz.substring(1, 3)) ?? 0;
            final tzMin = int.tryParse(tz.substring(3, 5)) ?? 0;
            offsetMinutes = sign * (tzHour * 60 + tzMin);
          }
        }

        final utc = DateTime.utc(year, month, day, hour, min)
            .subtract(Duration(minutes: offsetMinutes));
        return utc.toLocal();
      }
    } catch (_) {}
    return null;
  }

  static String _fmtDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year} '
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  static String _fmtNow() => _fmtDate(DateTime.now());

  static String _stripHtml(String html) => html
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static List<BorsaNewsItem> _fallback() {
    final now = _fmtNow();
    return [
      BorsaNewsItem(
        title: 'Borsa İstanbul’da hisseler haftalık toparlanma sinyali veriyor',
        summary:
            'Bankacılık ve holding hisseleri, yabancı yatırımcı akışındaki canlanma ile dikkat çekiyor.',
        source: 'Investing.com',
        time: now,
        url: 'https://tr.investing.com/news/stock-market-news',
        category: 'Borsa',
      ),
      BorsaNewsItem(
        title: 'İş dünyasında yatırım ve birleşme haberleri yoğunlaşıyor',
        summary:
            'Kurumsal faaliyetler, şirket birleşmeleri ve yatırım duyurularında yeni gelişmeler izleniyor.',
        source: 'Google News / İş',
        time: now,
        url: 'https://news.google.com',
        category: 'İş',
      ),
      BorsaNewsItem(
        title:
            'Bilim ve teknoloji alanında yeni ürün ve yatırım duyuruları artıyor',
        summary:
            'Yapay zeka, enerji ve üretim teknolojilerindeki gelişmeler gündemi hareket ettiriyor.',
        source: 'Google News / Bilim & Teknoloji',
        time: now,
        url: 'https://news.google.com',
        category: 'Bilim & Teknoloji',
      ),
      BorsaNewsItem(
        title: 'Döviz kurlarında oynaklık sürüyor',
        summary:
            'Dolar/TL ve euro/TL hareketleri yatırımcıların kısa vadeli pozisyonlarını etkiliyor.',
        source: 'Bloomberg HT',
        time: now,
        url: 'https://www.bloomberght.com',
        category: 'Borsa',
      ),
      BorsaNewsItem(
        title: 'Merkez Bankası faiz beklentileri piyasaları yönlendiriyor',
        summary:
            'Enflasyon verileri ve politika adımları önümüzdeki süreçte belirleyici kalmaya devam ediyor.',
        source: 'BBC Türkçe Ekonomi',
        time: now,
        url: 'https://www.bbc.com/turkce',
        category: 'Borsa',
      ),
    ];
  }
}
