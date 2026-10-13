import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sonarpad_mobile_starter/l10n/app_localizations_lookup.dart';
import 'package:sonarpad_mobile_starter/services/podcast_service.dart';

void main() {
  test('Romanian phase 2 translates a substantial part of the ARB catalog', () {
    final en = jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync()) as Map<String, dynamic>;
    final ro = jsonDecode(File('lib/l10n/app_ro.arb').readAsStringSync()) as Map<String, dynamic>;
    final keys = en.keys.where((key) => !key.startsWith('@')).toList();
    final translated = keys.where((key) => en[key] != ro[key]).length;

    expect(ro['@@locale'], 'ro');
    expect(translated, greaterThanOrEqualTo(600));
    expect(ro['audioDescriptionCreateAiTitle'], 'Creează audiodescriere cu IA');
    expect(ro['radioBrowseByLanguage'], 'Răsfoiește după limbă');
    expect(ro['recordings'], 'Înregistrări');
    expect(ro['gutenbergSearchLabel'], 'Caută carte sau autor');
  });

  test('AI audio description supports Romanian as an actual target language', () {
    final screen = File('lib/screens/create_ai_audiodescription_screen.dart').readAsStringSync();
    final service = File('lib/services/ai_audiodescription_service.dart').readAsStringSync();
    final projectStrings = File('lib/services/audio_description_project_strings.dart').readAsStringSync();

    expect(screen, contains("AccessibleOption(value: 'ro', label: l10n.languageLabel('ro'))"));
    expect(service, contains("_WindowsPromptLanguage('Romanian'"));
    expect(service, contains("if (code.startsWith('ro')) return 'ro-RO';"));
    expect(service, contains('O mașină gonește pe stradă.'));
    expect(projectStrings, contains('_l10n.audioDescriptionProjectEditorTitle'));
    expect(lookupSupportedAppLocalizations('ro').audioDescriptionProjectEditorTitle,
        'Editează proiectul de audiodescriere');
  });

  test('Romanian routes use Romania and Romanian service messages', () {
    final route = File('lib/services/route_service.dart').readAsStringSync();
    final screen = File('lib/screens/route_screen.dart').readAsStringSync();

    expect(screen, contains("'ro' => 'ro'"));
    expect(screen, contains("value: 'ro'"));
    expect(route, contains("case 'ro':"));
    expect(route, contains("return 'ROU';"));
    final l10n = lookupSupportedAppLocalizations('ro');
    expect(route, contains('_strings(language).routeServiceInvalidAddress'));
    expect(l10n.routeServiceInvalidAddress, 'Adresă nevalidă');
    expect(l10n.routeServiceDestinationNotFound,
        'Adresa de destinație nu a fost găsită');
  });

  test('Romanian radio is supported by directory and community flows', () {
    final radio = File('lib/services/radio_service.dart').readAsStringSync();
    final screen = File('lib/screens/radio_screen.dart').readAsStringSync();
    final add = File('lib/screens/add_radio_screen.dart').readAsStringSync();

    expect(radio, contains("RadioLanguageOption('ro')"));
    expect(radio, contains("RadioCountryOption('ro')"));
    expect(radio, contains("'romanian',"));
    expect(radio, contains("'ro' => 'romanian'"));
    expect(radio, contains("'romanian' || 'romana' => 'ro'"));
    expect(screen, contains("'ro' => 'ro'"));
    expect(add, contains("'ro' => 'romanian'"));
    expect(add, contains('uiLanguage: l10n.localeName'));
  });

  test('Romanian Podcasts use Romania and localized Apple categories', () {
    final service = File('lib/services/podcast_service.dart').readAsStringSync();
    final screen = File('lib/screens/podcast_screen.dart').readAsStringSync();

    expect(service, contains("PodcastCountry('ro', 'Romania')"));
    expect(screen, contains("case 'ro':"));
    expect(screen, contains("return 'ro';"));
    expect(PodcastService.categories, hasLength(111));
    expect(PodcastService.categories.first.nameForLanguage('ro'),
        'Toate categoriile');
    expect(PodcastService.categories
        .singleWhere((category) => category.genreId == 1489)
        .nameForLanguage('ro-RO'), 'Știri');
    for (final category in PodcastService.categories) {
      expect(category.nameForLanguage('ro'), isNotEmpty);
      expect(category.nameForLanguage('ro'), category.nameForLanguage('ro_RO'));
    }
  });

  test('Romanian is wired into remaining language-aware services', () {
    final changelog = File('lib/services/changelog_service.dart').readAsStringSync();
    final weather = File('lib/services/news/weather_service.dart').readAsStringSync();
    final weatherScreen = File('lib/screens/weather_screen.dart').readAsStringSync();
    final html = File('lib/services/html_reader_service.dart').readAsStringSync();
    final wikipedia = File('lib/services/wikipedia_service.dart').readAsStringSync();
    final settings = File('lib/services/app_settings_service.dart').readAsStringSync();

    expect(changelog, contains("'uk', 'ro'"));
    expect(weather, contains("'ro' => 'ro'"));
    final l10n = lookupSupportedAppLocalizations('ro');
    expect(weatherScreen, contains('l10n.weatherConditionClearSky'));
    expect(l10n.weatherConditionClearSky, 'Cer senin');
    expect(html, contains('.articleUnknownTitle'));
    expect(l10n.articleUnknownTitle, 'Titlu necunoscut');
    expect(wikipedia, contains('l10n.wikipediaSearchHttpError(statusCode)'));
    expect(l10n.wikipediaSearchHttpError(503), 'Eroare Wikipedia: 503');
    expect(settings, contains("'ro' || 'ro-RO' => 'ro-RO-AlinaNeural'"));
  });
}
