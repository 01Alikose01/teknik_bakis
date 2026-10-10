class KapNewsItem {
  final String title;
  final String summary;
  final String source;
  final String time;
  final String url;
  final bool isWithin72h;
  final String? disclosureIndex;
  final String? disclosureType;

  const KapNewsItem({
    required this.title,
    required this.summary,
    required this.source,
    required this.time,
    required this.url,
    this.isWithin72h = true,
    this.disclosureIndex,
    this.disclosureType,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'summary': summary,
        'source': source,
        'time': time,
        'url': url,
        'isWithin72h': isWithin72h,
        'disclosureIndex': disclosureIndex,
        'disclosureType': disclosureType,
      };

  factory KapNewsItem.fromJson(Map<String, dynamic> json) => KapNewsItem(
        title: json['title'] as String? ?? '',
        summary: json['summary'] as String? ?? '',
        source: json['source'] as String? ?? '',
        time: json['time'] as String? ?? '',
        url: json['url'] as String? ?? '',
        isWithin72h: json['isWithin72h'] as bool? ?? true,
        disclosureIndex: json['disclosureIndex'] as String?,
        disclosureType: json['disclosureType'] as String?,
      );

  /// ***THYAO*** gibi sembol öneklerini temizler.
  String get cleanTitle {
    final cleaned =
        title.replaceAll(RegExp(r'^\*+[A-Z0-9]+\*+\s*'), '').trim();
    return cleaned.isNotEmpty ? cleaned : title;
  }

  /// KAP AI analizi için birleştirilmiş metin.
  String get analysisText => '$cleanTitle\n$summary';
}
