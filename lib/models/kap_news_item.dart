class KapNewsItem {
  final String title;
  final String summary;
  final String source;
  final String time;
  final String url;
  final bool isWithin72h;

  const KapNewsItem({
    required this.title,
    required this.summary,
    required this.source,
    required this.time,
    required this.url,
    this.isWithin72h = true,
  });

  /// ***THYAO*** gibi sembol öneklerini temizler.
  String get cleanTitle {
    final cleaned =
        title.replaceAll(RegExp(r'^\*+[A-Z0-9]+\*+\s*'), '').trim();
    return cleaned.isNotEmpty ? cleaned : title;
  }

  /// KAP AI analizi için birleştirilmiş metin.
  String get analysisText => '$cleanTitle\n$summary';
}
