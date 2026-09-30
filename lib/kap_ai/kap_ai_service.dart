import '../services/bist_stocks.dart';
import 'engine/kap_classifier.dart';
import 'engine/kap_scoring.dart';
import 'engine/kap_summary.dart';
import 'engine/kap_risk.dart';
import 'engine/kap_entity_extractor.dart';
import 'engine/kap_contradiction.dart';
import 'models/kap_analysis.dart';

class KapAiService {
  KapAiService();

  final KapClassifier _classifier = const KapClassifier();
  final KapScoring _scoring = const KapScoring();
  final KapSummary _summary = const KapSummary();
  final KapRiskEngine _risk = const KapRiskEngine();
  final KapEntityExtractor _entities = const KapEntityExtractor();
  final KapContradictionDetector _contradiction =
      const KapContradictionDetector();

  KapAnalysis analyze(String text, {String? symbol}) {
    final entities = _entities.extract(text, hintSymbol: symbol);
    final classification = _classifier.classify(text);
    final scoring = _scoring.calculate(text, classification, entities: entities);
    final company = _resolveCompanyName(text, symbol: symbol, entities: entities);

    final commentary = _summary.generateCommentary(
      company: company,
      text: text,
      classification: classification,
      entities: entities,
    );

    final risks = _risk.generate(text, classification, entities: entities);
    final contradiction = _contradiction.detect(text, classification);

    final allRisks = [...risks];
    if (contradiction.hasContradiction && contradiction.message != null) {
      allRisks.insert(0, contradiction.message!);
    }
    if (classification.isLowConfidence) {
      allRisks.add(
        'AI sınıflandırma güveni düşük — bildirimi orijinal KAP metninden doğrulamanız önerilir.',
      );
    }

    return KapAnalysis(
      summary: commentary.summary,
      companyName: company,
      executiveSummary: commentary.executiveSummary,
      financialImpact: commentary.financialImpact,
      marketOutlook: commentary.marketOutlook,
      retailInvestorGuidance: commentary.retailInvestorGuidance,
      keyHighlights: commentary.keyHighlights,
      watchItems: commentary.watchItems,
      category: classification.category,
      effect: classification.effect,
      score: scoring.score,
      stars: scoring.stars,
      effectScore: scoring.effectScore,
      risks: allRisks.toSet().toList(),
      matchedKeywords: classification.matchedKeywords,
      confidence: classification.confidence,
      secondaryCategories: classification.secondaryCategories,
      entities: entities,
      contradiction: contradiction,
    );
  }

  String _resolveCompanyName(
    String text, {
    String? symbol,
    required entities,
  }) {
    // 1. Doğrudan parametre olarak gelen sembol
    final cleanSym = symbol?.trim().toUpperCase();
    if (cleanSym != null && cleanSym.isNotEmpty && cleanSym != 'KAP') {
      final stockName = _findStockName(cleanSym);
      if (stockName != null && stockName.isNotEmpty) {
        return '$stockName ($cleanSym)';
      }
      return cleanSym;
    }

    // 2. Çıkarılan hisse sembollerinden kontrol
    if (entities.symbols.isNotEmpty) {
      final firstSym = entities.symbols.first.toString().toUpperCase();
      final stockName = _findStockName(firstSym);
      if (stockName != null && stockName.isNotEmpty) {
        return '$stockName ($firstSym)';
      }
      return firstSym;
    }

    // 3. Metnin ilk satırından başlık çıkarma
    final lines = text.split('\n');
    for (final line in lines) {
      final value = line.trim();
      if (value.length > 3 && value.length < 50 && !_looksLikeGenericHeader(value)) {
        return value;
      }
    }

    return 'Şirket';
  }

  bool _looksLikeGenericHeader(String line) {
    final lower = line.toLowerCase();
    return lower.contains('özel durum açıklaması') ||
        lower.contains('kamuyu aydınlatma platformu') ||
        lower.contains('bildirim') ||
        lower.contains('genel açıklama');
  }

  String? _findStockName(String sym) {
    for (final s in kBistStocks) {
      if (s['symbol']?.toUpperCase() == sym.toUpperCase()) {
        return s['name'];
      }
    }
    return null;
  }
}
