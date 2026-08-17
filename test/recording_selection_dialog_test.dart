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
}
