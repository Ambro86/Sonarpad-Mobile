class TmdbMovie {
  final int id;
  final String title;
  final String overview;
  final String releaseDate;
  
  TmdbMovie({
    required this.id,
    required this.title,
    required this.overview,
    required this.releaseDate,
  });

  factory TmdbMovie.fromJson(Map<String, dynamic> json) {
    return TmdbMovie(
      id: json['id'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      overview: json['overview'] as String? ?? '',
      releaseDate: json['release_date'] as String? ?? '',
    );
  }
}
