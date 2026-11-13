import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sonarpad_mobile_starter/l10n/app_localizations.dart';
import 'package:sonarpad_mobile_starter/screens/documents_screen.dart';
import 'package:sonarpad_mobile_starter/screens/audio_description_project_editor_screen.dart';
import 'package:sonarpad_mobile_starter/services/document_library_service.dart';
import 'package:sonarpad_mobile_starter/services/document_text_extractor.dart';
import 'package:sonarpad_mobile_starter/services/audio_description_project_library.dart';
import 'package:sonarpad_mobile_starter/services/ai_audiodescription_service.dart';
import 'package:sonarpad_mobile_starter/widgets/universal_accessible_view.dart';
import 'audio_description_project_editor_test.dart' show sampleProject;

class _Paths extends PathProviderPlatform {
  _Paths(this.root);
  final String root;
  @override
  Future<String?> getApplicationDocumentsPath() async => root;
  @override
  Future<String?> getApplicationSupportPath() async => root;
  @override
  Future<String?> getTemporaryPath() async => root;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late PathProviderPlatform oldPaths;
  final shares = <String>[];
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    root = await Directory.systemTemp.createTemp('ad-document-roundtrip-');
    oldPaths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _Paths(root.path);
    configureAccessibleRendererRuntime(useFlutterOnIos: true);
    shares.clear();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/share'),
      (call) async {
        shares.addAll(
          List<String>.from((call.arguments as Map)['paths'] as List),
        );
        return 'success';
      },
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('flutter_tts'),
      (call) async => call.method == 'getVoices' ? [] : 1,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('com.ryanheise.audio_session'),
      (_) async => null,
    );
  });
  tearDown(() async {
    configureAccessibleRendererRuntime(useFlutterOnIos: false);
    PathProviderPlatform.instance = oldPaths;
    for (final channel in [
      'dev.fluttercommunity.plus/share',
      'flutter_tts',
      'com.ryanheise.audio_session',
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(channel), null);
    }
    await root.delete(recursive: true);
  });
  Future<void> settleIo(WidgetTester tester) async {
    for (var i = 0; i < 30; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  UniversalAccessibleList documents(WidgetTester tester) => tester
      .widgetList<UniversalAccessibleList>(find.byType(UniversalAccessibleList))
      .firstWhere((w) => w.debugTag == 'documents');
  testWidgets(
    'Android project exports text, shares original, reimports edits and opens in project editor',
    (tester) async {
      final library = DocumentLibraryService();
      late String originalPath;
      late String id;
      await tester.runAsync(() async {
        final source = File('${root.path}/Film.sonarpad-ad.json');
        await source.writeAsString(
          jsonEncode(sampleProject(source.path).toJson()),
        );
        final document = await library.importFile(source);
        await library.add(document);
        originalPath = await library.resolveFilePath(document);
        id = document.id;
      });
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('it'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const DocumentsScreen(),
        ),
      );
      await settleIo(tester);
      final l10n = AppLocalizations.of(
        tester.element(find.byType(DocumentsScreen)),
      );
      for (final entry in <String, String>{
        'txt': l10n.textFormat,
        'html': l10n.htmlFormat,
        'md': l10n.markdownFormat,
        'docx': l10n.docxFormat,
        'epub': l10n.epubFormat,
        'pdf': l10n.pdfFormat,
      }.entries) {
        late Future<void> operation;
        await tester.runAsync(() async {
          operation = Future<void>.sync(
            () => documents(tester).onEvent!(
              AccessibleListEvent(
                id: id,
                type: 'customAction',
                action: 'export',
              ),
            ),
          );
        });
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(TextButton, entry.value));
        await settleIo(tester);
        expect(
          find.text(l10n.exportCompleteTitle),
          findsOneWidget,
          reason: entry.key,
        );
        await tester.tap(find.widgetWithText(TextButton, l10n.share));
        await settleIo(tester);
        await tester.runAsync(() => operation);
        expect(shares.last, endsWith('.${entry.key}'));
        await tester.runAsync(() async {
          final extracted = await DocumentTextExtractor().extract(
            path: shares.last,
            extension: entry.key,
          );
          expect(extracted.error, isNull, reason: entry.key);
          expect(
            extracted.text,
            contains('Prima descrizione'),
            reason: entry.key,
          );
          expect(
            extracted.text,
            contains('Seconda descrizione'),
            reason: entry.key,
          );
          expect(extracted.text, isNot(contains('source_path')));
        });
      }
      await tester.runAsync(() async {
        await documents(tester).onEvent!(
          AccessibleListEvent(id: id, type: 'customAction', action: 'share'),
        );
        expect(shares.last, originalPath);
        final shared =
            jsonDecode(await File(shares.last).readAsString())
                as Map<String, dynamic>;
        (shared['descriptions'] as List).first['text'] =
            'Descrizione modificata fuori da Sonarpad';
        final edited = await File(
          '${root.path}/Modificato.json',
        ).writeAsString(jsonEncode(shared));
        final imported = await library.importFile(edited);
        await library.add(imported);
        final projects = await loadAudioDescriptionProjects(library);
        expect(projects.map((p) => p.id), containsAll([id, imported.id]));
        final reader = AiAudioDescriptionService();
        try {
          final restored = await reader.loadEditableProject(
            await library.resolveFilePath(imported),
          );
          expect(
            restored.descriptions.first.text,
            'Descrizione modificata fuori da Sonarpad',
          );
          expect(restored.descriptions.first.sourceStartSec, 2);
          expect(restored.descriptions.last.text, 'Seconda descrizione');
        } finally {
          reader.dispose();
        }
        id = imported.id;
      });
      // Reopen the actual Documents screen and activate the reimported item.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('it'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const DocumentsScreen(),
        ),
      );
      await settleIo(tester);
      unawaited(
        Future<void>.sync(
          () => documents(tester).onEvent!(
            AccessibleListEvent(id: id, type: 'activate'),
          ),
        ),
      );
      await settleIo(tester);
      expect(find.byType(AudioDescriptionProjectEditorScreen), findsOneWidget);
      final editorRows = tester
          .widgetList<UniversalAccessibleList>(
            find.byType(UniversalAccessibleList),
          )
          .expand((w) => w.sections)
          .expand((s) => s.rows);
      expect(
        editorRows.any(
          (r) => r.value == 'Descrizione modificata fuori da Sonarpad',
        ),
        isTrue,
      );
      await tester.pumpWidget(const SizedBox());
      await settleIo(tester);
    },
    variant: TargetPlatformVariant({TargetPlatform.android}),
  );
}
