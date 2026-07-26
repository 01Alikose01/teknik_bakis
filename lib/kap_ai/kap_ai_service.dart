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
    final classification = _classifier.classify(text);
    final scoring = _scoring.calculate(text, classification);
    final company = _extractCompany(text);
    final summary = _summary.generate(company, text, classification);
    final risks = _risk.generate(text, classification);
    final entities = _entities.extract(text, hintSymbol: symbol);
    final contradiction = _contradiction.detect(text, classification);

    final allRisks = [...risks];
    if (contradiction.hasContradiction && contradiction.message != null) {
      allRisks.insert(0, contradiction.message!);
    }
    if (classification.isLowConfidence) {
      allRisks.add(
        'AI sınıflandırma güveni düşük — bildirimi orijinal metinden doğrulamanız önerilir.',
      );
    }

    return KapAnalysis(
      summary: summary,
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

  String _extractCompany(String text) {
    final lines = text.split('\n');
    for (final line in lines) {
      final value = line.trim();
      if (value.length > 3 && value.length < 40) {
        return value;
      }
    }
    return 'Şirket';
  }
}
