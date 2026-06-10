class RadioStation {
  final String name;
  final String streamUrl;
  final String languageCode;

  const RadioStation({
    required this.name,
    required this.streamUrl,
    required this.languageCode,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'streamUrl': streamUrl,
        'languageCode': languageCode,
      };

  factory RadioStation.fromJson(Map<String, dynamic> json) => RadioStation(
        name: json['name'] as String,
        streamUrl: json['streamUrl'] as String,
        languageCode: json['languageCode'] as String? ?? 'custom',
      );
}

class RadioLanguageOption {
  final String code;

  const RadioLanguageOption(this.code);
}

class RadioCountryOption {
  final String code;

  const RadioCountryOption(this.code);
}

class RadioGenreOption {
  final String value;
  final String? tag;

  const RadioGenreOption(this.value, this.tag);
}
