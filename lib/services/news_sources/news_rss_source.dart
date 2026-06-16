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

class NewsSourceFolder {
  final String id;
  final String name;

  const NewsSourceFolder({
    required this.id,
    required this.name,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
      };

  factory NewsSourceFolder.fromJson(Map<String, dynamic> json) =>
      NewsSourceFolder(
        id: json['id'] ?? '',
        name: json['name'] ?? '',
      );
}

class NewsRssSource {
  final String name;
  final Uri uri;
  final List<NewsRssCategory>? categories;
  final bool isCustom;
  final bool isFolder;
  final String? folderId;
  final String? parentFolderId;

  const NewsRssSource({
    required this.name,
    required this.uri,
    this.categories,
    this.isCustom = false,
    this.isFolder = false,
    this.folderId,
    this.parentFolderId,
  });

  factory NewsRssSource.folder(NewsSourceFolder folder) => NewsRssSource(
        name: folder.name,
        uri: Uri(scheme: 'sonarpad-news-folder', path: folder.id),
        isCustom: true,
        isFolder: true,
        folderId: folder.id,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'uri': uri.toString(),
        'isCustom': isCustom,
        if (parentFolderId != null) 'parentFolderId': parentFolderId,
      };

  factory NewsRssSource.fromJson(Map<String, dynamic> json) => NewsRssSource(
        name: json['name'],
        uri: Uri.parse(json['uri']),
        isCustom: json['isCustom'] ?? true,
        parentFolderId: json['parentFolderId'],
      );

  NewsRssSource copyWith({
    String? name,
    Uri? uri,
    List<NewsRssCategory>? categories,
    bool? isCustom,
    bool? isFolder,
    String? folderId,
    String? parentFolderId,
    bool clearParentFolderId = false,
  }) =>
      NewsRssSource(
        name: name ?? this.name,
        uri: uri ?? this.uri,
        categories: categories ?? this.categories,
        isCustom: isCustom ?? this.isCustom,
        isFolder: isFolder ?? this.isFolder,
        folderId: folderId ?? this.folderId,
        parentFolderId:
            clearParentFolderId ? null : parentFolderId ?? this.parentFolderId,
      );
}
