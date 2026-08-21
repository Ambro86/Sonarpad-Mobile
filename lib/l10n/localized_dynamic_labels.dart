import 'app_localizations.dart';

extension LocalizedDynamicLabels on AppLocalizations {
  String radioLanguageLabel(String code) => switch (code) {
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
}
