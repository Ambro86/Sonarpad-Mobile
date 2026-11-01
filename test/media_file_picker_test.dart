import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonarpad_mobile_starter/l10n/app_localizations.dart';
import 'package:sonarpad_mobile_starter/services/cloud_file_picker_service.dart';
import 'package:sonarpad_mobile_starter/services/media_file_picker_service.dart';
import 'package:sonarpad_mobile_starter/screens/translator_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    CloudFilePicker.debugUseNativePicker = true;
  });
  tearDown(() => CloudFilePicker.debugUseNativePicker = null);

  testWidgets(
    'browse preserves multiple selection, filters and original names',
    (tester) async {
      Map<dynamic, dynamic>? arguments;
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        const MethodChannel('sonarpad/cloud_file_picker_progress'),
        (_) async => null,
      );
      messenger.setMockMethodCallHandler(
        const MethodChannel('sonarpad/cloud_file_picker'),
        (call) async {
          arguments = call.arguments as Map;
          return [
            {'name': 'Prima.mp3', 'path': '/cache/first.mp3', 'size': 12},
            {'name': 'Seconda.wav', 'path': '/cache/second.wav', 'size': 24},
          ];
        },
      );
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('it'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Builder(
            builder: (ctx) {
              context = ctx;
              return const Scaffold();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      FilePickerResult? result;
      final selection = MediaFilePicker.pickFiles(
        context: context,
        allowedExtensions: ['mp3', 'wav'],
        allowMultiple: true,
      ).then((value) => result = value);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sfoglia…'));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
      var complete = false;
      final pending = selection.whenComplete(() => complete = true);
      final timer = Stopwatch()..start();
      while (!complete) {
        if (timer.elapsed > const Duration(seconds: 5)) throw StateError('Picker timeout');
        await tester.pump(const Duration(milliseconds: 100));
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      await pending;
    });
      expect(arguments!['allowMultiple'], true);
      expect(arguments!['allowedExtensions'], ['mp3', 'wav']);
      expect(result!.files.map((f) => f.name), ['Prima.mp3', 'Seconda.wav']);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'documents choice opens the existing picker with the media filter',
    (tester) async {
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('it'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Builder(
            builder: (ctx) {
              context = ctx;
              return const Scaffold();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      final selection = MediaFilePicker.pickFiles(
        context: context,
        allowedExtensions: ['mp4'],
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Documenti · Sonarpad'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TranslationDocumentPickerScreen>(
              find.byType(TranslationDocumentPickerScreen),
            )
            .allowedExtensions,
        ['mp4'],
      );
      Navigator.of(
        tester.element(find.byType(TranslationDocumentPickerScreen)),
      ).pop();
      await tester.pumpAndSettle();
      expect(await selection, isNull);
    },
  );
}
