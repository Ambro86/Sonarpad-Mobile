import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sonarpad_mobile_starter/l10n/app_localizations_lookup.dart';
import 'package:sonarpad_mobile_starter/l10n/localized_dynamic_labels.dart';
import 'package:sonarpad_mobile_starter/services/html_reader_service.dart';
import 'package:sonarpad_mobile_starter/services/route_service.dart';
import 'package:sonarpad_mobile_starter/services/sonartube_service.dart';
import 'package:sonarpad_mobile_starter/utils/list_timestamp_formatter.dart';

void main() {
  test('service locale lookup accepts regional names and safe fallbacks', () {
    for (final locale in ['tr', 'tr_TR', 'tr-TR', ' TR-tr ']) {
      final strings = lookupSupportedAppLocalizations(locale);
      expect(strings.settings, 'Ayarlar');
      expect(strings.languageLabel('ro-RO'), 'Rumence');
      expect(strings.radioCountryLabel('ro'), 'Romanya');
      expect(strings.listTimestampToday, 'bugün');
      expect(strings.listTimestampYesterday, 'dün');
    }
    expect(lookupSupportedAppLocalizations('pt-br').localeName, 'pt_BR');
    expect(lookupSupportedAppLocalizations('zh-Hans-CN').localeName, 'zh_CN');
    expect(lookupSupportedAppLocalizations('unsupported').localeName, 'en');
    expect(lookupSupportedAppLocalizations('', fallbackLanguage: 'it').localeName,
        'it');
    expect(lookupSupportedAppLocalizations('unsupported',
        fallbackLanguage: 'also-unsupported').localeName, 'en');
  });

  test('empty route addresses report Turkish without making a request', () async {
    final service = RouteService(client: MockClient((request) async {
      fail('An empty address must not reach the network.');
    }));
    for (final locale in ['tr', 'tr_TR', 'tr-TR']) {
      await expectLater(
        service.geocode(query: ' ', language: locale, countryCode: 'tr'),
        throwsA(isA<Exception>().having((error) => error.toString(), 'message',
            contains('Geçersiz adres'))),
      );
    }
  });

  test('route network errors retain status and Turkish request parameters',
      () async {
    late Uri requested;
    final service = RouteService(client: MockClient((request) async {
      requested = request.url;
      return http.Response('', 503);
    }));
    await expectLater(
      service.geocode(query: 'Ankara', language: 'tr', countryCode: 'tr'),
      throwsA(isA<Exception>().having((error) => error.toString(), 'message',
          contains('Adres aramasında ağ hatası: HTTP 503'))),
    );
    expect(requested.queryParameters['language'], 'tr');
    expect(requested.queryParameters['boundary.country'], 'TUR');
  });

  test('SonarTube uses Turkish language and Turkey for regional app locales',
      () async {
    final requests = <Uri>[];
    final service = SonarTubeService(
      enableDirectNavigation: false,
      client: MockClient((request) async {
        requests.add(request.url);
        return http.Response(jsonEncode({'ok': true, 'items': [], 'page': 1}), 200);
      }),
    );
    for (final locale in ['tr', 'tr_TR', 'tr-TR']) {
      service.setLocaleName(locale);
      final page = await service.search('İstanbul');
      expect(page.items, isEmpty);
    }
    expect(requests, hasLength(3));
    for (final uri in requests) {
      expect(uri.queryParameters['hl'], 'tr');
      expect(uri.queryParameters['gl'], 'TR');
      expect(uri.queryParameters['q'], 'İstanbul');
    }
  });

  test('imported article fallbacks and author prefix use Turkish ARB strings', () {
    for (final locale in ['tr', 'tr_TR', 'tr-TR']) {
      expect(HtmlReaderService.authorPrefix(locale), 'Yazar:');
      expect(HtmlReaderService.pickTitle(html_parser.parse('<html></html>'), locale),
          'Başlık bulunamadı');
    }
    expect(HtmlReaderService.pickTitle(
        html_parser.parse('<h1>Kaynağın gerçek başlığı</h1>'), 'tr'),
        'Kaynağın gerçek başlığı');
  });

  test('Turkish list timestamps use day-month-year and a 24-hour clock', () async {
    await initializeDateFormatting('tr');
    final timestamp = formatListTimestamp(DateTime(2000, 1, 2, 13, 5), 'tr');
    expect(timestamp, '02.01.2000 13:05');
    expect(formatListTimestamp(null, 'tr'), isNull);
    expect(titleWithListTimestamp('Başlık', null, 'tr'), 'Başlık');
  });
}
