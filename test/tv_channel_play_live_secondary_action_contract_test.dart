import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sonarpad_mobile_starter/l10n/app_localizations.dart';

void main() {
  test('every TV channel surface exposes direct live playback', () {
    final tv = File('lib/screens/tv_screen.dart').readAsStringSync();
    final favorites =
        File('lib/screens/favorite_tvs_screen.dart').readAsStringSync();

    expect(tv, contains("id: 'play_live'"));
    expect(tv, contains("event.action == 'play_live'"));
    expect(tv, contains('onPlayLive: () => widget.onPlayLive(channel)'));
    expect(tv, contains("icon: 'play'"));
    expect(tv, contains('icon: const Icon(Icons.play_arrow)'));

    expect(favorites, contains("id: 'play_live'"));
    expect(favorites, contains("event.action == 'play_live'"));
    expect(favorites, contains('widget.onPlayLive(channel)'));
    expect(favorites, contains("icon: 'play'"));
    expect(favorites, contains('icon: const Icon(Icons.play_arrow)'));
  });

  test('direct TV playback resolves the stream and opens the player', () {
    final tv = File('lib/screens/tv_screen.dart').readAsStringSync();

    expect(tv, contains('Future<void> _playLiveChannel(TvChannel channel)'));
    expect(tv, contains('_service.resolveStreamUrl(channel)'));
    expect(tv, contains("RouteSettings(name: '/tv/channel/player')"));
    expect(tv, contains('RadioPlayerScreen('));
    expect(tv, contains('tvChannel: channel'));
  });

  test('live-play visual controls stay hidden from screen readers', () {
    final shared =
        File('lib/widgets/universal_accessible_view.dart').readAsStringSync();
    final native =
        File('ios/Runner/SonarpadNativeAccessibleView.swift').readAsStringSync();

    expect(shared, contains("'play' => Icons.play_arrow"));
    expect(shared, contains('return ExcludeSemantics('));
    expect(native, contains('case "play": return "play.fill"'));
    expect(native, contains('stack.accessibilityElementsHidden = true'));
    expect(native, contains('button.isAccessibilityElement = false'));
  });

  test('ARB discovery accepts Windows and POSIX paths', () {
    for (final path in <String>[
      'lib/l10n/app_tr.arb',
      r'lib\l10n\app_tr.arb',
      r'lib/l10n\app_tr.arb',
      r'C:\project\lib\l10n\app_pt_BR.arb',
      '/Users/runner/project/lib/l10n/app_zh_CN.arb',
    ]) {
      expect(_isAppArbPath(path), isTrue, reason: path);
    }
    for (final path in <String>[
      'lib/l10n/app_localizations.dart',
      'lib/l10n/app_localizations_lookup.dart',
      r'lib\l10n\app_localizations_lookup.dart',
      'lib/l10n/app_tr.arb.bak',
      'lib/l10n/untranslated_messages.json',
      'lib/l10n/other.arb',
    ]) {
      expect(_isAppArbPath(path), isFalse, reason: path);
    }
  });

  test('every locale contains the direct TV playback label', () {
    final arbFiles = Directory('lib/l10n')
        .listSync()
        .whereType<File>()
        .where((file) => _isAppArbPath(file.path))
        .toList();

    // An empty discovery must fail, rather than silently passing on Windows.
    expect(arbFiles, isNotEmpty, reason: 'No app ARB files found in lib/l10n');

    final labelsByLocale = <String, String>{};
    for (final file in arbFiles) {
      final arb = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final localeValue = arb['@@locale'];
      expect(localeValue, isA<String>(),
          reason: 'Missing locale in ${file.path}');
      final localeName = (localeValue as String).replaceAll('-', '_');
      expect(localeName, isNotEmpty, reason: 'Empty locale in ${file.path}');
      expect(labelsByLocale, isNot(contains(localeName)),
          reason: 'Duplicate ARB locale $localeName in ${file.path}');

      final label = arb['tvPlayLive'];
      expect(label, isA<String>(),
          reason: 'Missing tvPlayLive in ${file.path}');
      final text = label as String;
      expect(text.trim(), isNotEmpty,
          reason: 'Empty tvPlayLive in ${file.path}');
      labelsByLocale[localeName] = text;
    }

    // Exercise generated translations, not every file whose name happens to
    // start with app_localizations. The lookup helper is not a translation.
    final supportedLocales = AppLocalizations.supportedLocales;
    expect(supportedLocales, isNotEmpty,
        reason: 'No generated app locales found');
    expect(
      supportedLocales.map((locale) => locale.toString()).toSet(),
      equals(labelsByLocale.keys.toSet()),
      reason: 'Generated locales must match the app ARB catalog',
    );
    for (final locale in supportedLocales) {
      final localized = lookupAppLocalizations(locale);
      expect(
        localized.tvPlayLive,
        labelsByLocale[locale.toString()],
        reason: 'Generated tvPlayLive differs from the ARB for $locale',
      );
    }
  });
}

bool _isAppArbPath(String path) {
  final name = path.replaceAll('\\', '/').split('/').last;
  return name.startsWith('app_') && name.endsWith('.arb');
}
