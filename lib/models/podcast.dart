class PodcastSubscription {
  final String title;
  final String feedUrl;
  final String? artworkUrl;

  const PodcastSubscription({
    required this.title,
    required this.feedUrl,
    this.artworkUrl,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'feedUrl': feedUrl,
        'artworkUrl': artworkUrl,
      };

  factory PodcastSubscription.fromJson(Map<String, dynamic> json) =>
      PodcastSubscription(
        title: json['title'] as String,
        feedUrl: json['feedUrl'] as String,
        artworkUrl: json['artworkUrl'] as String?,
      );
}

class PodcastSearchResult {
  final String title;
  final String author;
  final String feedUrl;
  final String? artworkUrl;

  const PodcastSearchResult({
    required this.title,
    required this.author,
    required this.feedUrl,
    this.artworkUrl,
  });
}

class PodcastDetails {
  final String title;
  final String author;
  final String description;
  final String feedUrl;
  final String? artworkUrl;

  const PodcastDetails({
    required this.title,
    required this.author,
    required this.description,
    required this.feedUrl,
    this.artworkUrl,
  });
}

class PodcastCountry {
  final String code;
  final String name;

  const PodcastCountry(this.code, this.name);
}

class PodcastCategory {
  final int? genreId;
  final String name;
  final String? englishName;
  final String? frenchName;
  final String? spanishName;
  final String? portugueseName;
  final String? polishName;
  final String? czechName;
  final String? germanName;

  const PodcastCategory(
    this.genreId,
    this.name, {
    this.englishName,
    this.frenchName,
    this.spanishName,
    this.portugueseName,
    this.polishName,
    this.czechName,
    this.germanName,
  });

  String nameForLanguage(String languageCode) => switch (languageCode) {
        'en' => englishName ?? name,
        'fr' => frenchName ?? englishName ?? name,
        'es' => spanishName ?? englishName ?? name,
        'pt' => portugueseName ?? englishName ?? name,
        'pl' => polishName ?? englishName ?? name,
        'cs' => czechName ?? englishName ?? name,
        'de' => germanName ?? englishName ?? name,
        _ => name,
      };
}


class PodcastChapter {
  final Duration start;
  final String title;
  final String? url;
  final String? imageUrl;

  const PodcastChapter({
    required this.start,
    required this.title,
    this.url,
    this.imageUrl,
  });
}

class PodcastEpisode {
  final String title;
  final String description;
  final String audioUrl;
  final String? videoUrl;
  final DateTime? publishedAt;
  final String? id;
  final String? chaptersUrl;
  final String? chaptersType;

  const PodcastEpisode({
    required this.title,
    required this.description,
    required this.audioUrl,
    this.videoUrl,
    this.publishedAt,
    this.id,
    this.chaptersUrl,
    this.chaptersType,
  });
}
