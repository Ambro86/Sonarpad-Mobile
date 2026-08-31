enum NewsArticleMediaKind { audio, pdf, youtube }

class NewsArticleMediaLink {
  final NewsArticleMediaKind kind;
  final String url;
  final String label;

  const NewsArticleMediaLink({
    required this.kind,
    required this.url,
    required this.label,
  });

  static NewsArticleMediaLink? tryParse(
    String rawUrl, {
    String? label,
  }) {
    final url = rawUrl.trim();
    final uri = Uri.tryParse(url);
    if (uri == null ||
        (uri.scheme.toLowerCase() != 'http' &&
            uri.scheme.toLowerCase() != 'https') ||
        uri.host.isEmpty) {
      return null;
    }

    final host = uri.host.toLowerCase();
    final path = uri.path.toLowerCase();
    final kind = _youtubeHosts.contains(host) ||
            host.endsWith('.youtube.com') ||
            host.endsWith('.youtube-nocookie.com')
        ? NewsArticleMediaKind.youtube
        : path.endsWith('.pdf')
            ? NewsArticleMediaKind.pdf
            : _audioExtensions.any(path.endsWith)
                ? NewsArticleMediaKind.audio
                : null;
    if (kind == null) return null;

    var cleanLabel = (label ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleanLabel.isEmpty) {
      if (uri.pathSegments.isNotEmpty && uri.pathSegments.last.isNotEmpty) {
        cleanLabel = Uri.decodeComponent(uri.pathSegments.last);
      } else {
        cleanLabel = host;
      }
    }

    return NewsArticleMediaLink(kind: kind, url: url, label: cleanLabel);
  }

  Map<String, dynamic> toJson() => {
        'kind': kind.name,
        'url': url,
        'label': label,
      };

  static NewsArticleMediaLink? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final url = raw['url']?.toString() ?? '';
    final label = raw['label']?.toString() ?? '';
    final kindName = raw['kind']?.toString() ?? '';
    final parsed = tryParse(url, label: label);
    if (parsed == null) return null;
    NewsArticleMediaKind? expectedKind;
    for (final value in NewsArticleMediaKind.values) {
      if (value.name == kindName) {
        expectedKind = value;
        break;
      }
    }
    if (expectedKind == null || expectedKind != parsed.kind) return parsed;
    return NewsArticleMediaLink(
      kind: expectedKind,
      url: url,
      label: parsed.label,
    );
  }

  static const _youtubeHosts = {
    'youtube.com',
    'www.youtube.com',
    'm.youtube.com',
    'music.youtube.com',
    'youtu.be',
  };

  static const _audioExtensions = [
    '.mp3',
    '.m4a',
    '.aac',
    '.wav',
    '.ogg',
    '.opus',
    '.flac',
  ];
}

class NewsArticle {
  final String id;
  final String title;
  final String link;
  final String summary;
  final String source;
  final DateTime? publishedAt;
  final List<NewsArticleMediaLink> mediaLinks;

  const NewsArticle({
    required this.id,
    required this.title,
    required this.link,
    required this.summary,
    required this.source,
    required this.publishedAt,
    this.mediaLinks = const <NewsArticleMediaLink>[],
  });
}

class NewsArticleContent {
  final String text;
  final String url;

  const NewsArticleContent({
    required this.text,
    required this.url,
  });
}
