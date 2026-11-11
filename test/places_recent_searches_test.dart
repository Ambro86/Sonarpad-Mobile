import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonarpad_mobile_starter/l10n/app_localizations.dart';
import 'package:sonarpad_mobile_starter/screens/italiaonline_screen.dart';
import 'package:sonarpad_mobile_starter/services/recent_searches_service.dart';
import 'package:sonarpad_mobile_starter/widgets/universal_accessible_view.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('place history preserves all search modes and supports removal', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('it'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ItaliaOnlineScreen(),
      ),
    );
    await tester.pumpAndSettle();

    final history = RecentSearchesService();
    final queries = [
      ('kind_pagine_gialle', 'Farmacia', 'Milano'),
      ('kind_pagine_bianche', 'Mario Rossi', 'Roma'),
      ('kind_phone', '+390212345678', ''),
    ];
    UniversalAccessibleList list() => tester.widget<UniversalAccessibleList>(
      find.byType(UniversalAccessibleList),
    );
    AccessibleListRow row(String id) => list().sections
        .expand((section) => section.rows)
        .firstWhere((row) => row.id == id);

    for (final query in queries) {
      row(query.$1).onActivate!();
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, query.$2);
      if (query.$3.isNotEmpty) {
        await tester.enterText(find.byType(TextField).last, query.$3);
      }
      await list().onEvent!(
        const AccessibleListEvent(type: 'activate', id: 'search'),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ItaliaOnlineResultsScreen), findsOneWidget);
      final results = tester.widget<ItaliaOnlineResultsScreen>(
        find.byType(ItaliaOnlineResultsScreen),
      );
      final stored = jsonDecode(
        (await history.getRecentSearches('places')).first,
      );
      expect(stored['what'], results.query.what);
      expect(stored['where'], query.$3);
      expect(stored['reverse'], query.$1 == 'kind_phone');
      expect(stored['country'], 'it');
      Navigator.of(
        tester.element(find.byType(ItaliaOnlineResultsScreen)),
      ).pop();
      await tester.pumpAndSettle();
    }
    expect(await history.getRecentSearches('places'), hasLength(3));

    row('recent').onActivate!();
    await tester.pumpAndSettle();
    expect(find.text('Ricerche recenti'), findsOneWidget);
    expect(row('search_0').title, contains('+390212345678'));
    expect(row('search_1').title, contains('Mario Rossi'));
    expect(row('search_2').title, contains('Milano'));
    expect(row('search_0').visualActionId, 'delete');
    expect(row('search_0').actions.single.id, 'delete');
    expect(
      find.ancestor(
        of: find.byIcon(Icons.delete_outline),
        matching: find.byType(ExcludeSemantics),
      ),
      findsWidgets,
    );

    await list().onEvent!(
      const AccessibleListEvent(type: 'activate', id: 'search_1'),
    );
    await tester.pumpAndSettle();
    final reopened = tester.widget<ItaliaOnlineResultsScreen>(
      find.byType(ItaliaOnlineResultsScreen),
    );
    expect(reopened.query.what, 'Mario Rossi');
    expect(reopened.query.where, 'Roma');
    expect(reopened.query.kind.name, 'pagineBianche');
    expect(reopened.query.reverse, isFalse);
    expect(await history.getRecentSearches('places'), hasLength(3));
    Navigator.of(tester.element(find.byType(ItaliaOnlineResultsScreen))).pop();
    await tester.pumpAndSettle();
    row('recent').onActivate!();
    await tester.pumpAndSettle();

    await list().onEvent!(
      const AccessibleListEvent(
        type: 'customAction',
        id: 'search_0',
        action: 'delete',
      ),
    );
    await tester.pumpAndSettle();
    expect(await history.getRecentSearches('places'), hasLength(2));
    await tester.tap(find.byIcon(Icons.delete_sweep));
    await tester.pumpAndSettle();
    final l10n = AppLocalizations.of(tester.element(find.byType(AlertDialog)));
    await tester.tap(find.widgetWithText(TextButton, l10n.clear));
    await tester.pumpAndSettle();
    expect(await history.getRecentSearches('places'), isEmpty);
    expect(find.text(l10n.noRecentSearches), findsOneWidget);
  });
}
