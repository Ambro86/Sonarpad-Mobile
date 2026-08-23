import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _arb(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

Set<String> _messageKeys(Map<String, dynamic> arb) =>
    arb.keys.where((key) => !key.startsWith('@')).toSet();

void main() {
  test('Ukrainian ARB covers every Sonarpad localization key', () {
    final italian = _arb('lib/l10n/app_it.arb');
    final ukrainian = _arb('lib/l10n/app_uk.arb');
    expect(ukrainian['@@locale'], 'uk');
    expect(_messageKeys(ukrainian), _messageKeys(italian));
  });

  test('Ukrainian is selectable and wired into generated localizations', () {
    final settings = File('lib/screens/settings_screen.dart').readAsStringSync();
    final service = File('lib/services/app_settings_service.dart').readAsStringSync();
    final generated = File('lib/l10n/app_localizations.dart').readAsStringSync();

    expect(settings, contains("AccessibleOption(value: 'uk', label: l10n.radioLanguageUk)"));
    expect(service, contains("'uk'"));
    expect(generated, contains("Locale('uk')"));
    expect(generated, contains("case 'uk':"));
  });

  test('Ukrainian changelog is complete for every release', () {
    final decoded = jsonDecode(
      File('assets/changelog.json').readAsStringSync(),
    ) as List<dynamic>;
    for (final raw in decoded) {
      final release = raw as Map<String, dynamic>;
      final ukrainian = release['uk'] as List<dynamic>?;
      expect(ukrainian, isNotNull, reason: 'Missing uk changelog for ${release['version']}');
      expect(ukrainian, isNotEmpty, reason: 'Empty uk changelog for ${release['version']}');
      final english = release['en'] as List<dynamic>?;
      if (english != null) {
        expect(ukrainian!.length, english.length,
            reason: 'Ukrainian changelog should contain the same shared entries as English for ${release['version']}');
      }
    }

    final latest = decoded
        .cast<Map<String, dynamic>>()
        .firstWhere((release) => release['version'] == '0.4.0');
    final latestUk = (latest['uk'] as List<dynamic>).cast<String>();
    expect(latestUk.any((entry) => entry.contains('українською')), isTrue);
  });

  test('Ukrainian calendar contains every day and every daily quote', () {
    final calendar = jsonDecode(
      File('assets/calendar/uk.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    expect((calendar['saints'] as Map<String, dynamic>).length, 365);
    expect((calendar['quotes'] as List<dynamic>).length, 128);
    expect((calendar['holidays'] as Map<String, dynamic>)['24-8'],
        'День Незалежності України');

    final generated = File(
      'lib/services/calendar/calendar_localization_data.g.dart',
    ).readAsStringSync();
    expect(generated, contains('"uk"'));
  });

  test('Ukrainian news uses Ukrainian RSS sources and Google News Ukraine', () {
    final service = File('lib/services/news_service.dart').readAsStringSync();
    final sources = File(
      'lib/services/news_sources/ukrainian_news_sources.dart',
    ).readAsStringSync();
    expect(service, contains('NewsLanguage.ukrainian'));
    expect(service, contains('ukrainianNewsSources'));
    expect(sources, contains('ceid=UA:uk'));
    expect(sources, contains('Укрінформ'));
    expect(sources, contains('Суспільне Новини'));
  });

  test('Ukraine is the localized default for routes radio and podcasts', () {
    final routes = File('lib/screens/route_screen.dart').readAsStringSync();
    final radio = File('lib/screens/radio_screen.dart').readAsStringSync();
    final podcasts = File('lib/screens/podcast_screen.dart').readAsStringSync();
    expect(routes, contains("'uk' => 'ua'"));
    expect(routes, contains("AccessibleOption(value: 'ua'"));
    expect(radio, contains("'uk' => 'ua'"));
    expect(podcasts, contains("case 'uk':"));
    expect(podcasts, contains("return 'ua';"));
  });

  test('Ukrainian iOS localization is advertised and linked in Xcode', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    final project = File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();
    final ukPlist = File('ios/Runner/uk.lproj/InfoPlist.strings').readAsStringSync();
    expect(plist, contains('<string>uk</string>'));
    expect(project, contains('uk.lproj/InfoPlist.strings'));
    expect(ukPlist, contains('NSCameraUsageDescription'));
    expect(ukPlist, contains('NSCalendarsUsageDescription'));
    expect(ukPlist, contains('NSContactsUsageDescription'));
  });

  test('Italy-only home features remain gated by Italian locale', () {
    final home = File('lib/screens/home_screen.dart').readAsStringSync();
    expect(home, contains("final isItalian = l10n.localeName == 'it';"));
    expect(home, contains('if (_isRaiPlayValid && isItalian)'));
    expect(home, contains('if (_isSecretCodeValid && isItalian)'));
    expect(home, contains('if (showItalianPharmacyFeature)'));
  });
}
