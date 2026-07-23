import '../data/keyword_database.dart';

class KapAnalysis {
  final String summary;

  final KapCategory category;

  final KapEffect effect;

  final int score;

  final int stars;

  final String effectScore;

  final List<String> risks;

  final List<String> matchedKeywords;

  const KapAnalysis({
    required this.summary,
    required this.category,
    required this.effect,
    required this.score,
    required this.stars,
    required this.effectScore,
    required this.risks,
    required this.matchedKeywords,
  });

  String get categoryName =>
      KeywordDatabase.categoryNames[category] ?? "Belirsiz";
}