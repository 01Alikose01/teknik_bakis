import '../data/keyword_database.dart';

class KapClassificationResult {
  final KapCategory category;
  final KapEffect effect;
  final int score;
  final List<String> matchedKeywords;

  const KapClassificationResult({
    required this.category,
    required this.effect,
    required this.score,
    required this.matchedKeywords,
  });

  bool get isUnknown => category == KapCategory.unknown;

  String get categoryName =>
      KeywordDatabase.categoryNames[category] ?? "Belirsiz";
}

class KapClassifier {
  const KapClassifier();

  KapClassificationResult classify(String text) {
    final normalized = _normalize(text);

    KapCategory bestCategory = KapCategory.unknown;
    int bestScore = 0;
    List<String> bestKeywords = [];

    for (final entry in KeywordDatabase.categoryKeywords.entries) {
      int score = 0;
      List<String> matched = [];

      for (final keyword in entry.value) {
        if (normalized.contains(_normalize(keyword))) {
          matched.add(keyword);

          // Uzun ifadeler daha değerlidir.
          score += keyword.split(" ").length * 10;
        }
      }

      if (score > bestScore) {
        bestScore = score;
        bestCategory = entry.key;
        bestKeywords = matched;
      }
    }

    return KapClassificationResult(
      category: bestCategory,
      effect:
          KeywordDatabase.effects[bestCategory] ?? KapEffect.neutral,
      score: bestScore,
      matchedKeywords: bestKeywords,
    );
  }

  String _normalize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\wçğıöşü\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}