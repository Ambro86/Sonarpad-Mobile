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
  final bool isCustom;

  const NewsRssSource({
    required this.name,
    required this.uri,
    this.categories,
    this.isCustom = false,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'uri': uri.toString(),
        'isCustom': isCustom,
      };

  factory NewsRssSource.fromJson(Map<String, dynamic> json) => NewsRssSource(
        name: json['name'],
        uri: Uri.parse(json['uri']),
        isCustom: json['isCustom'] ?? true,
      );
}
