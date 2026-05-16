class NewsArticle {
  final String id;
  final String title;
  final String link;
  final String summary;
  final String source;
  final DateTime? publishedAt;

  const NewsArticle({
    required this.id,
    required this.title,
    required this.link,
    required this.summary,
    required this.source,
    required this.publishedAt,
  });
}
