class RadioStation {
  final String name;
  final String streamUrl;
  final String languageCode;
  final String stationUuid;
  final String countryCode;
  final String countryName;
  final String language;
  final String tags;
  final String homepage;
  final String favicon;
  final String codec;
  final int bitrate;
  final int votes;
  final int clickCount;
  final String source;

  const RadioStation({
    required this.name,
    required this.streamUrl,
    required this.languageCode,
    this.stationUuid = '',
    this.countryCode = '',
    this.countryName = '',
    this.language = '',
    this.tags = '',
    this.homepage = '',
    this.favicon = '',
    this.codec = '',
    this.bitrate = 0,
    this.votes = 0,
    this.clickCount = 0,
    this.source = '',
  });

  String get detailsText {
    final parts = <String>[];
    if (countryName.trim().isNotEmpty) parts.add(countryName.trim());
    if (language.trim().isNotEmpty) parts.add(language.trim());
    if (tags.trim().isNotEmpty) parts.add(tags.trim());
    if (bitrate > 0) parts.add('$bitrate kbps');
    if (codec.trim().isNotEmpty) parts.add(codec.trim().toUpperCase());
    if (source.trim().isNotEmpty) parts.add(source.trim());
    return parts.isEmpty ? streamUrl : parts.join(' • ');
  }

  String get accessibilityLabel {
    final details = detailsText;
    return details.isEmpty ? name : '$name, $details';
  }

  RadioStation copyWith({
    String? name,
    String? streamUrl,
    String? languageCode,
    String? stationUuid,
    String? countryCode,
    String? countryName,
    String? language,
    String? tags,
    String? homepage,
    String? favicon,
    String? codec,
    int? bitrate,
    int? votes,
    int? clickCount,
    String? source,
  }) =>
      RadioStation(
        name: name ?? this.name,
        streamUrl: streamUrl ?? this.streamUrl,
        languageCode: languageCode ?? this.languageCode,
        stationUuid: stationUuid ?? this.stationUuid,
        countryCode: countryCode ?? this.countryCode,
        countryName: countryName ?? this.countryName,
        language: language ?? this.language,
        tags: tags ?? this.tags,
        homepage: homepage ?? this.homepage,
        favicon: favicon ?? this.favicon,
        codec: codec ?? this.codec,
        bitrate: bitrate ?? this.bitrate,
        votes: votes ?? this.votes,
        clickCount: clickCount ?? this.clickCount,
        source: source ?? this.source,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'streamUrl': streamUrl,
        'languageCode': languageCode,
        'stationUuid': stationUuid,
        'countryCode': countryCode,
        'countryName': countryName,
        'language': language,
        'tags': tags,
        'homepage': homepage,
        'favicon': favicon,
        'codec': codec,
        'bitrate': bitrate,
        'votes': votes,
        'clickCount': clickCount,
        'source': source,
      };

  factory RadioStation.fromJson(Map<String, dynamic> json) => RadioStation(
        name: (json['name'] ?? '').toString(),
        streamUrl: (json['streamUrl'] ?? '').toString(),
        languageCode: (json['languageCode'] ?? 'custom').toString(),
        stationUuid: (json['stationUuid'] ?? '').toString(),
        countryCode: (json['countryCode'] ?? '').toString(),
        countryName: (json['countryName'] ?? '').toString(),
        language: (json['language'] ?? '').toString(),
        tags: (json['tags'] ?? '').toString(),
        homepage: (json['homepage'] ?? '').toString(),
        favicon: (json['favicon'] ?? '').toString(),
        codec: (json['codec'] ?? '').toString(),
        bitrate: _intFromJson(json['bitrate']),
        votes: _intFromJson(json['votes']),
        clickCount: _intFromJson(json['clickCount']),
        source: (json['source'] ?? '').toString(),
      );

  static int _intFromJson(Object? value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse((value ?? '').toString()) ?? 0;
  }
}

class RadioLanguageOption {
  final String code;
  final String label;
  final int stationCount;

  const RadioLanguageOption(
    this.code, {
    this.label = '',
    this.stationCount = 0,
  });
}

class RadioCountryOption {
  final String code;
  final String label;
  final int stationCount;

  const RadioCountryOption(
    this.code, {
    this.label = '',
    this.stationCount = 0,
  });
}

class RadioGenreOption {
  final String value;
  final String? tag;

  const RadioGenreOption(this.value, this.tag);
}
