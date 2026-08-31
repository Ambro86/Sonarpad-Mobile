import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonarpad_mobile_starter/l10n/app_localizations.dart';
import 'package:sonarpad_mobile_starter/widgets/recording_selection_dialog.dart';

void main() {
  testWidgets('selects and returns multiple recordings', (tester) async {
    RecordingSelectionResult? result;
    final recordings = [
      File(r'C:\recordings\prima.m4a'),
      File(r'C:\recordings\seconda.mp4'),
    ];

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('it'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showRecordingSelectionDialog(context, recordings);
            },
            child: const Text('Apri selezione'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Apri selezione'));
    await tester.pumpAndSettle();

    expect(find.text('Seleziona registrazioni'), findsOneWidget);
    expect(find.text('Condividi (0)'), findsOneWidget);

    await tester.tap(find.byType(Checkbox).at(0));
    await tester.pump();
    await tester.tap(find.byType(Checkbox).at(1));
    await tester.pump();

    expect(find.text('Condividi (2)'), findsOneWidget);
    await tester.tap(find.text('Condividi (2)'));
    await tester.pumpAndSettle();

    expect(result!.action, RecordingSelectionAction.share);
    expect(result!.recordings, hasLength(2));
    expect(result!.recordings.map((file) => file.path), [
      recordings[0].path,
      recordings[1].path,
    ]);
  });

  testWidgets('asks confirmation before returning recordings to delete', (
    tester,
  ) async {
    RecordingSelectionResult? result;
    final recording = File(r'C:\recordings\prima.m4a');

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('it'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showRecordingSelectionDialog(context, [recording]);
            },
            child: const Text('Apri selezione'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Apri selezione'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.tap(find.text('Elimina (1)'));
    await tester.pumpAndSettle();

    expect(
      find.text('Vuoi eliminare definitivamente una registrazione?'),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Elimina'));
    await tester.pumpAndSettle();

    expect(result!.action, RecordingSelectionAction.delete);
    expect(result!.recordings.single.path, recording.path);
  });
  testWidgets('selection screen uses top-left Back and exposes no dismiss barrier', (
    tester,
  ) async {
    final semanticsHandle = tester.ensureSemantics();
    final recording = File(r'C:\recordings\prima.m4a');

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('it'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () => showRecordingSelectionDialog(context, [recording]),
            child: const Text('Apri selezione'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Apri selezione'));
    await tester.pumpAndSettle();

    final backFinder = find.byKey(
      const ValueKey('recording_selection_back_semantics'),
    );
    expect(backFinder, findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
    expect(find.bySemanticsLabel('Ignora'), findsNothing);
    expect(find.widgetWithText(TextButton, 'Indietro'), findsNothing);
    expect(tester.getTopLeft(backFinder).dx, lessThanOrEqualTo(4));
    expect(
      tester.getTopLeft(backFinder).dy,
      lessThan(
        tester.getTopLeft(find.text('Seleziona registrazioni')).dy,
      ),
    );
    semanticsHandle.dispose();
  });

  testWidgets('select all is before recordings and can toggle the full selection', (
    tester,
  ) async {
    RecordingSelectionResult? result;
    final recordings = [
      File(r'C:\recordings\prima.m4a'),
      File(r'C:\recordings\seconda.mp4'),
      File(r'C:\recordings\terza.m4a'),
    ];

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('it'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showRecordingSelectionDialog(context, recordings);
            },
            child: const Text('Apri selezione'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Apri selezione'));
    await tester.pumpAndSettle();

    final selectAll = find.byKey(
      const ValueKey('recording_selection_select_all'),
    );
    expect(selectAll, findsOneWidget);
    expect(find.text('Seleziona tutto'), findsOneWidget);
    expect(
      tester.getTopLeft(selectAll).dy,
      lessThan(
        tester.getTopLeft(
          find.byKey(
            ValueKey('recording_selection_${recordings.first.path}'),
          ),
        ).dy,
      ),
    );

    await tester.tap(selectAll);
    await tester.pump();
    expect(find.text('Deseleziona tutto'), findsOneWidget);
    expect(find.text('Condividi (3)'), findsOneWidget);
    for (final checkbox in tester.widgetList<Checkbox>(find.byType(Checkbox))) {
      expect(checkbox.value, isTrue);
    }

    await tester.tap(selectAll);
    await tester.pump();
    expect(find.text('Seleziona tutto'), findsOneWidget);
    expect(find.text('Condividi (0)'), findsOneWidget);
    for (final checkbox in tester.widgetList<Checkbox>(find.byType(Checkbox))) {
      expect(checkbox.value, isFalse);
    }

    await tester.tap(selectAll);
    await tester.pump();
    await tester.tap(find.text('Condividi (3)'));
    await tester.pumpAndSettle();

    expect(result!.action, RecordingSelectionAction.share);
    expect(
      result!.recordings.map((file) => file.path),
      recordings.map((file) => file.path),
    );
  });

  testWidgets('rename appears only for exactly one selected recording', (
    tester,
  ) async {
    RecordingSelectionResult? result;
    final recordings = [
      File(r'C:\recordings\prima.m4a'),
      File(r'C:\recordings\seconda.mp4'),
    ];

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('it'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showRecordingSelectionDialog(context, recordings);
            },
            child: const Text('Apri selezione'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Apri selezione'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('recording_selection_rename')), findsNothing);

    await tester.tap(find.byType(Checkbox).at(0));
    await tester.pump();
    final rename = find.byKey(const ValueKey('recording_selection_rename'));
    expect(rename, findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Rinomina'), findsOneWidget);

    await tester.tap(find.byType(Checkbox).at(1));
    await tester.pump();
    expect(rename, findsNothing);

    await tester.tap(find.byType(Checkbox).at(1));
    await tester.pump();
    expect(rename, findsOneWidget);
    await tester.tap(rename);
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.action, RecordingSelectionAction.rename);
    expect(result!.recordings, hasLength(1));
    expect(result!.recordings.single.path, recordings.first.path);
  });

}
