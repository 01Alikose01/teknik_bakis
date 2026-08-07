import 'package:flutter_test/flutter_test.dart';
import 'package:teknik_bakis/models/kap_news_item.dart';
import 'package:teknik_bakis/services/kap_news_service.dart';

void main() {
  group('KapNewsService.filterBySymbol', () {
    test('matches items by source symbol and title', () {
      final items = [
        const KapNewsItem(
          title: 'SISE açıklaması',
          summary: 'Sermaye artırımı',
          source: 'SISE',
          time: '01.08.2026 10:00',
          url: '',
        ),
        const KapNewsItem(
          title: 'THYAO bilanço',
          summary: 'Yıl sonu raporu',
          source: 'THYAO',
          time: '01.08.2026 11:00',
          url: '',
        ),
      ];

      final filtered = KapNewsService.filterBySymbol(items, 'SISE');

      expect(filtered, hasLength(1));
      expect(filtered.first.source, 'SISE');
      expect(filtered.first.title, contains('SISE'));
    });

    test('returns empty when there is no match', () {
      final items = [
        const KapNewsItem(
          title: 'THYAO bilanço',
          summary: 'Yıl sonu raporu',
          source: 'THYAO',
          time: '01.08.2026 11:00',
          url: '',
        ),
      ];

      final filtered = KapNewsService.filterBySymbol(items, 'SISE');

      expect(filtered, isEmpty);
    });

    test('builds Investing.com news URL from stock name', () {
      final url = KapNewsService.buildInvestingNewsUrl('AKBNK', name: 'Akbank');

      expect(url, 'https://tr.investing.com/equities/akbank-news');
    });

    test('prefers ticker-based slug for symbols like TUPRS', () {
      final url = KapNewsService.buildInvestingNewsUrl('TUPRS', name: 'Türkiye Petrol Rafinerileri A.Ş.');

      expect(url, 'https://tr.investing.com/equities/tupras-news');
    });

    test('builds curated fallback news when Investing.com is unavailable', () {
      final items = KapNewsService.buildSampleNews('AKBNK', name: 'Akbank');

      expect(items, isNotEmpty);
      expect(items.first.title, contains('Akbank'));
      expect(items.first.summary, isNotEmpty);
      expect(items.first.source, 'Investing.com');
    });

    test('parses Investing.com news items from HTML', () {
      const html = '''
      <div class="articleItem">
        <a href="/news/akbank-1" title="Akbank açıklaması geldi">Akbank açıklaması geldi</a>
        <p class="articleSummary">Şirket bilançosu açıklandı.</p>
      </div>
      <div class="articleItem">
        <a href="/news/akbank-2" title="Akbank tarihinde yeni dönem">Akbank tarihinde yeni dönem</a>
      </div>
      ''';

      final items = KapNewsService.parseInvestingHtml(html, 'AKBNK', 'Akbank');

      expect(items, hasLength(2));
      expect(items.first.title, 'Akbank açıklaması geldi');
      expect(items.first.summary, 'Şirket bilançosu açıklandı.');
      expect(items.first.url, contains('/news/akbank-1'));
    });
  });
}
