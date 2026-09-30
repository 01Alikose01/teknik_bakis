import '../data/keyword_database.dart';
import '../models/kap_entities.dart';
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
    KapClassificationResult classification, {
    KapEntities? entities,
  }) {
    final normalized = text.toLowerCase();
    int score = 0;

    //-------------------------------------------------
    // 1- Kategori Baz Puanı
    //-------------------------------------------------

    switch (classification.category) {
      case KapCategory.newBusiness:
        score += 65;
        break;

      case KapCategory.tender:
        score += 70;
        break;

      case KapCategory.export:
        score += 60;
        break;

      case KapCategory.shareBuyback:
        score += 65;
        break;

      case KapCategory.dividend:
        score += 60;
        break;

      case KapCategory.bonusIssue:
        score += 70;
        break;

      case KapCategory.solarEnergyGES:
        score += 65;
        break;

      case KapCategory.capacityIncrease:
        score += 60;
        break;

      case KapCategory.investment:
        score += 55;
        break;

      case KapCategory.incentive:
        score += 50;
        break;

      case KapCategory.partnership:
        score += 65;
        break;

      case KapCategory.debtReduction:
        score += 55;
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
        score += 75;
        break;

      case KapCategory.executiveResignation:
        score += 35;
        break;

      case KapCategory.lawsuit:
        score += 50;
        break;

      case KapCategory.debtIssuance:
        score += 40;
        break;

      case KapCategory.shareTransaction:
        score += 45;
        break;

      case KapCategory.capitalIncrease:
        score += 45;
        break;

      case KapCategory.financialReport:
        score += 50;
        break;

      case KapCategory.ratingUpdate:
        score += 45;
        break;

      default:
        score += 30;
    }

    //-------------------------------------------------
    // 2- Parasal Büyüklük Puanı
    //-------------------------------------------------

    if (entities?.amountTl != null && entities!.amountTl! > 0) {
      score += _amountScore(entities.amountTl!);
    } else {
      score += _moneyScoreFallback(normalized);
    }

    //-------------------------------------------------
    // 3- Güçlü Pozitif Kelimeler
    //-------------------------------------------------

    const positives = [
      'imzalandı',
      'kazanıldı',
      'tamamlandı',
      'onaylandı',
      'yatırım',
      'teşvik',
      'yeni',
      'büyüme',
      'kapasite',
      'sipariş',
      'rekor',
      'kâr',
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
      'iptal',
      'fesih',
      'zarar',
      'durduruldu',
      'iflas',
      'konkordato',
      'ceza',
      'mahkeme',
      'kayıp',
      'düşüş',
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
    // 6- Yıldız (1-5)
    //-------------------------------------------------

    final stars = switch (score) {
      >= 85 => 5,
      >= 70 => 4,
      >= 50 => 3,
      >= 30 => 2,
      _ => 1,
    };

    //-------------------------------------------------
    // 7- +94 / -81 / 50 gösterimi
    //-------------------------------------------------

    String effectScore;
    if (classification.effect == KapEffect.positive) {
      effectScore = '+$score';
    } else if (classification.effect == KapEffect.negative) {
      effectScore = '-$score';
    } else {
      effectScore = '$score';
    }

    return KapScoreResult(
      score: score,
      stars: stars,
      effectScore: effectScore,
    );
  }

  int _amountScore(double amountTl) {
    if (amountTl >= 5000000000) return 25; // 5 Milyar TL+
    if (amountTl >= 1000000000) return 20; // 1 Milyar TL+
    if (amountTl >= 500000000) return 15;  // 500 Milyon TL+
    if (amountTl >= 100000000) return 12;  // 100 Milyon TL+
    if (amountTl >= 25000000) return 8;   // 25 Milyon TL+
    if (amountTl >= 5000000) return 5;    // 5 Milyon TL+
    return 2;
  }

  int _moneyScoreFallback(String text) {
    final regex = RegExp(
      r'([\d.,]+)\s*(milyar|milyon|bin)?\s*(tl|₺|usd|eur|dolar|euro)',
      caseSensitive: false,
    );

    final match = regex.firstMatch(text);
    if (match == null) return 0;

    final unit = match.group(2)?.toLowerCase() ?? '';
    if (unit == 'milyar') return 20;
    if (unit == 'milyon') return 12;
    if (unit == 'bin') return 4;
    return 2;
  }
}