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

  factory PodcastSubscription.fromJson(Map<String, dynamic> json) => PodcastSubscription(
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

class PodcastEpisode {
  final String title;
  final String description;
  final String audioUrl;
  final DateTime? publishedAt;

  const PodcastEpisode({
    required this.title,
    required this.description,
    required this.audioUrl,
    this.publishedAt,
  });
}
