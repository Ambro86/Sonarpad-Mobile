import 'app_localizations.dart';

extension LocalizedDynamicLabels on AppLocalizations {
  String languageLabel(String code) {
    final normalized = code.trim().replaceAll('_', '-').toLowerCase();
    final base = normalized.split('-').first;
    return switch (base) {
      'it' => radioLanguageIt,
      'en' => radioLanguageEn,
      'tr' => radioLanguageTr,
      'de' => radioLanguageDe,
      'es' => radioLanguageEs,
      'pt' => radioLanguagePt,
      'sv' => radioLanguageSv,
      'vi' => radioLanguageVi,
      'cs' => radioLanguageCs,
      'pl' => radioLanguagePl,
      'fr' => radioLanguageFr,
      'sr' => radioLanguageSr,
      'uk' => radioLanguageUk,
      'hi' => radioLanguageHi,
      'lt' => radioLanguageLt,
      'ru' => radioLanguageRu,
      'zh' => radioLanguageZh,
      _ => code,
    };
  }

  String radioLanguageLabel(String code) => languageLabel(code);

  String radioCountryLabel(String code) => switch (code) {
        'it' => radioCountryOptionIt,
        'us' => radioCountryOptionUs,
        'gb' => radioCountryOptionGb,
        'tr' => radioCountryOptionTr,
        'fr' => radioCountryOptionFr,
        'es' => radioCountryOptionEs,
        'de' => radioCountryOptionDe,
        'ch' => radioCountryOptionCh,
        'at' => radioCountryOptionAt,
        'be' => radioCountryOptionBe,
        'nl' => radioCountryOptionNl,
        'pt' => radioCountryOptionPt,
        'br' => radioCountryOptionBr,
        'ar' => radioCountryOptionAr,
        'mx' => radioCountryOptionMx,
        'ca' => radioCountryOptionCa,
        'au' => radioCountryOptionAu,
        'ie' => radioCountryOptionIe,
        'se' => radioCountryOptionSe,
        'pl' => radioCountryOptionPl,
        'jp' => radioCountryOptionJp,
        'cn' => chinaCountryName,
        _ => code.toUpperCase(),
      };

  String radioGenreLabel(String value) => switch (value) {
        'all' => radioGenreOptionAll,
        'news' => radioGenreOptionNews,
        'music' => radioGenreOptionMusic,
        'sport' => radioGenreOptionSport,
        'talk' => radioGenreOptionTalk,
        'pop' => radioGenreOptionPop,
        'rock' => radioGenreOptionRock,
        'classical' => radioGenreOptionClassical,
        'jazz' => radioGenreOptionJazz,
        'dance' => radioGenreOptionDance,
        'blues' => radioGenreOptionBlues,
        'country' => radioGenreOptionCountry,
        'hiphop' => radioGenreOptionHiphop,
        'electronic' => radioGenreOptionElectronic,
        'latin' => radioGenreOptionLatin,
        'reggae' => radioGenreOptionReggae,
        'metal' => radioGenreOptionMetal,
        'folk' => radioGenreOptionFolk,
        'religion' => radioGenreOptionReligion,
        'local' => radioGenreOptionLocal,
        'culture' => radioGenreOptionCulture,
        'oldies' => radioGenreOptionOldies,
        'kids' => radioGenreOptionKids,
        'ambient' => radioGenreOptionAmbient,
        _ => value,
      };

  String radioCommunityLanguageLabel(String value) => switch (value) {
        'italian' => radioCommunityLanguageItalian,
        'english' => radioCommunityLanguageEnglish,
        'turkish' => radioCommunityLanguageTurkish,
        'spanish' => radioCommunityLanguageSpanish,
        'french' => radioCommunityLanguageFrench,
        'german' => radioCommunityLanguageGerman,
        'portuguese' => radioCommunityLanguagePortuguese,
        'swedish' => radioCommunityLanguageSwedish,
        'vietnamese' => radioCommunityLanguageVietnamese,
        'czech' => radioCommunityLanguageCzech,
        'polish' => radioCommunityLanguagePolish,
        'serbian' => radioCommunityLanguageSerbian,
        'ukrainian' => radioCommunityLanguageUkrainian,
        'lithuanian' => radioCommunityLanguageLithuanian,
        'russian' => radioCommunityLanguageRussian,
        'chinese' => radioCommunityLanguageChinese,
        'hindi' => radioCommunityLanguageHindi,
        _ => value,
      };


  String formatDistance(double meters) {
    if (meters < 1000) return routeDistanceMeters(meters.round());
    return routeDistanceKilometers((meters / 1000).toStringAsFixed(1));
  }

  String formatDuration(double seconds) {
    final minutes = (seconds / 60).round();
    if (minutes < 60) return routeDurationMinutes(minutes);
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    return routeDurationHoursMinutes(hours, mins);
  }

  /// Compact playback clock used by media players. Durations below one hour
  /// stay as m:ss; from one hour onward the hour is shown explicitly.
  String formatPlaybackClock(Duration duration) {
    final totalSeconds = duration.inSeconds < 0 ? 0 : duration.inSeconds;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:$seconds';
    }
    return '$minutes:$seconds';
  }

  /// Natural-language playback duration for screen readers. Reuses the
  /// already-localized duration units shared with the Media Cutter.
  String formatPlaybackSpokenDuration(Duration duration) {
    var totalSeconds = duration.inSeconds;
    if (totalSeconds <= 0 && duration.inMilliseconds > 0) totalSeconds = 1;
    if (totalSeconds < 0) totalSeconds = 0;

    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    final units = <String>[];

    if (hours > 0) units.add(_playbackDurationUnit('hour', hours));
    if (minutes > 0) units.add(_playbackDurationUnit('minute', minutes));
    if (seconds > 0 || units.isEmpty) {
      units.add(_playbackDurationUnit('second', seconds));
    }

    if (units.length == 1) return units.first;
    final connector = ' $mediaCutterDurationAnd ';
    if (units.length == 2) return '${units[0]}$connector${units[1]}';
    return '${units.sublist(0, units.length - 1).join(', ')}$connector${units.last}';
  }

  String _playbackDurationUnit(String unit, int value) {
    final form = switch (localeName) {
      'pl' => () {
          final mod10 = value % 10;
          final mod100 = value % 100;
          if (value == 1) return 0;
          if (mod10 >= 2 && mod10 <= 4 && !(mod100 >= 12 && mod100 <= 14)) {
            return 1;
          }
          return 2;
        }(),
      'cs' => value == 1 ? 0 : (value >= 2 && value <= 4 ? 1 : 2),
      _ => value == 1 ? 0 : 2,
    };

    final word = switch ((unit, form)) {
      ('hour', 0) => mediaCutterDurationHourOne,
      ('hour', 1) => mediaCutterDurationHourFew,
      ('hour', _) => mediaCutterDurationHourMany,
      ('minute', 0) => mediaCutterDurationMinuteOne,
      ('minute', 1) => mediaCutterDurationMinuteFew,
      ('minute', _) => mediaCutterDurationMinuteMany,
      ('second', 0) => mediaCutterDurationSecondOne,
      ('second', 1) => mediaCutterDurationSecondFew,
      _ => mediaCutterDurationSecondMany,
    };
    return '$value $word';
  }
}
