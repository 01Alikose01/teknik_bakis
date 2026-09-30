import '../data/keyword_database.dart';

class KapEntities {
  final String? amount;
  final double? amountTl;
  final String? currency;
  final List<String> dates;
  final List<String> percentages;
  final List<String> symbols;
  final String? institution;
  final String? shareCount;
  final String? dividendPerShare;
  final String? capitalRatio;
  final String? projectScope;

  const KapEntities({
    this.amount,
    this.amountTl,
    this.currency,
    this.dates = const [],
    this.percentages = const [],
    this.symbols = const [],
    this.institution,
    this.shareCount,
    this.dividendPerShare,
    this.capitalRatio,
    this.projectScope,
  });

  bool get hasAny =>
      amount != null ||
      dates.isNotEmpty ||
      percentages.isNotEmpty ||
      symbols.isNotEmpty ||
      institution != null ||
      shareCount != null ||
      dividendPerShare != null ||
      capitalRatio != null ||
      projectScope != null;
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
