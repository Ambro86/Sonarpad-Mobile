import '../l10n/app_localizations.dart';
import '../services/home_customization_service.dart';

Set<String> availableHomeItemIds({
  required bool isItalian,
  required bool isTvCodeValid,
  required bool isRaiPlayValid,
  required bool isRaiPlaySoundCodeValid,
}) {
  final ids = <String>{
    HomeItemIds.documents,
    HomeItemIds.calendar,
    HomeItemIds.news,
    HomeItemIds.weather,
    HomeItemIds.podcasts,
    HomeItemIds.sonarTube,
    HomeItemIds.createAiAudioDescription,
    HomeItemIds.convertMedia,
    HomeItemIds.mediaCutter,
    HomeItemIds.cinema,
    HomeItemIds.radio,
    HomeItemIds.wikipedia,
    HomeItemIds.voiceDictionary,
    HomeItemIds.route,
    HomeItemIds.settings,
    HomeItemIds.info,
  };

  if (isItalian) {
    ids.addAll({
      HomeItemIds.treccani,
      HomeItemIds.digitalLibrary,
      HomeItemIds.openingHours,
      HomeItemIds.pharmacy,
    });
    if (isTvCodeValid) ids.add(HomeItemIds.tv);
    if (isRaiPlayValid) {
      ids.add(HomeItemIds.raiPlay);
      ids.add(HomeItemIds.la7Play);
    }
    if (isRaiPlaySoundCodeValid) {
      ids.add(HomeItemIds.raiPlaySound);
      ids.add(HomeItemIds.audioDescriptions);
      ids.add(HomeItemIds.directory);
    }
    if (isTvCodeValid || isRaiPlayValid || isRaiPlaySoundCodeValid) {
      ids.add(HomeItemIds.sonarpadAudioDescriptions);
    }
  }

  return ids;
}

String homeItemLabel(AppLocalizations l10n, String id) {
  switch (id) {
    case HomeItemIds.documents:
      return l10n.documents;
    case HomeItemIds.calendar:
      return l10n.calendar;
    case HomeItemIds.news:
      return l10n.news;
    case HomeItemIds.weather:
      return l10n.meteoTitle;
    case HomeItemIds.podcasts:
      return l10n.podcasts;
    case HomeItemIds.sonarTube:
      return l10n.sonarTubeTitle;
    case HomeItemIds.createAiAudioDescription:
      return l10n.audioDescriptionCreateAiTitle;
    case HomeItemIds.convertMedia:
      return l10n.convertMediaTitle;
    case HomeItemIds.mediaCutter:
      return l10n.mediaCutterTitle;
    case HomeItemIds.cinema:
      return l10n.cinemaTitle;
    case HomeItemIds.radio:
      return l10n.radio;
    case HomeItemIds.tv:
      return l10n.homeTv;
    case HomeItemIds.raiPlaySound:
      return l10n.homeRaiPlaySound;
    case HomeItemIds.raiPlay:
      return l10n.homeRaiPlay;
    case HomeItemIds.la7Play:
      return l10n.homeLa7Play;
    case HomeItemIds.audioDescriptions:
      return l10n.audiodescriptionTitle;
    case HomeItemIds.sonarpadAudioDescriptions:
      return l10n.sonarpadAudiodescriptionsTitle;
    case HomeItemIds.wikipedia:
      return l10n.importFromWikipedia;
    case HomeItemIds.treccani:
      return l10n.treccaniTitle;
    case HomeItemIds.voiceDictionary:
      return l10n.voiceDictionaryTitle;
    case HomeItemIds.digitalLibrary:
      return l10n.homeDigitalLibrary;
    case HomeItemIds.route:
      return l10n.routeTitle;
    case HomeItemIds.openingHours:
      return l10n.homeOpeningHours;
    case HomeItemIds.directory:
      return l10n.homeDirectory;
    case HomeItemIds.pharmacy:
      return l10n.pharmacyFeatureTitle;
    case HomeItemIds.settings:
      return l10n.settings;
    case HomeItemIds.info:
      return l10n.info;
  }
  return id;
}
