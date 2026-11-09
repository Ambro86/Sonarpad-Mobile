import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonarpad_mobile_starter/l10n/app_localizations.dart';
import 'package:sonarpad_mobile_starter/models/document_item.dart';
import 'package:sonarpad_mobile_starter/screens/documents_screen.dart';
import 'package:sonarpad_mobile_starter/screens/news_screen.dart';
import 'package:sonarpad_mobile_starter/services/news_service.dart';
import 'package:sonarpad_mobile_starter/widgets/universal_accessible_view.dart';

Widget app(Widget home) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: home,
);

List<AccessibleListRow> rows(WidgetTester tester) => tester
    .widget<UniversalAccessibleList>(find.byType(UniversalAccessibleList))
    .sections.expand((s) => s.rows).toList();

Future<void> search(WidgetTester tester, String query) async {
  final field = rows(tester).firstWhere((r) => r.id == 'library_search_field');
  await field.onValueChanged!(query);
  unawaited(Future<void>.value(rows(tester)
      .firstWhere((r) => r.id == 'library_search').onActivate!()));
  await tester.pumpAndSettle();
}

void expectCleanResults(WidgetTester tester) {
  expect(find.text('Search results'), findsOneWidget);
  expect(find.byType(TextField), findsNothing);
  expect(find.byType(FloatingActionButton), findsNothing);
  expect(find.byType(SonarpadVisualHomeButton), findsNothing);
  expect(find.byType(SonarpadBackButton), findsOneWidget);
  expect(rows(tester).any((r) => r.id.startsWith('library_')), isFalse);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('document results preserve actions and full-folder reordering', (tester) async {
    final documents = [
      for (final name in ['Alpha', 'Hidden', 'Alpine']) DocumentItem(
        id: name, name: name, path: 'https://example.test/$name',
        extension: 'librivox', addedAt: DateTime(2026),
      ),
    ];
    SharedPreferences.setMockInitialValues({
      'document_library_v1': jsonEncode(documents.map((d) => d.toJson()).toList()),
    });
    await tester.pumpWidget(app(const DocumentsScreen()));
    await tester.pumpAndSettle();
    expect(rows(tester).firstWhere((r) => r.id == 'library_search_field').title,
        'Search documents');
    expect(find.byTooltip('Clear search'), findsNothing);
    await tester.enterText(find.byKey(const ValueKey('library_search_field')), 'prova');
    await tester.pump();
    expect(find.byTooltip('Clear search'), findsOneWidget);
    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Clear search'), findsNothing);
    expect(tester.widget<TextField>(
      find.byKey(const ValueKey('library_search_field'))).controller!.text, '');
    final original = rows(tester).firstWhere((r) => r.id == 'Alpine');
    await search(tester, '  AL  ');
    expectCleanResults(tester);
    expect(rows(tester).map((r) => r.title), ['Alpha', 'Alpine']);
    final result = rows(tester).last;
    expect(result.actions.map((a) => a.id), original.actions.map((a) => a.id));
    expect(result.visualActions.map((a) => a.id), original.visualActions.map((a) => a.id));
    final list = tester.widget<UniversalAccessibleList>(find.byType(UniversalAccessibleList));
    await list.onEvent!(const AccessibleListEvent(
      type: 'customAction', id: 'Alpine', action: 'move_up',
    ));
    await tester.pumpAndSettle();
    final prefs = await SharedPreferences.getInstance();
    final stored = DocumentItem.listFromJsonString(prefs.getString('document_library_v1')!);
    expect(stored.map((d) => d.id), ['Alpha', 'Alpine', 'Hidden']);
    await tester.tap(find.byType(SonarpadBackButton));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Clear search'), findsOneWidget);
    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Clear search'), findsNothing);
    await tester.pumpAndSettle();
    expect(rows(tester).firstWhere((r) => r.id == 'library_search_field').value, '');
    await search(tester, 'missing');
    expectCleanResults(tester);
    expect(rows(tester).single.title, contains('missing'));
  });

  testWidgets('community search matches names and URLs and still adds a source', (tester) async {
    final client = MockClient((request) async => http.Response(jsonEncode([
      {'name': 'Alpha Gazette', 'url': 'https://alpha.test/rss', 'language': 'en'},
      {'name': 'Beta Gazette', 'url': 'https://beta.test/rss', 'language': 'en'},
    ]), 200));
    await http.runWithClient(() async {
      await tester.pumpWidget(app(const NewsScreen(initialLanguage: NewsLanguage.english)));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Community news sources'));
      await tester.pumpAndSettle();
      expect(rows(tester).firstWhere((r) => r.id == 'library_search_field').title,
          'Search Sonarpad community news sources');
      expect(find.byTooltip('Clear search'), findsNothing);
      await tester.enterText(find.byKey(const ValueKey('library_search_field')), 'prova');
      await tester.pump();
      expect(find.byTooltip('Clear search'), findsOneWidget);
      await tester.tap(find.byTooltip('Clear search'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Clear search'), findsNothing);
      expect(tester.widget<TextField>(
        find.byKey(const ValueKey('library_search_field'))).controller!.text, '');
      await search(tester, ' ALPHA ');
      expectCleanResults(tester);
      expect(rows(tester).single.title, 'Alpha Gazette');
      await tester.tap(find.byType(SonarpadBackButton));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Clear search'), findsOneWidget);
    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Clear search'), findsNothing);
      await tester.pumpAndSettle();
      expect(rows(tester).firstWhere((r) => r.id == 'library_search_field').value, '');
      await search(tester, 'beta.test');
      expectCleanResults(tester);
      expect(rows(tester).single.title, 'Beta Gazette');
      final list = tester.widget<UniversalAccessibleList>(find.byType(UniversalAccessibleList));
      await list.onEvent!(const AccessibleListEvent(type: 'activate', id: 'source_0'));
      await tester.pumpAndSettle();
      final saved = await NewsService().getCustomSources(NewsLanguage.english);
      expect(saved.any((s) => s.name == 'Beta Gazette'), isTrue);
      expect(rows(tester).single.title, contains('beta.test'));
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }, () => client);
  });
}
