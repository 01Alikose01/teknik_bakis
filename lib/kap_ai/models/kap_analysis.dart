import '../data/keyword_database.dart';
import '../models/kap_entities.dart';
import '../engine/kap_contradiction.dart';

class KapAnalysis {
  final String summary;
  final KapCategory category;
  final KapEffect effect;
  final int score;
  final int stars;
  final String effectScore;
  final List<String> risks;
  final List<String> matchedKeywords;
  final int confidence;
  final List<CategoryMatch> secondaryCategories;
  final KapEntities entities;
  final KapContradictionResult contradiction;

  const KapAnalysis({
    required this.summary,
    required this.category,
    required this.effect,
    required this.score,
    required this.stars,
    required this.effectScore,
    required this.risks,
    required this.matchedKeywords,
    required this.confidence,
    this.secondaryCategories = const [],
    required this.entities,
    required this.contradiction,
  });

  String get categoryName =>
      KeywordDatabase.categoryNames[category] ?? 'Belirsiz';

  String get confidenceLabel {
    if (confidence >= 80) return 'Yüksek';
    if (confidence >= 50) return 'Orta';
    return 'Düşük';
  }

  bool get hasContradiction => contradiction.hasContradiction;
}
