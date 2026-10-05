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
}
