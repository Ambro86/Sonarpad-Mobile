import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonarpad_mobile_starter/l10n/app_localizations.dart';
import 'package:sonarpad_mobile_starter/l10n/travel_strings.dart';
import 'package:sonarpad_mobile_starter/l10n/travel_translations.dart';
import 'package:sonarpad_mobile_starter/screens/travel_screen.dart';
import 'package:sonarpad_mobile_starter/services/travel_service.dart';
import 'package:sonarpad_mobile_starter/services/home_customization_service.dart';
import 'package:sonarpad_mobile_starter/utils/home_item_catalog.dart';
import 'travel_screen_test.dart' show rows;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('device region selects supported currency and phone prefix', () {
    for (final sample in [
      ['en', 'US', 'US', 'USD', '+1'],
      ['en', 'GB', 'GB', 'GBP', '+44'],
      ['fr', 'CA', 'CA', 'CAD', '+1'],
      ['fr', 'FR', 'FR', 'EUR', '+33'],
      ['es', 'MX', 'MX', 'MXN', '+52'],
      ['de', 'CH', 'CH', 'CHF', '+41'],
      ['pl', 'PL', 'PL', 'PLN', '+48'],
      ['it', 'CN', 'CN', 'EUR', '+86'],
      ['pt_BR', 'ZZ', 'BR', 'BRL', '+55'],
      ['en_US', '', 'US', 'USD', '+1'],
      ['en', '', 'GB', 'GBP', '+44'],
    ]) {
      final strings = TravelStrings(sample[0], deviceCountry: sample[1]);
      expect(strings.defaultCountry, sample[2], reason: sample.toString());
      expect(strings.defaultCurrency, sample[3], reason: sample.toString());
      expect(strings.defaultPhonePrefix, sample[4], reason: sample.toString());
    }
  });
  testWidgets('device defaults apply on first use but saved choices win', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.binding.platformDispatcher.localeTestValue = const Locale(
      'es',
      'MX',
    );
    addTearDown(tester.binding.platformDispatcher.clearLocaleTestValue);
    Future<void> mount() async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('fr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const TravelSearchScreen(),
        ),
      );
      await tester.pumpAndSettle();
    }

    await mount();
    expect(rows(tester).firstWhere((r) => r.id == 'country').value, 'MX');
    expect(rows(tester).firstWhere((r) => r.id == 'currency').value, 'MXN');
    await tester.pumpWidget(const SizedBox());
    await RecentTravelService().saveLast(
      TravelQuery(country: 'IT', currency: 'GBP'),
    );
    await mount();
    expect(rows(tester).firstWhere((r) => r.id == 'country').value, 'IT');
    expect(rows(tester).firstWhere((r) => r.id == 'currency').value, 'GBP');
    await tester.pumpWidget(const SizedBox());
  });
  test('all travel catalogues are complete and preserve placeholders', () {
    final keys = TravelStrings.keys.toSet();
    Set<String> placeholders(String value) =>
        RegExp(r'\{[a-zA-Z]+\}').allMatches(value).map((m) => m[0]!).toSet();
    for (final locale in AppLocalizations.supportedLocales) {
      final tag = locale.toString();
      final t = TravelStrings(tag);
      final catalog = tag == 'pt_BR' ? 'pt_BR' : locale.languageCode;
      if (!['it', 'en'].contains(catalog)) {
        expect(travelTranslations[catalog]!.keys.toSet(), keys, reason: tag);
      }
      for (final key in keys) {
        expect(t.t(key).trim(), isNotEmpty, reason: '$tag/$key');
        expect(t.t(key), isNot(key), reason: '$tag/$key');
        expect(
          placeholders(t.t(key)),
          placeholders(TravelStrings('en').t(key)),
          reason: '$tag/$key',
        );
      }
    }
    expect(TravelStrings('pt-BR').t('train'), 'Trem');
    expect(TravelStrings('pt-BR').defaultCountry, 'BR');
    expect(TravelStrings('zh-CN').t('title'), '旅行搜索');
  });
  test('Slavic duration plurals remain natural', () {
    expect(TravelStrings('pl').durationValue(5, hours: true), '5 godzin');
    expect(TravelStrings('pl').durationValue(22, hours: false), '22 minuty');
    expect(TravelStrings('cs').durationValue(5, hours: false), '5 minut');
    expect(TravelStrings('uk').durationValue(21, hours: true), '21 година');
    expect(TravelStrings('uk').durationValue(12, hours: false), '12 хвилин');
  });
  test(
    'travel is available internationally without exposing Italy-only services',
    () {
      final ids = availableHomeItemIds(
        isItalian: false,
        isTvCodeValid: false,
        isRaiPlayValid: false,
        isRaiPlaySoundCodeValid: false,
      );
      expect(ids, contains(HomeItemIds.travel));
      expect(ids, isNot(contains(HomeItemIds.tv)));
      expect(ids, isNot(contains(HomeItemIds.treccani)));
    },
  );
  for (final locale in AppLocalizations.supportedLocales) {
    testWidgets('travel welcome is accessible in $locale', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const TravelScreen(),
        ),
      );
      await tester.pumpAndSettle();
      final visible = rows(tester);
      expect(visible.any((r) => r.id == 'unavailable-language'), isFalse);
      expect(
        visible.any(
          (r) => r.title == TravelStrings(locale.toString()).t('welcome1'),
        ),
        isTrue,
      );
      await tester.pumpWidget(const SizedBox());
    });
    test('session preserves $locale and currency', () async {
      final service = TravelService(
        clientToken: 'test',
        logger: (_) async {},
        client: MockClient((request) async {
          final body = jsonDecode(request.body) as Map;
          expect(body['locale'], locale.toString().replaceAll('_', '-'));
          expect(body['currency'], 'GBP');
          return http.Response(
            jsonEncode({
              'token': 'local-test-session',
              'locale': locale.languageCode,
              'currency': 'GBP',
            }),
            201,
          );
        }),
      );
      await service.start(locale.toString(), 'GBP');
      await service.close();
    });
  }
}
