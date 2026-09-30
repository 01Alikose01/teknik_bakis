import '../data/keyword_database.dart';
import '../models/kap_entities.dart';
import '../engine/kap_contradiction.dart';

class KapAnalysis {
  /// Kısa ve vurucu genel AI özeti (kartlar ve geriye dönük uyumluluk için)
  final String summary;

  /// Şirket tam unvanı veya kodu (ör. "Türk Hava Yolları (THYAO)")
  final String companyName;

  /// Yönetici Özeti — kim, ne zaman, ne kadarlık ve ne amaçla işlem yaptı
  final String executiveSummary;

  /// Finansal ve Operasyonel Etki — ciro, marj, nakit akışı ve sipariş defteri etkisi
  final String financialImpact;

  /// Piyasa ve Fiyatlama Beklentisi — açılış tepkisi, hacim ve kısa/orta vadeli dinamikler
  final String marketOutlook;

  /// Küçük Yatırımcı İçin Stratejik Aksiyon Rehberi — mevcut pozisyon ve yeni alım tavsiyesi
  final String retailInvestorGuidance;

  /// Öne çıkan 3-4 kilit hap bilgi maddesi
  final List<String> keyHighlights;

  /// Takip edilecek kritik katalizörler ve tarihler
  final List<String> watchItems;

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
    this.companyName = '',
    this.executiveSummary = '',
    this.financialImpact = '',
    this.marketOutlook = '',
    this.retailInvestorGuidance = '',
    this.keyHighlights = const [],
    this.watchItems = const [],
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
