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

  const PodcastCategory(
    this.genreId,
    this.name, {
    this.englishName,
    this.frenchName,
    this.spanishName,
  });

  String nameForLanguage(String languageCode) => switch (languageCode) {
        'en' => englishName ?? name,
        'fr' => frenchName ?? englishName ?? name,
        'es' => spanishName ?? englishName ?? name,
        _ => name,
      };
}

class PodcastEpisode {
  final String title;
  final String description;
  final String audioUrl;
  final DateTime? publishedAt;
  final String? id;

  const PodcastEpisode({
    required this.title,
    required this.description,
    required this.audioUrl,
    this.publishedAt,
    this.id,
  });
}
