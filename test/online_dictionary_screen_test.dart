import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonarpad_mobile_starter/l10n/app_localizations.dart';
import 'package:sonarpad_mobile_starter/screens/online_dictionary_screen.dart';
import 'package:sonarpad_mobile_starter/services/home_customization_service.dart';
import 'package:sonarpad_mobile_starter/services/online_dictionary_service.dart';
import 'package:sonarpad_mobile_starter/utils/home_item_catalog.dart';
import 'package:sonarpad_mobile_starter/widgets/universal_accessible_view.dart';

const example = DictionaryEntry(
  word: 'casa',
  language: 'it',
  definitions: ['Edificio usato come abitazione.', 'Dimora di una persona.'],
  synonyms: ['abitazione, dimora'],
);

class FakeDictionary extends OnlineDictionaryService {
  Future<DictionaryEntry> Function(String, String)? handler;
  final calls = <String>[];
  bool closed = false;
  @override
  Future<DictionaryEntry> lookup(String word, {String language = 'it'}) async {
    calls.add('$language/$word');
    return handler == null ? example : handler!(word, language);
  }

  @override
  void close() {
    closed = true;
    super.close();
  }
}

Widget app(Widget child, [String locale = 'it']) => MaterialApp(
  locale: Locale(locale),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: child,
);
UniversalAccessibleList list(WidgetTester tester) => tester
    .widgetList<UniversalAccessibleList>(find.byType(UniversalAccessibleList))
    .last;
List<AccessibleListRow> rows(WidgetTester tester) =>
    list(tester).sections.expand((s) => s.rows).toList();
AccessibleListRow row(WidgetTester tester, String id) =>
    rows(tester).firstWhere((r) => r.id == id);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
    'clean form, locale default and independently adjustable sliders',
    (tester) async {
      await tester.pumpWidget(app(const OnlineDictionaryScreen(), 'fr'));
      await tester.pumpAndSettle();
      expect(row(tester, 'language').value, 'fr');
      expect(row(tester, 'language').kind, 'slider');
      expect(row(tester, 'translation').kind, 'slider');
      expect(rows(tester).where((r) => r.kind == 'textField'), hasLength(1));
      await row(tester, 'language').onValueChanged!(2);
      await tester.pumpAndSettle();
      expect(row(tester, 'language').value, 'de');
      expect(row(tester, 'translation').value, 'en');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('online_dictionary_language'), 'de');
    },
  );
  testWidgets('remember both language choices on reopening', (tester) async {
    SharedPreferences.setMockInitialValues({
      'online_dictionary_language': 'es',
      'online_dictionary_translation': '',
    });
    await tester.pumpWidget(app(const OnlineDictionaryScreen()));
    await tester.pumpAndSettle();
    expect(row(tester, 'language').value, 'es');
    expect(row(tester, 'translation').value, '');
  });
  testWidgets(
    'search opens results only; numbering, synonyms and focus handoff',
    (tester) async {
      final fake = FakeDictionary();
      await tester.pumpWidget(
        app(OnlineDictionaryScreen(serviceFactory: () => fake)),
      );
      await tester.pumpAndSettle();
      await row(tester, 'translation').onValueChanged!(0);
      await row(tester, 'word').onValueChanged!(' casa ');
      await row(tester, 'search').onActivate!();
      await tester.pumpAndSettle();
      expect(fake.calls, ['it/casa']);
      expect(
        rows(tester).any((r) => r.kind == 'textField' || r.kind == 'slider'),
        isFalse,
      );
      expect(
        row(tester, 'entry-definition-0').title,
        '1. Edificio usato come abitazione.',
      );
      expect(
        row(tester, 'entry-definition-1').title,
        '2. Dimora di una persona.',
      );
      expect(row(tester, 'entry-synonym-0').title, 'abitazione, dimora');
      expect(list(tester).initialFocusId, 'entry-heading');
    },
  );
  testWidgets(
    'loading is clean, cancellation closes request and ignores late result',
    (tester) async {
      final pending = Completer<DictionaryEntry>();
      final fake = FakeDictionary()..handler = (_, _) => pending.future;
      await tester.pumpWidget(
        app(OnlineDictionaryScreen(serviceFactory: () => fake)),
      );
      await tester.pumpAndSettle();
      await row(tester, 'word').onValueChanged!('casa');
      await row(tester, 'search').onActivate!();
      await tester.pumpAndSettle();
      expect(rows(tester).map((r) => r.id), ['loading', 'cancel']);
      await row(tester, 'cancel').onActivate!();
      await tester.pumpAndSettle();
      expect(fake.closed, isTrue);
      pending.complete(example);
      await tester.pumpAndSettle();
      expect(row(tester, 'word').value, 'casa');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('network error retry and not-found are accessible', (
    tester,
  ) async {
    var attempts = 0;
    await tester.pumpWidget(
      app(
        OnlineDictionaryResultsScreen(
          word: 'casa',
          language: 'it',
          serviceFactory: () => FakeDictionary()
            ..handler = (_, _) async {
              if (attempts++ == 0) {
                throw const DictionaryRequestException('http_503');
              }
              throw const DictionaryRequestException('not_found');
            },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(row(tester, 'error').title, isNot('Parola non trovata.'));
    await row(tester, 'retry').onActivate!();
    await tester.pumpAndSettle();
    expect(row(tester, 'error').title, 'Parola non trovata.');
    expect(attempts, 2);
  });
  testWidgets('translation failure retains useful primary definitions', (
    tester,
  ) async {
    final fake = FakeDictionary()
      ..handler = (_, language) async {
        if (language == 'en') {
          throw const DictionaryRequestException('http_503');
        }
        return example;
      };
    await tester.pumpWidget(
      app(
        OnlineDictionaryResultsScreen(
          word: 'casa',
          language: 'it',
          translation: 'en',
          serviceFactory: () => fake,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(row(tester, 'entry-definition-0').title, contains('Edificio'));
    expect(row(tester, 'translation-error').title, isNotEmpty);
  });
  test(
    'dictionary is available internationally and in reading category',
    () async {
      final ids = availableHomeItemIds(
        isItalian: false,
        isTvCodeValid: false,
        isRaiPlayValid: false,
        isRaiPlaySoundCodeValid: false,
      );
      expect(ids, contains(HomeItemIds.onlineDictionary));
      expect(HomeItemIds.readingOrder, contains(HomeItemIds.onlineDictionary));
      final order = await HomeCustomizationService().loadItemOrder();
      expect(
        order.where((id) => id == HomeItemIds.onlineDictionary),
        hasLength(1),
      );
    },
  );
}
