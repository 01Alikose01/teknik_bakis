import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/kap_news_item.dart';

class KapNewsService {
  static const _kapGithubUrl =
      'https://raw.githubusercontent.com/Alikose010/teknik-bakis-kap/main/data/kap_news.json';

  static String lastUpdated = '';

  /// KAP Bildirimleri sekmesiyle aynı kaynak: GitHub JSON → KAP API → demo.
  static Future<List<KapNewsItem>> fetch() async {
    // 1. GitHub Raw JSON
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

    // 2. KAP API
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
            final rawDate = d['publishDate']?.toString() ??
                d['releaseDate']?.toString() ??
                '';
            final dt = _tryParseDate(rawDate);
            items.add(KapNewsItem(
              title: d['title']?.toString() ??
                  d['subject']?.toString() ??
                  'KAP Bildirimi',
              summary: d['disclosureClass']?.toString() ??
                  d['subject']?.toString() ??
                  '',
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

    lastUpdated = '';
    final filtered = items.where((i) => i.isWithin72h).toList();
    if (filtered.isNotEmpty) return filtered;
    if (items.isNotEmpty) return items;

    // 3. Demo
    return _fallback();
  }

  static List<KapNewsItem> _fallback() {
    final now = _fmtNow();
    return [
      KapNewsItem(
          title: 'THYAO — Özel Durum Açıklaması',
          summary:
              'Şirket yönetim kurulu kararı hakkında kamuoyu bilgilendirmesi.',
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
          summary:
              'Genel kurul kararı ile hisse başına temettü dağıtılacak.',
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
