import '../data/keyword_database.dart';
import '../models/kap_entities.dart';

class KapClassificationResult {
  final KapCategory category;
  final KapEffect effect;
  final int score;
  final List<String> matchedKeywords;
  final int confidence;
  final List<CategoryMatch> secondaryCategories;

  const KapClassificationResult({
    required this.category,
    required this.effect,
    required this.score,
    required this.matchedKeywords,
    required this.confidence,
    this.secondaryCategories = const [],
  });

  bool get isUnknown => category == KapCategory.unknown;

  bool get isLowConfidence => confidence < 50;

  String get categoryName =>
      KeywordDatabase.categoryNames[category] ?? 'Belirsiz';

  String get confidenceLabel {
    if (confidence >= 80) return 'Yüksek';
    if (confidence >= 50) return 'Orta';
    return 'Düşük';
  }
}

class KapClassifier {
  const KapClassifier();

  KapClassificationResult classify(String text) {
    final normalized = _normalize(text);
    final allMatches = <CategoryMatch>[];

    for (final entry in KeywordDatabase.categoryKeywords.entries) {
      var score = 0;
      final matched = <String>[];

      for (final keyword in entry.value) {
        if (normalized.contains(_normalize(keyword))) {
          matched.add(keyword);
          score += keyword.split(' ').length * 10;
        }
      }

      if (score > 0) {
        allMatches.add(CategoryMatch(
          category: entry.key,
          score: score,
          matchedKeywords: matched,
        ));
      }
    }

    allMatches.sort((a, b) => b.score.compareTo(a.score));

    if (allMatches.isEmpty) {
      return const KapClassificationResult(
        category: KapCategory.unknown,
        effect: KapEffect.neutral,
        score: 0,
        matchedKeywords: [],
        confidence: 20,
      );
    }

    final best = allMatches.first;
    final secondScore = allMatches.length > 1 ? allMatches[1].score : 0;

    final confidence = _calculateConfidence(
      best.score,
      secondScore,
      best.matchedKeywords.length,
      best.category,
    );

    final secondary = allMatches
        .skip(1)
        .where((m) => m.score >= (best.score * 0.4).round() && m.score >= 10)
        .take(3)
        .toList();

    return KapClassificationResult(
      category: best.category,
      effect: KeywordDatabase.effects[best.category] ?? KapEffect.neutral,
      score: best.score,
      matchedKeywords: best.matchedKeywords,
      confidence: confidence,
      secondaryCategories: secondary,
    );
  }

  int _calculateConfidence(
    int bestScore,
    int secondScore,
    int matchCount,
    KapCategory category,
  ) {
    if (category == KapCategory.unknown) return 20;

    var conf = 0.0;
    conf += (bestScore / 60.0 * 45).clamp(0, 45);
    conf += (matchCount * 7).clamp(0, 25);

    if (secondScore == 0) {
      conf += 30;
    } else {
      final margin = (bestScore - secondScore) / bestScore;
      conf += (margin * 30).clamp(5, 30);
    }

    return conf.round().clamp(15, 98);
  }

  String _normalize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\wçğıöşü\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
