class BorsaNewsItem {
  final String title;
  final String summary;
  final String source;
  final String time;
  final String url;
  final String category;
  final DateTime? publishedDate;

  const BorsaNewsItem({
    required this.title,
    required this.summary,
    required this.source,
    required this.time,
    required this.url,
    required this.category,
    this.publishedDate,
  });

  Map<String, dynamic> toJson() => {
    'title': title,
    'summary': summary,
    'source': source,
    'time': time,
    'url': url,
    'category': category,
    'publishedDate': publishedDate?.toIso8601String(),
  };

  factory BorsaNewsItem.fromJson(Map<String, dynamic> j) => BorsaNewsItem(
    title: j['title'] as String? ?? '',
    summary: j['summary'] as String? ?? '',
    source: j['source'] as String? ?? '',
    time: j['time'] as String? ?? '',
    url: j['url'] as String? ?? '',
    category: j['category'] as String? ?? '',
    publishedDate: j['publishedDate'] != null
        ? DateTime.tryParse(j['publishedDate'] as String)
        : null,
  );
}
