import 'package:flutter_test/flutter_test.dart';
import 'package:sonarpad_mobile_starter/l10n/app_localizations_lookup.dart';
import 'package:sonarpad_mobile_starter/models/podcast.dart';
import 'package:sonarpad_mobile_starter/screens/weather_screen.dart';
import 'package:sonarpad_mobile_starter/services/podcast_service.dart';

void main() {
  PodcastCategory category(int? genreId) => PodcastService.categories
      .singleWhere((category) => category.genreId == genreId);

  test('every podcast category has a Turkish display name', () {
    expect(PodcastService.categories, hasLength(111));
    expect(PodcastService.categories.first.genreId, isNull);
    expect(
      PodcastService.categories.map((category) => category.genreId).toSet(),
      hasLength(111),
    );

    for (final category in PodcastService.categories) {
      final label = category.nameForLanguage('tr');
      expect(label, isNotEmpty);
      expect(label, isNot(category.genreId.toString()));
      // These two category names are also standard Turkish words.
      if (![1514, 1553].contains(category.genreId)) {
        expect(label, isNot(category.nameForLanguage('en')));
      }
    }
  });

  test('podcast category labels keep stable genre meanings in Turkish', () {
    expect(category(null).nameForLanguage('tr'), 'Tüm kategoriler');
    expect(category(1301).nameForLanguage('tr'), 'Sanat');
    expect(category(1489).nameForLanguage('tr'), 'Haberler');
    expect(category(1488).nameForLanguage('tr'), 'Gerçek suç hikâyeleri');
    expect(category(1546).nameForLanguage('tr'), 'Futbol');
    expect(category(1547).nameForLanguage('tr'), 'Amerikan futbolu');
    expect(category(1554).nameForLanguage('tr'), 'Kriket');
    expect(category(null).name, 'Tutte le categorie');
  });

  test('podcast category locale variants retain their labels and fallback', () {
    for (final category in PodcastService.categories) {
      expect(category.nameForLanguage('tr_TR'), category.nameForLanguage('tr'));
      expect(category.nameForLanguage('tr-TR'), category.nameForLanguage('tr'));
      expect(category.nameForLanguage('pt_BR'), category.nameForLanguage('pt'));
      expect(category.nameForLanguage('zh_CN'), category.nameForLanguage('zh'));
      expect(category.nameForLanguage('xx'), category.nameForLanguage('it'));
    }
    expect(category(null).nameForLanguage('pt_BR'), 'Todas as categorias');
    expect(category(null).nameForLanguage('zh_CN'), '所有类别');
  });

  const weatherCodes = [
    0, 1, 2, 3, 45, 48, 51, 53, 55, 56, 57, 61, 63, 65,
    66, 67, 71, 73, 75, 77, 80, 81, 82, 85, 86, 95, 96, 99,
  ];

  test('all existing WMO conditions are translated into Turkish', () {
    final tr = lookupSupportedAppLocalizations('tr');
    final en = lookupSupportedAppLocalizations('en');
    final it = lookupSupportedAppLocalizations('it');
    expect(weatherCodes, hasLength(28));
    for (final code in weatherCodes) {
      final label = weatherConditionLabel(tr, code);
      expect(label, isNotEmpty);
      expect(label, isNot(code.toString()));
      expect(label, isNot(weatherConditionLabel(en, code)));
      expect(label, isNot(weatherConditionLabel(it, code)));
    }
    expect(weatherConditionLabel(tr, 0), 'Açık');
    expect(weatherConditionLabel(tr, 48), 'Kırağı oluşturan sis');
    expect(weatherConditionLabel(tr, 61), 'Hafif yağmur');
    expect(weatherConditionLabel(tr, 85), 'Hafif kar sağanağı');
    expect(weatherConditionLabel(tr, 95), 'Gök gürültülü fırtına');
    expect(weatherConditionLabel(tr, 99),
        'Şiddetli doluyla birlikte gök gürültülü fırtına');
  });

  test('weather regional labels and the existing Czech fallback are retained',
      () {
    final localePairs = [
      ['tr_TR', 'tr'],
      ['tr-TR', 'tr'],
      ['pt_BR', 'pt'],
      ['zh_CN', 'zh'],
      ['cs', 'it'],
    ];
    for (final pair in localePairs) {
      final variant = lookupSupportedAppLocalizations(pair.first);
      final base = lookupSupportedAppLocalizations(pair.last);
      for (final code in weatherCodes) {
        expect(weatherConditionLabel(variant, code),
            weatherConditionLabel(base, code));
      }
    }
  });

  test('unknown weather codes keep the existing numeric fallback', () {
    for (final locale in ['tr', 'tr_TR', 'en', 'it', 'cs', 'pt_BR', 'zh_CN']) {
      final l10n = lookupSupportedAppLocalizations(locale);
      expect(weatherConditionLabel(l10n, 123), '123');
    }
  });
}
