import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _arb(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

Set<String> _messageKeys(Map<String, dynamic> arb) =>
    arb.keys.where((key) => !key.startsWith('@')).toSet();

void main() {
  test('German ARB covers every localized Sonarpad message', () {
    final italian = _arb('lib/l10n/app_it.arb');
    final german = _arb('lib/l10n/app_de.arb');

    expect(german['@@locale'], 'de');
    expect(_messageKeys(german), _messageKeys(italian));
    expect(_messageKeys(german).length, greaterThanOrEqualTo(991));
  });

  test('German language name is localized in every app language', () {
    const expected = <String, String>{
      'it': 'Tedesco',
      'en': 'German',
      'fr': 'Allemand',
      'es': 'Alemán',
      'pt': 'Alemão',
      'pl': 'Niemiecki',
      'cs': 'Němčina',
      'de': 'Deutsch',
    };

    for (final entry in expected.entries) {
      final arb = _arb('lib/l10n/app_${entry.key}.arb');
      expect(arb['german'], entry.value, reason: 'locale ${entry.key}');
    }
  });

  test('German is wired into settings and generated localizations', () {
    final settings = File('lib/screens/settings_screen.dart').readAsStringSync();
    final service =
        File('lib/services/app_settings_service.dart').readAsStringSync();
    final generated = File('lib/l10n/app_localizations.dart').readAsStringSync();

    expect(settings, contains("AccessibleOption(value: 'de', label: l10n.german)"));
    expect(service, contains("'cs', 'de'"));
    expect(generated, contains("Locale('de')"));
    expect(generated, contains("case 'de':"));
  });

  test('calendar has German saints, holidays and daily quotes', () {
    final saints = File('lib/services/calendar/saints_data.dart').readAsStringSync();
    final calendar =
        File('lib/services/calendar/calendar_service.dart').readAsStringSync();

    expect(RegExp(r'^    "de":', multiLine: true).allMatches(saints).length, 365);
    expect(calendar, contains("if (lang == 'de')"));
    expect(calendar, contains('Tag der Deutschen Einheit'));
    expect(calendar, contains('final quotesDe = ['));
    expect(calendar, contains("case 'de':\n        list = quotesDe;"));
  });

  test('German dynamic services do not fall back to Italian', () {
    final news = File('lib/services/news_service.dart').readAsStringSync();
    final weather = File('lib/screens/weather_screen.dart').readAsStringSync();
    final radio = File('lib/screens/radio_screen.dart').readAsStringSync();
    final routes = File('lib/screens/route_screen.dart').readAsStringSync();

    expect(news, contains('NewsLanguage.german'));
    expect(news, contains('germanNewsSources'));
    expect(weather, contains("'de' => _weatherCodeLabelsDe"));
    expect(radio, contains("'de' => 'de'"));
    expect(routes, contains("'de' => 'de'"));
  });

  test('Italy-only home features and routes stay gated by Italian locale', () {
    final home = File('lib/screens/home_screen.dart').readAsStringSync();
    final main = File('lib/main.dart').readAsStringSync();
    expect(home, contains("final isItalian = l10n.localeName == 'it';"));
    expect(home, contains('if (_isRaiPlayValid && isItalian)'));
    expect(home, contains('if (_isSecretCodeValid && isItalian)'));
    expect(home, contains('if (showItalianPharmacyFeature)'));
    expect(main, contains('Widget italianOnlyRoute'));
    for (final route in [
      '/tv',
      '/tv/recordings',
      '/raiplaysound',
      '/raiplay',
      '/la7play',
      '/bdciechi',
      '/aifa',
      '/orari_apertura',
      '/italiaonline',
      '/audiodescriptions',
    ]) {
      expect(main, contains("'$route'"), reason: route);
    }
  });

  test('iOS advertises German and has German permission descriptions', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    final germanPlist =
        File('ios/Runner/de.lproj/InfoPlist.strings').readAsStringSync();

    expect(plist, contains('<string>de</string>'));
    expect(germanPlist, contains('NSCameraUsageDescription'));
    expect(germanPlist, contains('NSCalendarsUsageDescription'));
    expect(germanPlist, contains('NSContactsUsageDescription'));
  });

  test('shared UI labels live in ARB for every supported language', () {
    const locales = ['it', 'en', 'fr', 'es', 'pt', 'pl', 'cs', 'de'];
    const keys = [
      'letterJumpSelectLetter',
      'letterJumpSelected',
      'settingsToggleOn',
      'settingsToggleOff',
      'radioDirectoryLoading',
      'recentRadios',
      'noRecentRadios',
      'radioBrowseByCity',
      'radioCityInputHint',
      'radioPreviousPage',
      'radioNextPage',
      'radioPageOf',
      'radioNoResultsWithQuery',
      'radioNoResultsGeneric',
      'radioSearchRawError',
      'radioBrowserConnectionError',
      'documentIndexLoadingMessage',
      'documentIndexUnavailableMessage',
      'mediaCutterVolumeSummary',
      'mediaCutterDurationSummary',
      'mediaCutterSeekStepButton',
      'mediaCutterSeekStepTitle',
      'mediaCutterSeekStepSelected',
      'mediaCutterPartEffectTalkingGuitar',
      'mediaCutterPartEffectHaunting',
      'openItem',
      'clearSearch',
      'fileTypeLabel',
      'cinemaTrailerLoading',
      'cinemaNoTrailer',
      'radioScheduleDialogTitle',
      'radioScheduleOpenRequirement',
      'radioScheduleCancelAction',
      'radioLanguageTr',
      'radioCountryOptionTr',
      'radioCommunityLanguageTurkish',
    ];

    for (final locale in locales) {
      final arb = _arb('lib/l10n/app_$locale.arb');
      for (final key in keys) {
        expect(arb[key], isNotNull, reason: '$locale missing $key');
        expect(arb[key].toString().trim(), isNotEmpty,
            reason: '$locale empty $key');
      }
    }

    final settings = File('lib/screens/settings_screen.dart').readAsStringSync();
    final podcast = File('lib/screens/podcast_screen.dart').readAsStringSync();
    final radio = File('lib/screens/radio_screen.dart').readAsStringSync();
    expect(settings, isNot(contains('_selectLetterLabel(')));
    expect(podcast, isNot(contains('_selectLetterLabel(')));
    expect(radio, isNot(contains('_selectLetterLabel(')));

    final dynamicLabels =
        File('lib/l10n/localized_dynamic_labels.dart').readAsStringSync();
    final radioPlayer =
        File('lib/screens/radio_player_screen.dart').readAsStringSync();
    final tvRecordings =
        File('lib/screens/tv_recordings_screen.dart').readAsStringSync();
    expect(dynamicLabels, isNot(contains('_turkishLanguageLabel(')));
    expect(dynamicLabels, isNot(contains('_turkeyCountryLabel(')));
    expect(radioPlayer, isNot(contains('Programma registrazione')));
    expect(radioPlayer, isNot(contains('Annulla registrazione programmata')));
    expect(tvRecordings, isNot(contains('_openLabel(')));
    expect(tvRecordings, isNot(contains('_deleteLabel(')));
  });

  test('German news sources include the supplied RSS feeds', () {
    final sources =
        File('lib/services/news_sources/german_news_sources.dart').readAsStringSync();
    const expected = <String, String>{
      'Tagesschau': 'https://www.tagesschau.de/xml/rss2/',
      'ZDFheute': 'https://www.zdf.de/rss/zdf/nachrichten',
      'Deutschlandfunk Nachrichten':
          'https://www.deutschlandfunk.de/nachrichten-100.xml',
      'Deutsche Welle Deutsch': 'https://rss.dw.com/xml/rss-de-all',
      'DER SPIEGEL': 'https://www.spiegel.de/schlagzeilen/index.rss',
      'ZEIT ONLINE': 'https://newsfeed.zeit.de/index',
      'Frankfurter Allgemeine Zeitung': 'https://www.faz.net/rss/aktuell/',
      'Süddeutsche Zeitung': 'https://rss.sueddeutsche.de/rss/Topthemen',
      'Neue Zürcher Zeitung': 'https://www.nzz.ch/recent.rss',
      'DER STANDARD': 'https://www.derstandard.at/rss',
      'heise online': 'https://www.heise.de/rss/heise-atom.xml',
      'Golem.de': 'https://rss.golem.de/rss.php?feed=RSS2.0',
      'Netzpolitik.org': 'https://netzpolitik.org/feed/',
      'Spektrum.de':
          'https://www.spektrum.de/alias/rss/spektrum-de-rss-feed/996406',
    };
    for (final entry in expected.entries) {
      expect(sources, contains("name: '${entry.key}'"));
      expect(sources, contains(entry.value));
    }
  });

  test('document paragraphs stay activatable without the UIKit button trait', () {
    final document =
        File('lib/screens/document_reader_screen.dart').readAsStringSync();
    final native =
        File('ios/Runner/SonarpadNativeAccessibleView.swift').readAsStringSync();

    expect(document, contains('accessibilityButtonTrait: false'));
    expect(document, contains("kind: canInteract ? 'action' : 'text'"));
    expect(document, contains("id: 'reader_instruction'"));
    expect(document, contains('title: _paragraphSelectionMode'));
    expect(document, contains(': l10n.documentReaderEditHint'));
    expect(document, isNot(contains('canInteract && i == 0\n                ? l10n.documentEditParagraphActionHint')));
    expect(native,
        contains('if row.accessibilityButtonTrait && (row.kind == "action"'));
    expect(native, contains('cell.accessoryType = row.accessibilityButtonTrait'));
    expect(native, contains('case "action", "button":'));
  });

}
