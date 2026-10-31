import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonarpad_mobile_starter/l10n/app_localizations.dart';
import 'package:sonarpad_mobile_starter/models/document_item.dart';
import 'package:sonarpad_mobile_starter/screens/document_reader_screen.dart';
import 'package:sonarpad_mobile_starter/services/document_library_service.dart';
import 'package:sonarpad_mobile_starter/services/pdf_password_service.dart';
import 'package:sonarpad_mobile_starter/widgets/document_password_dialog.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class _Paths extends PathProviderPlatform {
  _Paths(this.path);
  final String path;
  @override
  Future<String> getApplicationDocumentsPath() async => path;
  @override
  Future<String> getApplicationSupportPath() async => path;
  @override
  Future<String> getTemporaryPath() async => path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temporary;
  late PathProviderPlatform previousPaths;
  late File source;
  late List<int> originalBytes;
  final privatePath = Platform.environment['SONARPAD_TEST_PDF_PATH'];
  final password =
      Platform.environment['SONARPAD_TEST_PDF_PASSWORD'] ??
      'widget-test-password';

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    temporary = await Directory.systemTemp.createTemp('sonarpad-reader-pdf-');
    previousPaths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _Paths(temporary.path);
    source = File('${temporary.path}/source.pdf');
    if (privatePath != null) {
      await File(privatePath).copy(source.path);
    } else {
      final pdf = PdfDocument();
      pdf.pages.add().graphics.drawString(
        'Accessible protected PDF test',
        PdfStandardFont(PdfFontFamily.helvetica, 14),
      );
      pdf.security.userPassword = password;
      await source.writeAsBytes(await pdf.save());
      pdf.dispose();
    }
    originalBytes = await source.readAsBytes();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final name in [
      'flutter_tts',
      'sonarpad/tts_events',
      'com.ryanheise.audio_session',
      'com.ryanheise.just_audio.methods',
      'dev.fluttercommunity.plus/wakelock',
    ]) {
      messenger.setMockMethodCallHandler(
        MethodChannel(name),
        (_) async => null,
      );
    }
  });

  tearDown(() async {
    PathProviderPlatform.instance = previousPaths;
    await temporary.delete(recursive: true);
  });

  Future<void> waitFor(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 60; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump(const Duration(milliseconds: 100));
      if (finder.evaluate().isNotEmpty) return;
    }
    expect(finder, findsWidgets);
  }

  Future<void> mount(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('it'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              child: const Text('Open test PDF'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => DocumentReaderScreen(
                    document: DocumentItem(
                      id: 'pdf-test',
                      name: 'source.pdf',
                      path: source.path,
                      extension: 'pdf',
                      addedAt: DateTime(2026),
                      isTemporary: true,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open test PDF'));
    await waitFor(tester, find.byType(DocumentPasswordDialog));
  }

  testWidgets(
    'reader retries wrong password, opens PDF and saves original-based copy',
    (tester) async {
      await mount(tester);
      final field = find.byType(TextField);
      expect(tester.widget<TextField>(field).obscureText, isTrue);
      expect(tester.widget<TextField>(field).autocorrect, isFalse);
      await tester.enterText(field, 'wrong-value-not-for-logs');
      await tester.tap(find.text('OK'));
      await waitFor(tester, find.text('Password non corretta.'));
      await tester.enterText(find.byType(TextField), password);
      await tester.tap(find.text('OK'));
      final save = find.byKey(const ValueKey('save_pdf_without_password'));
      await waitFor(tester, save);
      expect(find.byType(DocumentPasswordDialog), findsNothing);
      await tester.tap(save);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salva in Sonarpad'));
      await waitFor(
        tester,
        find.text('File salvato nei Documenti di Sonarpad.'),
      );
      await tester.runAsync(() async {
        final library = DocumentLibraryService();
        await library.load();
        expect(library.documents.length, 1);
        final path = await library.resolveFilePath(library.documents.single);
        expect(path, isNot(source.path));
        final copy = openPdfWithPassword(await File(path).readAsBytes());
        final original = openPdfWithPassword(originalBytes, password: password);
        try {
          expect(copy.pages.count == original.pages.count, isTrue);
          expect(
            PdfTextExtractor(copy).extractText() ==
                PdfTextExtractor(original).extractText(),
            isTrue,
          );
          expect(
            (await source.readAsBytes()).toString() == originalBytes.toString(),
            isTrue,
          );
        } finally {
          copy.dispose();
          original.dispose();
        }
      });
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
    },
  );

  testWidgets(
    'cancel returns to previous screen without opening an empty PDF',
    (tester) async {
      await mount(tester);
      await tester.tap(find.text('Annulla'));
      await tester.pumpAndSettle();
      expect(find.byType(DocumentReaderScreen), findsNothing);
      expect(find.text('Open test PDF'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
    },
  );
}
