import 'package:flutter_test/flutter_test.dart';
import 'package:teknik_bakis/kap_ai/kap_ai_service.dart';
import 'package:teknik_bakis/kap_ai/data/keyword_database.dart';

void main() {
  late KapAiService service;

  setUp(() {
    service = KapAiService();
  });

  group('KapAiService Comprehensive Financial Analysis Tests', () {
    test('Analyzes new business contract with realistic depth', () {
      const text = '''
ASELSAN ELEKTRONİK SANAYİ VE TİCARET A.Ş.
Özel Durum Açıklaması (Genel)
Şirketimiz ile Savunma Sanayii Başkanlığı arasında 1.250.000.000 TL tutarında yeni bir savunma sistemleri satış sözleşmesi imzalanmıştır.
Teslimatların 2026-2027 yılları arasında tamamlanması planlanmaktadır.
''';

      final analysis = service.analyze(text, symbol: 'ASELS');

      expect(analysis.category, KapCategory.newBusiness);
      expect(analysis.effect, KapEffect.positive);
      expect(analysis.score, greaterThanOrEqualTo(70));
      expect(analysis.stars, greaterThanOrEqualTo(4));
      expect(analysis.effectScore, startsWith('+'));
      expect(analysis.companyName, contains('ASELS'));

      // Detaylı analiz alanları
      expect(analysis.summary, isNotEmpty);
      expect(analysis.executiveSummary, contains('Savunma Sanayii Başkanlığı'));
      expect(analysis.executiveSummary, contains('1.250.000.000 TL'));
      expect(analysis.financialImpact, contains('hasılat'));
      expect(analysis.financialImpact, contains('FAVÖK'));
      expect(analysis.marketOutlook, isNotEmpty);
      expect(analysis.retailInvestorGuidance, contains('Hissesi Olanlar'));
      expect(analysis.keyHighlights, isNotEmpty);
      expect(analysis.watchItems, isNotEmpty);
      expect(analysis.entities.amount, isNotNull);
      expect(analysis.entities.institution, 'Savunma Sanayii Başkanlığı');
    });

    test('Analyzes share buyback announcement accurately', () {
      const text = '''
TÜRK HAVA YOLLARI A.O.
Pay Geri Alım İşlemleri
Şirketimiz yönetim kurulu, hisse değerimizin şirket faaliyetlerinin gerçek performansını yansıtmadığı gerekçesiyle azami 500.000.000 TL fon ayrılarak 5.000.000 adet pay geri alım programı başlatılmasına karar vermiştir.
''';

      final analysis = service.analyze(text, symbol: 'THYAO');

      expect(analysis.category, KapCategory.shareBuyback);
      expect(analysis.effect, KapEffect.positive);
      expect(analysis.companyName, contains('THYAO'));
      expect(analysis.executiveSummary, contains('pay geri alım'));
      expect(analysis.financialImpact.toLowerCase(), contains('hisse başına'));
      expect(analysis.marketOutlook, contains('taban desteği'));
      expect(analysis.retailInvestorGuidance, isNotEmpty);
      expect(analysis.entities.shareCount, contains('5.000.000'));
    });

    test('Analyzes dividend proposal with yield and payment guidance', () {
      const text = '''
FORD OTOMOTİV SANAYİ A.Ş.
Kâr Payı Dağıtım İşlemlerine İlişkin Bildirim
Yönetim Kurulumuz tarafından hisse başına net 24,50 TL nakit temettü dağıtılması genel kurul onayına sunulacaktır.
Hak kullanım tarihi 15.10.2026 olarak belirlenmiştir.
''';

      final analysis = service.analyze(text, symbol: 'FROTO');

      expect(analysis.category, KapCategory.dividend);
      expect(analysis.effect, KapEffect.positive);
      expect(analysis.executiveSummary, contains('24,50 TL'));
      expect(analysis.financialImpact, contains('serbest nakit akışı'));
      expect(analysis.marketOutlook, contains('fiyat düzeltmesi'));
      expect(analysis.entities.dividendPerShare, contains('24,50'));
    });

    test('Analyzes bonus share capital increase (%300 Bedelsiz)', () {
      const text = '''
EREĞLİ DEMİR VE ÇELİK FABRİKALARI T.A.Ş.
Sermaye Artırımı İşlemleri
Şirketimiz sermayesinin iç kaynaklardan ve geçmiş yıl kârlarından karşılanmak üzere %300 oranında bedelsiz artırılması kararı alınmıştır.
''';

      final analysis = service.analyze(text, symbol: 'EREGL');

      expect(analysis.category, KapCategory.bonusIssue);
      expect(analysis.effect, KapEffect.positive);
      expect(analysis.executiveSummary, contains('%300'));
      expect(analysis.financialImpact, contains('özkaynak'));
      expect(analysis.marketOutlook, contains('likidite'));
      expect(analysis.retailInvestorGuidance, contains('şirket değerini'));
    });

    test('Analyzes rights issue with cautionary risk guidance', () {
      const text = '''
Şirketimiz sermayesinin %100 oranında nakden (bedelli) artırılmasına karar verilmiştir. Rüçhan hakkı kullanım fiyatı 1 TL olacaktır.
''';

      final analysis = service.analyze(text);

      expect(analysis.category, KapCategory.rightsIssue);
      expect(analysis.effect, KapEffect.negative);
      expect(analysis.effectScore, startsWith('-'));
      expect(analysis.retailInvestorGuidance, contains('rüçhan haklarını'));
      expect(analysis.risks.any((r) => r.contains('sulanma') || r.contains('seyrelme')), isTrue);
    });

    test('Analyzes Solar Energy (GES) investment disclosure', () {
      const text = '''
KORDSA TEKNİK TEKSTİL A.Ş.
Tesislerimizin elektrik ihtiyacını karşılamak üzere 250.000.000 TL tutarında Çatı Güneş Enerjisi Santrali (GES) yatırımı yapılmasına karar verilmiştir.
''';

      final analysis = service.analyze(text, symbol: 'KORDS');

      expect(analysis.category, KapCategory.solarEnergyGES);
      expect(analysis.effect, KapEffect.positive);
      expect(analysis.financialImpact, contains('tasarruf'));
      expect(analysis.entities.projectScope, contains('Güneş Enerjisi'));
    });

    test('Resolves company names correctly from symbols and fallback', () {
      final analysisAkbank = service.analyze('Temettü dağıtım kararı', symbol: 'AKBNK');
      expect(analysisAkbank.companyName, contains('Akbank'));

      final analysisThy = service.analyze('Yeni uçak alım sözleşmesi', symbol: 'THYAO');
      expect(analysisThy.companyName, contains('Türk Hava Yolları'));
    });
  });
}
