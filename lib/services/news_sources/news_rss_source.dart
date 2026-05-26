class NewsRssCategory {
  final String name;
  final Uri uri;
  final bool isLocal;

  const NewsRssCategory({
    required this.name,
    required this.uri,
    this.isLocal = false,
  });
}

class NewsRssSource {
  final String name;
  final Uri uri;
  final List<NewsRssCategory>? categories;

  const NewsRssSource({
    required this.name,
    required this.uri,
    this.categories,
  });
}
