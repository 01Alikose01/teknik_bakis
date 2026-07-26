import '../data/keyword_database.dart';

class KapEntities {
  final String? amount;
  final double? amountTl;
  final List<String> dates;
  final List<String> percentages;
  final List<String> symbols;
  final String? institution;

  const KapEntities({
    this.amount,
    this.amountTl,
    this.dates = const [],
    this.percentages = const [],
    this.symbols = const [],
    this.institution,
  });

  bool get hasAny =>
      amount != null ||
      dates.isNotEmpty ||
      percentages.isNotEmpty ||
      symbols.isNotEmpty ||
      institution != null;
}

class CategoryMatch {
  final KapCategory category;
  final int score;
  final List<String> matchedKeywords;

  const CategoryMatch({
    required this.category,
    required this.score,
    required this.matchedKeywords,
  });

  String get categoryName =>
      KeywordDatabase.categoryNames[category] ?? 'Belirsiz';
}
