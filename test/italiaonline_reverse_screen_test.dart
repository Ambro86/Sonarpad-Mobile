import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonarpad_mobile_starter/widgets/universal_accessible_view.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonarpad_mobile_starter/l10n/app_localizations.dart';
import 'package:sonarpad_mobile_starter/screens/italiaonline_screen.dart';

void main() {
  testWidgets('saved place country is restored separately from routes', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'places_search_country': 'fr'});
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('it'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ItaliaOnlineScreen(),
      ),
    );
    await tester.pumpAndSettle();
    final list = tester.widget<UniversalAccessibleList>(
      find.byType(UniversalAccessibleList),
    );
    expect(
      list.sections
          .expand((s) => s.rows)
          .firstWhere((r) => r.id == 'country')
          .value,
      'fr',
    );
    await tester.tap(find.text('Ricerca nominativi'));
    await tester.pumpAndSettle();
    final names = tester.widget<UniversalAccessibleList>(
      find.byType(UniversalAccessibleList),
    );
    expect(
      names.sections.expand((s) => s.rows).any((r) => r.id == 'country'),
      isFalse,
    );
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
    'international interface offers places and phone search with a country',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ItaliaOnlineScreen(),
        ),
      );
      expect(find.text('Find places and businesses'), findsWidgets);
      expect(find.text('Enter a place or business'), findsOneWidget);
      expect(
        tester
            .widget<UniversalAccessibleList>(
              find.byType(UniversalAccessibleList),
            )
            .sections
            .expand((s) => s.rows)
            .firstWhere((r) => r.id == 'country')
            .value,
        'us',
      );
      expect(find.text('Ricerca nominativi'), findsNothing);
      expect(find.text('Find a phone number'), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(2));
      expect(find.byType(SegmentedButton<int>), findsNothing);
      await tester.tap(find.text('Find a phone number'));
      await tester.pumpAndSettle();
      expect(find.text('Enter the phone number'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      final rows = tester
          .widget<UniversalAccessibleList>(find.byType(UniversalAccessibleList))
          .sections
          .expand((s) => s.rows);
      expect(rows.any((r) => r.id == 'country'), isTrue);
      expect(rows.any((r) => r.id == 'kind_pagine_bianche'), isFalse);
    },
  );

  testWidgets(
    'phone mode exposes phone entry and hides the irrelevant location',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('it'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ItaliaOnlineScreen(),
        ),
      );
      expect(find.text('Località, indirizzo (opzionale)'), findsOneWidget);
      await tester.tap(find.text('Cerca un numero di telefono'));
      await tester.pumpAndSettle();
      expect(find.text('Inserisci il numero di telefono'), findsOneWidget);
      expect(find.text('Località, indirizzo (opzionale)'), findsNothing);
      expect(find.byType(SwitchListTile), findsNothing);
      expect(find.byType(Checkbox), findsNothing);
      final field = tester.widget<TextField>(find.byType(TextField).first);
      expect(field.keyboardType, TextInputType.phone);
      await tester.enterText(find.byType(TextField).first, 'abc');
      await tester.tap(find.text('Cerca'));
      await tester.pumpAndSettle();
      expect(find.byType(ItaliaOnlineResultsScreen), findsNothing);
      expect(
        find.text(
          'Inserisci un numero di telefono valido, completo di prefisso.',
        ),
        findsOneWidget,
      );
    },
  );
}
