import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonarpad_mobile_starter/l10n/app_localizations.dart';
import 'package:sonarpad_mobile_starter/screens/tv_channel_screen.dart';
import 'package:sonarpad_mobile_starter/services/tv_service.dart';

void main() {
  testWidgets('selezionare un giorno chiude e conferma subito', (tester) async {
    final today = DateTime(2026, 8, 18);
    DateTime? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () async {
              selected = await showTvDaySelectionDialog(
                context,
                selectedDate: today,
                today: today,
                labelForDate: (date) => switch (date.difference(today).inDays) {
                  -1 => 'Ieri',
                  0 => 'Oggi',
                  1 => 'Domani',
                  _ => 'Dopodomani',
                },
              );
            },
            child: const Text('Scegli giorno'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Scegli giorno'));
    await tester.pumpAndSettle();
    expect(find.text('Conferma'), findsNothing);
    expect(find.text('Annulla'), findsNothing);

    await tester.tap(find.text('Domani'));
    await tester.pumpAndSettle();

    expect(selected, today.add(const Duration(days: 1)));
    expect(find.text('Domani'), findsNothing);
  });

  testWidgets('la trama inizia con Indietro e non espone Ignora', (
    tester,
  ) async {
    final semanticsHandle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('it'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () => showTvProgramDetailsDialog(
              context,
              TvProgram(
                title: 'Programma di prova',
                hour: '20:30',
                startTime: 1,
                endTime: 2,
                description: 'Trama completa del programma.',
              ),
            ),
            child: const Text('Apri trama'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Apri trama'));
    await tester.pumpAndSettle();

    expect(find.text('Indietro'), findsOneWidget);
    expect(find.text('Programma di prova'), findsOneWidget);
    expect(find.text('Trama completa del programma.'), findsOneWidget);
    expect(find.bySemanticsLabel('Ignora'), findsNothing);
    expect(
      tester.getTopLeft(find.text('Indietro')).dy,
      lessThan(tester.getTopLeft(find.text('Programma di prova')).dy),
    );
    expect(
      tester
          .getSemantics(
            find.byKey(const ValueKey('tv_program_details_back_semantics')),
          )
          .sortKey,
      const OrdinalSortKey(1),
    );
    expect(
      tester
          .getSemantics(
            find.byKey(const ValueKey('tv_program_details_title_semantics')),
          )
          .sortKey,
      const OrdinalSortKey(2),
    );
    expect(
      tester
          .getSemantics(
            find.byKey(
              const ValueKey('tv_program_details_description_semantics'),
            ),
          )
          .sortKey,
      const OrdinalSortKey(3),
    );

    semanticsHandle.dispose();
  });
}
