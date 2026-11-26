import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonarpad_mobile_starter/l10n/app_localizations.dart';
import 'package:sonarpad_mobile_starter/services/sonartube_media_export_service.dart';
import 'package:sonarpad_mobile_starter/services/sonartube_service.dart';
import 'package:sonarpad_mobile_starter/widgets/sonartube_save_media_dialog.dart';

class _Export extends SonarTubeMediaExportService {
  final completed = Completer<String>();
  final cleaned = <String>[];
  late SonarTubeMediaExportController controller;

  @override
  Future<String> exportMp3({
    required SonarTubeService service,
    required SonarTubeItem item,
    SonarTubeMediaExportController? controller,
    void Function(double fraction)? onProgress,
  }) {
    this.controller = controller!;
    onProgress?.call(0.99);
    return completed.future;
  }

  @override
  Future<void> cleanup(String filePath) async => cleaned.add(filePath);
}

void main() {
  for (final cancelDuringExport in [true, false]) {
    testWidgets(
      'Cancel ${cancelDuringExport ? "at 99%" : "after export"} discards the temporary file',
      (tester) async {
        final exporter = _Export();
        late AppLocalizations labels;
        late Future<void> operation;
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('it'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) {
                labels = AppLocalizations.of(context);
                return TextButton(
                  onPressed: () {
                    operation = saveSonarTubeMediaWithDestination(
                      context,
                      service: SonarTubeService(),
                      item: const SonarTubeItem(
                        kind: SonarTubeItemKind.video,
                        id: 'id',
                        title: 'song',
                        url: '',
                      ),
                      exportService: exporter,
                    );
                  },
                  child: const Text('Start'),
                );
              },
            ),
          ),
        );
        await tester.tap(find.text('Start'));
        await tester.pumpAndSettle();
        await tester.tap(find.text(labels.sonarTubeSaveAsMp3));
        await tester.pumpAndSettle();
        if (cancelDuringExport) {
          await tester.tap(find.text(labels.cancel));
          await tester.pumpAndSettle();
          expect(exporter.controller.isCancelled, isTrue);
          expect(find.byType(AlertDialog), findsNothing);
        }
        exporter.completed.complete('song.mp3');
        await tester.pumpAndSettle();
        if (!cancelDuringExport) {
          expect(find.text(labels.mediaProcessingCompleted), findsOneWidget);
          await tester.tap(find.text(labels.cancel));
          await tester.pumpAndSettle();
        }
        await operation;
        expect(exporter.cleaned, ['song.mp3']);
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.text('Start'), findsOneWidget);
      },
    );
  }
}
