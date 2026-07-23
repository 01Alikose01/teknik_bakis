import 'engine/kap_classifier.dart';
import 'engine/kap_scoring.dart';
import 'engine/kap_summary.dart';
import 'engine/kap_risk.dart';

import 'models/kap_analysis.dart';

class KapAiService {
  KapAiService();

  final KapClassifier _classifier = const KapClassifier();

  final KapScoring _scoring = const KapScoring();

  final KapSummary _summary = const KapSummary();

  final KapRiskEngine _risk = const KapRiskEngine();

  //---------------------------------------------------------

  KapAnalysis analyze(String text) {
    //------------------------------------
    // 1- Sınıflandır
    //------------------------------------

    final classification = _classifier.classify(text);

    //------------------------------------
    // 2- Puanla
    //------------------------------------

    final scoring = _scoring.calculate(
      text,
      classification,
    );

    //------------------------------------
    // 3- Şirket Adı
    //------------------------------------

    final company = _extractCompany(text);

    //------------------------------------
    // 4- Özet
    //------------------------------------

    final summary = _summary.generate(
      company,
      text,
      classification,
    );

    //------------------------------------
    // 5- Risk
    //------------------------------------

    final risks = _risk.generate(
      text,
      classification,
    );

    //------------------------------------
    // 6- Sonuç
    //------------------------------------

    return KapAnalysis(
      summary: summary,
      category: classification.category,
      effect: classification.effect,
      score: scoring.score,
      stars: scoring.stars,
      effectScore: scoring.effectScore,
      risks: risks,
      matchedKeywords: classification.matchedKeywords,
    );
  }

  //---------------------------------------------------------
  // Şirket Adını Bul
  //---------------------------------------------------------

  String _extractCompany(String text) {
    final lines = text.split("\n");

    for (final line in lines) {
      final value = line.trim();

      if (value.length > 3 && value.length < 40) {
        return value;
      }
    }

    return "Şirket";
  }
}