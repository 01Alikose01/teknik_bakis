import '../data/keyword_database.dart';
import 'kap_classifier.dart';

class KapScoreResult {
  final int score; // 0-100

  final int stars; // 1-5

  final String effectScore;

  const KapScoreResult({
    required this.score,
    required this.stars,
    required this.effectScore,
  });
}

class KapScoring {
  const KapScoring();

  KapScoreResult calculate(
    String text,
    KapClassificationResult classification,
  ) {
    final normalized = text.toLowerCase();

    int score = 0;

    //-------------------------------------------------
    // 1- Kategori Baz Puanı
    //-------------------------------------------------

    switch (classification.category) {
      case KapCategory.newBusiness:
        score += 60;
        break;

      case KapCategory.tender:
        score += 65;
        break;

      case KapCategory.export:
        score += 55;
        break;

      case KapCategory.shareBuyback:
        score += 55;
        break;

      case KapCategory.dividend:
        score += 50;
        break;

      case KapCategory.capacityIncrease:
        score += 55;
        break;

      case KapCategory.investment:
        score += 50;
        break;

      case KapCategory.incentive:
        score += 45;
        break;

      case KapCategory.partnership:
        score += 60;
        break;

      case KapCategory.debtReduction:
        score += 45;
        break;

      case KapCategory.rightsIssue:
        score += 65;
        break;

      case KapCategory.penalty:
        score += 70;
        break;

      case KapCategory.bankruptcy:
        score += 95;
        break;

      case KapCategory.concordat:
        score += 90;
        break;

      case KapCategory.productionStop:
        score += 80;
        break;

      case KapCategory.contractTermination:
        score += 70;
        break;

      case KapCategory.executiveResignation:
        score += 35;
        break;

      case KapCategory.lawsuit:
        score += 45;
        break;

      default:
        score += 25;
    }

    //-------------------------------------------------
    // 2- Parasal Büyüklük
    //-------------------------------------------------

    score += _moneyScore(normalized);

    //-------------------------------------------------
    // 3- Güçlü Pozitif Kelimeler
    //-------------------------------------------------

    const positives = [

      "imzalandı",

      "kazanıldı",

      "tamamlandı",

      "onaylandı",

      "yatırım",

      "teşvik",

      "yeni",

      "büyüme",

      "kapasite",

      "sipariş",
    ];

    for (final word in positives) {
      if (normalized.contains(word)) {
        score += 2;
      }
    }

    //-------------------------------------------------
    // 4- Güçlü Negatif Kelimeler
    //-------------------------------------------------

    const negatives = [

      "iptal",

      "fesih",

      "zarar",

      "durduruldu",

      "iflas",

      "konkordato",

      "ceza",

      "mahkeme",

      "kayıp",
    ];

    for (final word in negatives) {
      if (normalized.contains(word)) {
        score += 3;
      }
    }

    //-------------------------------------------------
    // 5- Limit
    //-------------------------------------------------

    score = score.clamp(1, 100);

    //-------------------------------------------------
    // 6- Yıldız
    //-------------------------------------------------

    int stars = switch (score) {
      >= 90 => 5,
      >= 75 => 4,
      >= 55 => 3,
      >= 35 => 2,
      _ => 1,
    };

    //-------------------------------------------------
    // 7- +94 / -81 gösterimi
    //-------------------------------------------------

    String effectScore;

    if (classification.effect == KapEffect.positive) {
      effectScore = "+$score";
    } else if (classification.effect == KapEffect.negative) {
      effectScore = "-$score";
    } else {
      effectScore = "$score";
    }

    return KapScoreResult(
      score: score,
      stars: stars,
      effectScore: effectScore,
    );
  }

  //-------------------------------------------------
  // Para büyüklüğü analizi
  //-------------------------------------------------

  int _moneyScore(String text) {
    final regex = RegExp(
      r'([\d.,]+)\s*(milyar|milyon|bin)?\s*(tl|₺|usd|eur|dolar|euro)',
      caseSensitive: false,
    );

    final match = regex.firstMatch(text);

    if (match == null) {
      return 0;
    }

    final value =
        double.tryParse(match.group(1)!.replaceAll(",", ".")) ?? 0;

    final unit = match.group(2)?.toLowerCase() ?? "";

    double amount = value;

    if (unit == "bin") amount *= 1000;
    if (unit == "milyon") amount *= 1000000;
    if (unit == "milyar") amount *= 1000000000;

    if (amount >= 5000000000) return 30;

    if (amount >= 1000000000) return 25;

    if (amount >= 500000000) return 20;

    if (amount >= 100000000) return 15;

    if (amount >= 10000000) return 10;

    if (amount >= 1000000) return 6;

    return 2;
  }
}