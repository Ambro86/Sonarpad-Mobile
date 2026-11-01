import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonarpad_mobile_starter/l10n/app_localizations.dart';
import 'package:sonarpad_mobile_starter/l10n/app_localizations_lookup.dart';

void main() {
  test('Dutch localization delegate is supported and produces Dutch strings', () {
    expect(AppLocalizations.supportedLocales, contains(const Locale('nl')));
    expect(AppLocalizations.delegate.isSupported(const Locale('nl')), isTrue);
    expect(lookupSupportedAppLocalizations('nl').appLanguage, 'App-taal');
  });

  test('Dutch choices exist in dictionary, routes and content catalogues', () {
    final dictionary = File('lib/screens/online_dictionary_screen.dart').readAsStringSync();
    final routes = File('lib/screens/route_screen.dart').readAsStringSync();
    final wikipedia = File('lib/screens/wikipedia_screen.dart').readAsStringSync();
    final gutenberg = File('lib/screens/gutenberg_screen.dart').readAsStringSync();
    expect(dictionary, contains("    'nl',"));
    expect(routes, contains("AccessibleOption(value: 'nl', label: l10n.radioCountryOptionNl)"));
    expect(routes, contains("value: 'nl', child: Text(l10n.radioCountryOptionNl)"));
    expect(wikipedia, contains("'nl' => 'nl'"));
    expect(gutenberg, contains("    'nl',"));
  });

  test('Dutch voice, radio and media locale mappings are present', () {
    final ad = File('lib/services/ai_audiodescription_service.dart').readAsStringSync();
    final radio = File('lib/services/radio_service.dart').readAsStringSync();
    final tube = File('lib/services/sonartube_service.dart').readAsStringSync();
    final music = File('lib/services/sonarmusic_service.dart').readAsStringSync();
    expect(ad, contains("if (code.startsWith('nl')) return 'nl-NL'"));
    expect(radio, contains("    'dutch',"));
    expect(tube, contains("_youtubeRegion = 'NL'"));
    expect(music, contains("'nl' => 'NL'"));
  });
}
