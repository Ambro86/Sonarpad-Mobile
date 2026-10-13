import '../l10n/app_localizations_lookup.dart';

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

  const PodcastCategory(this.genreId);

  /// Preserves the original Italian name getter for callers without a locale.
  String get name => nameForLanguage('it');

  String nameForLanguage(String languageCode) {
    final l10n = lookupSupportedAppLocalizations(
      languageCode,
      fallbackLanguage: 'it',
    );
    return switch (genreId) {
      null => l10n.podcastCategoryAll,
      1301 => l10n.podcastCategoryArts,
      1321 => l10n.podcastCategoryBusiness,
      1303 => l10n.podcastCategoryComedy,
      1304 => l10n.podcastCategoryEducation,
      1483 => l10n.podcastCategoryFiction,
      1511 => l10n.podcastCategoryGovernment,
      1512 => l10n.podcastCategoryHealthAndFitness,
      1487 => l10n.podcastCategoryHistory,
      1305 => l10n.podcastCategoryKidsAndFamily,
      1502 => l10n.podcastCategoryLeisure,
      1310 => l10n.podcastCategoryMusic,
      1489 => l10n.podcastCategoryNews,
      1314 => l10n.podcastCategoryReligionAndSpirituality,
      1533 => l10n.podcastCategoryScience,
      1324 => l10n.podcastCategorySocietyAndCulture,
      1545 => l10n.podcastCategorySports,
      1318 => l10n.podcastCategoryTechnology,
      1488 => l10n.podcastCategoryTrueCrime,
      1309 => l10n.podcastCategoryTvAndFilm,
      1482 => l10n.podcastCategoryBooks,
      1402 => l10n.podcastCategoryDesign,
      1459 => l10n.podcastCategoryFashionAndBeauty,
      1306 => l10n.podcastCategoryFood,
      1405 => l10n.podcastCategoryPerformingArts,
      1406 => l10n.podcastCategoryVisualArts,
      1410 => l10n.podcastCategoryCareers,
      1493 => l10n.podcastCategoryEntrepreneurship,
      1412 => l10n.podcastCategoryInvesting,
      1491 => l10n.podcastCategoryManagement,
      1492 => l10n.podcastCategoryMarketing,
      1494 => l10n.podcastCategoryNonProfit,
      1496 => l10n.podcastCategoryComedyInterviews,
      1495 => l10n.podcastCategoryImprov,
      1497 => l10n.podcastCategoryStandUp,
      1501 => l10n.podcastCategoryCourses,
      1499 => l10n.podcastCategoryHowTo,
      1498 => l10n.podcastCategoryLanguageLearning,
      1500 => l10n.podcastCategorySelfImprovement,
      1486 => l10n.podcastCategoryComedyFiction,
      1484 => l10n.podcastCategoryDrama,
      1485 => l10n.podcastCategoryScienceFiction,
      1513 => l10n.podcastCategoryAlternativeHealth,
      1514 => l10n.podcastCategoryFitness,
      1518 => l10n.podcastCategoryMedicine,
      1517 => l10n.podcastCategoryMentalHealth,
      1515 => l10n.podcastCategoryNutrition,
      1516 => l10n.podcastCategorySexuality,
      1519 => l10n.podcastCategoryEducationForKids,
      1521 => l10n.podcastCategoryParenting,
      1522 => l10n.podcastCategoryPetsAndAnimals,
      1520 => l10n.podcastCategoryStoriesForKids,
      1510 => l10n.podcastCategoryAnimationAndManga,
      1503 => l10n.podcastCategoryAutomotive,
      1504 => l10n.podcastCategoryAviation,
      1506 => l10n.podcastCategoryCrafts,
      1507 => l10n.podcastCategoryGames,
      1505 => l10n.podcastCategoryHobbies,
      1508 => l10n.podcastCategoryHomeAndGarden,
      1509 => l10n.podcastCategoryVideoGames,
      1523 => l10n.podcastCategoryMusicCommentary,
      1524 => l10n.podcastCategoryMusicHistory,
      1525 => l10n.podcastCategoryMusicInterviews,
      1490 => l10n.podcastCategoryBusinessNews,
      1526 => l10n.podcastCategoryDailyNews,
      1531 => l10n.podcastCategoryEntertainmentNews,
      1530 => l10n.podcastCategoryNewsCommentary,
      1527 => l10n.podcastCategoryPolitics,
      1529 => l10n.podcastCategorySportsNews,
      1528 => l10n.podcastCategoryTechNews,
      1438 => l10n.podcastCategoryBuddhism,
      1439 => l10n.podcastCategoryChristianity,
      1463 => l10n.podcastCategoryHinduism,
      1440 => l10n.podcastCategoryIslam,
      1441 => l10n.podcastCategoryJudaism,
      1532 => l10n.podcastCategoryReligion,
      1444 => l10n.podcastCategorySpirituality,
      1538 => l10n.podcastCategoryAstronomy,
      1539 => l10n.podcastCategoryChemistry,
      1540 => l10n.podcastCategoryEarthSciences,
      1541 => l10n.podcastCategoryLifeSciences,
      1536 => l10n.podcastCategoryMathematics,
      1534 => l10n.podcastCategoryNaturalSciences,
      1537 => l10n.podcastCategoryNature,
      1542 => l10n.podcastCategoryPhysics,
      1535 => l10n.podcastCategorySocialSciences,
      1543 => l10n.podcastCategoryDocumentary,
      1302 => l10n.podcastCategoryPersonalJournals,
      1443 => l10n.podcastCategoryPhilosophy,
      1320 => l10n.podcastCategoryPlacesAndTravel,
      1544 => l10n.podcastCategoryRelationships,
      1549 => l10n.podcastCategoryBaseball,
      1548 => l10n.podcastCategoryBasketball,
      1554 => l10n.podcastCategoryCricket,
      1560 => l10n.podcastCategoryFantasySports,
      1547 => l10n.podcastCategoryFootball,
      1553 => l10n.podcastCategoryGolf,
      1550 => l10n.podcastCategoryHockey,
      1552 => l10n.podcastCategoryRugby,
      1551 => l10n.podcastCategoryRunning,
      1546 => l10n.podcastCategorySoccer,
      1558 => l10n.podcastCategorySwimming,
      1556 => l10n.podcastCategoryTennis,
      1557 => l10n.podcastCategoryVolleyball,
      1559 => l10n.podcastCategoryWilderness,
      1555 => l10n.podcastCategoryWrestling,
      1562 => l10n.podcastCategoryAfterShows,
      1564 => l10n.podcastCategoryFilmHistory,
      1565 => l10n.podcastCategoryFilmInterviews,
      1563 => l10n.podcastCategoryFilmReviews,
      1561 => l10n.podcastCategoryTvReviews,
      _ => genreId.toString(),
    };
  }
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
  final bool isLive;

  const PodcastEpisode({
    required this.title,
    required this.description,
    required this.audioUrl,
    this.videoUrl,
    this.publishedAt,
    this.id,
    this.chaptersUrl,
    this.chaptersType,
    this.isLive = false,
  });
}
