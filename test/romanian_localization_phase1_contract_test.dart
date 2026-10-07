import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Romanian ARB mirrors the complete message key set', () {
    final it = jsonDecode(File('lib/l10n/app_it.arb').readAsStringSync()) as Map<String, dynamic>;
    final ro = jsonDecode(File('lib/l10n/app_ro.arb').readAsStringSync()) as Map<String, dynamic>;

    final itKeys = it.keys.where((key) => !key.startsWith('@')).toSet();
    final roKeys = ro.keys.where((key) => !key.startsWith('@')).toSet();
    expect(ro['@@locale'], 'ro');
    expect(roKeys, unorderedEquals(itKeys));
    expect(ro['appLanguage'], 'Limba aplicației');
    expect(ro['news'], 'Știri');
    expect(ro['update'], 'Actualizare');
  });

  test('Romanian locale is selectable and generated', () {
    final localizations = File('lib/l10n/app_localizations.dart').readAsStringSync();
    final settings = File('lib/screens/settings_screen.dart').readAsStringSync();
    final preferences = File('lib/services/app_settings_service.dart').readAsStringSync();

    expect(localizations, contains("Locale('ro')"));
    expect(localizations, contains("case 'ro':"));
    expect(settings, contains("label: l10n.languageLabel('ro')"));
    expect(preferences, contains("'ro'"));
  });

  test('Romanian changelog covers every release completely', () {
    final releases = jsonDecode(File('assets/changelog.json').readAsStringSync()) as List<dynamic>;
    for (final raw in releases) {
      final release = raw as Map<String, dynamic>;
      final en = release['en'] as List<dynamic>;
      final ro = release['ro'] as List<dynamic>;
      expect(ro.length, en.length, reason: 'Romanian changelog mismatch in ${release['version']}');
      if (en.isNotEmpty) {
        expect(ro, isNotEmpty);
      }
    }
  });

  test('Romanian calendar has full days, quotes and national holiday', () {
    final calendar = jsonDecode(File('assets/calendar/ro.json').readAsStringSync()) as Map<String, dynamic>;
    final saints = calendar['saints'] as Map<String, dynamic>;
    final holidays = calendar['holidays'] as Map<String, dynamic>;
    final quotes = calendar['quotes'] as List<dynamic>;

    expect(calendar['locale'], 'ro');
    expect(saints.length, 365);
    expect(quotes.length, 128);
    expect(holidays['1-12'], 'Ziua Națională a României');

    final generated = File('lib/services/calendar/calendar_localization_data.g.dart').readAsStringSync();
    expect(generated, contains('\"ro\":'));
    expect(generated, contains('Fericirea nu înseamnă'));
  });

  test('Romanian News uses Google News Romania and Romanian sources', () {
    final service = File('lib/services/news_service.dart').readAsStringSync();
    final sources = File('lib/services/news_sources/romanian_news_sources.dart').readAsStringSync();
    final screen = File('lib/screens/news_screen.dart').readAsStringSync();
    final detail = File('lib/screens/news_detail_screen.dart').readAsStringSync();

    expect(service, contains('romanian'));
    expect(service, contains("'RO'"));
    expect(screen, contains('NewsLanguage.romanian'));
    expect(detail, contains('ro-RO-AlinaNeural'));
    expect(sources, contains('ceid=RO:ro'));
    expect(sources, contains('Digi24'));
    expect(sources, contains('HotNews'));
    expect(sources, contains('AGERPRES'));
    expect(sources, contains('Știrile ProTV'));
  });

  test('iOS declares Romanian localization and permission strings', () {
    final info = File('ios/Runner/Info.plist').readAsStringSync();
    final roInfo = File('ios/Runner/ro.lproj/InfoPlist.strings').readAsStringSync();
    final project = File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();

    expect(info, contains('<string>ro</string>'));
    expect(roInfo, contains('NSCameraUsageDescription'));
    expect(roInfo, contains('NSLocationWhenInUseUsageDescription'));
    expect(project, contains('ro.lproj/InfoPlist.strings'));
  });
}
