import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonarpad_mobile_starter/l10n/app_localizations.dart';
import 'package:sonarpad_mobile_starter/services/calendar/calendar_service.dart';
import 'package:sonarpad_mobile_starter/services/news_service.dart';

Map<String, dynamic> arb(String filename) =>
    jsonDecode(File('lib/l10n/$filename').readAsStringSync()) as Map<String, dynamic>;

void main() {
  test('Dutch ARB contains every key and locale resolves', () {
    final nl = arb('app_nl.arb');
    final it = arb('app_it.arb');
    final nlKeys = nl.keys.where((k) => !k.startsWith('@')).toSet();
    final itKeys = it.keys.where((k) => !k.startsWith('@')).toSet();
    expect(nlKeys, itKeys);
    expect(nl['@@locale'], 'nl');
    expect(nl['appLanguage'], 'App-taal');
    expect(nl['calendar'], 'Kalender');
    expect(lookupAppLocalizations(const Locale('nl')).settings, 'Instellingen');
  });

  test('Dutch news and calendar data are registered', () {
    expect(NewsLanguage.dutch.code, 'nl');
    expect(NewsLanguage.dutch.rssSources, isNotEmpty);
    final cal = jsonDecode(File('assets/calendar/nl.json').readAsStringSync())
        as Map<String, dynamic>;
    expect((cal['saints'] as Map).length, 365);
    expect((cal['quotes'] as List).length, 128);
    expect(CalendarService().getHoliday(DateTime(2026, 4, 27), 'nl'), 'Koningsdag');
  });

  test('Dutch labels are available in settings and AI creation', () {
    final settings = File('lib/screens/settings_screen.dart').readAsStringSync();
    final ai = File('lib/screens/create_ai_audiodescription_screen.dart').readAsStringSync();
    expect(settings, contains("AccessibleOption(value: 'nl', label: l10n.dutch)"));
    expect(ai, contains("AccessibleOption(value: 'nl', label: l10n.dutch)"));
    expect(File('ios/Runner/nl.lproj/InfoPlist.strings').existsSync(), isTrue);
  });
}
