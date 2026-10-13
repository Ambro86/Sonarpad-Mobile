import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonarpad_mobile_starter/l10n/app_localizations.dart';
import 'package:sonarpad_mobile_starter/l10n/app_localizations_lookup.dart';
import 'package:sonarpad_mobile_starter/screens/news_screen.dart';
import 'package:sonarpad_mobile_starter/services/news_service.dart';
import 'package:sonarpad_mobile_starter/widgets/universal_accessible_view.dart';

const _sourceName = 'İstanbul haberleri';
const _sourceUrl = 'https://example.test/turkish.rss';
const _success = 'Haber kaynağı Sonarpad topluluğuna başarıyla eklendi.';
const _duplicate = 'Bu haber kaynağı Sonarpad topluluğunda zaten var.';

http.Response _jsonResponse(Object value, [int status = 200]) =>
    http.Response.bytes(
      utf8.encode(jsonEncode(value)),
      status,
      // PHP returns UTF-8 JSON; a missing charset must not corrupt Turkish.
      headers: {'content-type': 'application/json'},
    );

Future<void> _openForm(WidgetTester tester, NewsService service) async {
  await tester.pumpWidget(MaterialApp(
    locale: const Locale('tr'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Builder(builder: (context) => Scaffold(
      body: TextButton(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => AddCommunityNewsSourceScreen(
            language: NewsLanguage.english,
            service: service,
          ),
        )),
        child: const Text('Open form'),
      ),
    )),
  ));
  await tester.tap(find.text('Open form'));
  await tester.pumpAndSettle();
}

UniversalAccessibleList _sharedList(WidgetTester tester) =>
    tester.widget<UniversalAccessibleList>(find.byType(UniversalAccessibleList));

AccessibleListRow _row(WidgetTester tester, String id) => _sharedList(tester)
    .sections.expand((section) => section.rows)
    .singleWhere((row) => row.id == id);

Future<void> _finishStatusTimers(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 3));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // Both mobile targets render the shared model in Flutter during tests.
    // The serialized rows are checked; this does not run native VoiceOver.
    configureAccessibleRendererRuntime(useFlutterOnIos: true);
  });

  tearDown(() {
    configureAccessibleRendererRuntime(useFlutterOnIos: false);
  });

  for (final uiLanguage in <String?>[null, 'en', 'tr_TR']) {
    test('Turkish POST preserves UI locale ${uiLanguage ?? 'default'} and UTF-8',
      () async {
        final requests = <http.Request>[];
        final service = NewsService(client: MockClient((request) async {
          requests.add(request);
          return _jsonResponse({'ok': true, 'message': _success});
        }));

        final message = await service.addCommunityNewsSource(
          language: NewsLanguage.turkish,
          name: _sourceName,
          feedUrl: _sourceUrl,
          uiLanguageCode: uiLanguage,
        );

        expect(requests, hasLength(1));
        expect(requests.single.method, 'POST');
        expect(requests.single.bodyFields, {
          'name': _sourceName,
          'url': _sourceUrl,
          'language': 'turkish',
          'ui_language': uiLanguage ?? 'tr',
        });
        expect(message, _success);
      },
    );
  }

  test('Turkish server failures retain accented characters', () async {
    final service = NewsService(client: MockClient((_) async =>
        _jsonResponse({'ok': false, 'error': _duplicate}, 409)));

    await expectLater(
      service.addCommunityNewsSource(
        language: NewsLanguage.turkish,
        name: _sourceName,
        feedUrl: _sourceUrl,
        uiLanguageCode: 'tr',
      ),
      throwsA(isA<Exception>().having(
        (error) => error.toString(), 'message', 'Exception: $_duplicate',
      )),
    );
  });

  test('Turkish community browsing accepts locale aliases and excludes saved feeds',
    () async {
      SharedPreferences.setMockInitialValues({
        'news_custom_sources_turkish': [jsonEncode({
          'name': 'Already saved',
          'uri': 'https://example.test/saved.rss',
          'isCustom': true,
        })],
      });
      final aliases = ['turkish', 'tr', 'tr_TR', 'tr-TR', 'TR'];
      final service = NewsService(client: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.queryParameters, {'language': 'turkish'});
        return _jsonResponse([
          for (var i = 0; i < aliases.length; i++) {
            'name': 'Türkçe $i',
            'url': 'https://example.test/$i.rss',
            'language': aliases[i],
          },
          {'name': 'English', 'url': 'https://example.test/en.rss', 'language': 'english'},
          {'name': 'Saved', 'url': 'https://example.test/saved.rss', 'language': 'turkish'},
          {
            'name': 'Built in',
            'url': NewsLanguage.turkish.rssSources.first.uri.toString(),
            'language': 'turkish',
          },
          {'name': 'Invalid', 'url': 'not a URL', 'language': 'turkish'},
        ]);
      }));

      final sources = await service.fetchCommunityNewsSources(NewsLanguage.turkish);
      expect(sources.map((source) => source.name), [
        for (var i = 0; i < aliases.length; i++) 'Türkçe $i',
      ]);
      expect(sources.every((source) => source.isCustom), isTrue);
    },
  );

  for (final language in [NewsLanguage.portugueseBrazil, NewsLanguage.chineseSimplified]) {
    test('Community aliases preserve the ${language.communityKey} edition', () async {
      final regionalCode = language.code.replaceAll('-', '_');
      final service = NewsService(client: MockClient((request) async {
        expect(request.url.queryParameters['language'], language.communityKey);
        return _jsonResponse([
          {'name': 'Canonical', 'url': 'https://example.test/canonical.rss', 'language': language.communityKey},
          {'name': 'Regional', 'url': 'https://example.test/regional.rss', 'language': regionalCode},
          {'name': 'Portugal', 'url': 'https://example.test/portugal.rss', 'language': 'portuguese'},
        ]);
      }));

      final sources = await service.fetchCommunityNewsSources(language);
      expect(sources.map((source) => source.name), ['Canonical', 'Regional']);
    });
  }

  testWidgets('Flutter form selects Turkish and freezes duplicate submissions',
    (tester) async {
      final response = Completer<http.Response>();
      final requests = <http.Request>[];
      final service = NewsService(client: MockClient((request) {
        requests.add(request);
        return response.future;
      }));
      final l10n = lookupSupportedAppLocalizations('tr');
      await _openForm(tester, service);

      final picker = find.byType(DropdownButtonFormField<NewsLanguage>);
      expect(tester.widget<DropdownButtonFormField<NewsLanguage>>(picker).initialValue,
        NewsLanguage.english);
      await tester.tap(picker);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text(l10n.radioLanguageTr).last,
        180,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text(l10n.radioLanguageTr).last);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), _sourceName);
      await tester.enterText(find.byType(TextField).at(1), _sourceUrl);
      final staleSelection = tester
          .widget<DropdownButtonFormField<NewsLanguage>>(picker).onChanged!;
      final submitButton = find.byWidgetPredicate((widget) => widget is FilledButton);
      final submit = tester.widget<FilledButton>(submitButton).onPressed!;
      submit();
      submit();
      await tester.pump();
      staleSelection(NewsLanguage.french);
      await tester.pump();

      expect(requests, hasLength(1));
      expect(requests.single.bodyFields['language'], 'turkish');
      expect(requests.single.bodyFields['ui_language'], 'tr');
      expect(tester.widget<DropdownButtonFormField<NewsLanguage>>(picker).initialValue,
        NewsLanguage.turkish);
      expect(tester.widget<DropdownButtonFormField<NewsLanguage>>(picker).onChanged, isNull);
      expect(tester.widget<FilledButton>(submitButton).onPressed, isNull);
      expect(tester.widgetList<TextField>(find.byType(TextField))
          .every((field) => field.enabled == false), isTrue);

      response.complete(_jsonResponse({'ok': true, 'message': _success}));
      await tester.pumpAndSettle();
      expect(find.byType(AddCommunityNewsSourceScreen), findsNothing);
      await _finishStatusTimers(tester);
    },
    variant: TargetPlatformVariant({TargetPlatform.linux}),
  );

  testWidgets('Shared form keeps its chosen language through failure and retry',
    (tester) async {
      final responses = [Completer<http.Response>(), Completer<http.Response>()];
      final requests = <http.Request>[];
      final service = NewsService(client: MockClient((request) {
        requests.add(request);
        return responses[requests.length - 1].future;
      }));
      final l10n = lookupSupportedAppLocalizations('tr');
      await _openForm(tester, service);

      final language = _row(tester, 'language');
      expect(language.kind, 'picker');
      expect(language.value, 'english');
      expect(language.title, l10n.sourceLanguageLabel);
      expect(language.options.map((option) => option.value),
        NewsLanguage.values.map((language) => language.name));
      expect(language.options.singleWhere((option) => option.value == 'turkish').label,
        l10n.radioLanguageTr);

      final events = _sharedList(tester).onEvent!;
      events(const AccessibleListEvent(type: 'textChanged', id: 'name', value: _sourceName));
      events(const AccessibleListEvent(type: 'textChanged', id: 'url', value: _sourceUrl));
      events(const AccessibleListEvent(type: 'picker', id: 'language', value: 'turkish'));
      events(const AccessibleListEvent(type: 'activate', id: 'submit'));
      events(const AccessibleListEvent(type: 'activate', id: 'submit'));
      // Delayed native events must not change an in-flight request or form.
      events(const AccessibleListEvent(type: 'picker', id: 'language', value: 'french'));
      events(const AccessibleListEvent(type: 'textChanged', id: 'name', value: 'Changed'));
      events(const AccessibleListEvent(type: 'textChanged', id: 'url', value: 'https://example.test/changed'));
      await tester.pump();

      expect(requests, hasLength(1));
      expect(requests.single.bodyFields, {
        'name': _sourceName, 'url': _sourceUrl,
        'language': 'turkish', 'ui_language': 'tr',
      });
      for (final id in ['name', 'url', 'language', 'submit']) {
        expect(_row(tester, id).enabled, isFalse, reason: '$id is frozen');
      }
      expect(_row(tester, 'language').value, 'turkish');
      expect(_row(tester, 'name').value, _sourceName);
      expect(_row(tester, 'url').value, _sourceUrl);

      responses.first.complete(_jsonResponse({'ok': false, 'error': _duplicate}, 409));
      await tester.pumpAndSettle();
      expect(find.byType(AddCommunityNewsSourceScreen), findsOneWidget);
      expect(_row(tester, 'language').value, 'turkish');
      expect(_row(tester, 'name').value, _sourceName);
      for (final id in ['name', 'url', 'language', 'submit']) {
        expect(_row(tester, id).enabled, isTrue, reason: '$id is restored');
      }
      _sharedList(tester).onEvent!(const AccessibleListEvent(type: 'activate', id: 'submit'));
      await tester.pump();
      expect(requests, hasLength(2));
      expect(requests.last.bodyFields, requests.first.bodyFields);

      responses.last.complete(_jsonResponse({'ok': true, 'message': _success}));
      await tester.pumpAndSettle();
      expect(find.byType(AddCommunityNewsSourceScreen), findsNothing);
      await _finishStatusTimers(tester);
    },
    variant: TargetPlatformVariant({TargetPlatform.android, TargetPlatform.iOS}),
  );
}
