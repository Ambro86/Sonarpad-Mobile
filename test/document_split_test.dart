import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonarpad_mobile_starter/l10n/app_localizations.dart';
import 'package:sonarpad_mobile_starter/models/document_item.dart';
import 'package:sonarpad_mobile_starter/screens/document_split_screen.dart';
import 'package:sonarpad_mobile_starter/screens/documents_screen.dart';
import 'package:sonarpad_mobile_starter/widgets/universal_accessible_view.dart';
import 'package:sonarpad_mobile_starter/services/document_library_service.dart';
import 'package:sonarpad_mobile_starter/services/docx_export_service.dart';
import 'package:sonarpad_mobile_starter/services/pdf_export_service.dart';
import 'package:sonarpad_mobile_starter/services/document_media_split_service.dart';
import 'package:sonarpad_mobile_starter/services/media_join_service.dart';

class _Paths extends PathProviderPlatform {
  _Paths(this.root);
  final String root;
  @override
  Future<String?> getApplicationDocumentsPath() async => root;
  @override
  Future<String?> getTemporaryPath() async => root;
}

Future<MediaJoinItemInfo> _probeMedia(String path) async {
  final probe = await Process.run('ffprobe', ['-v','error','-show_streams',
    '-show_format','-of','json',path]);
  expect(probe.exitCode, 0, reason: probe.stderr.toString());
  final data = jsonDecode(probe.stdout as String);
  final types = [for (final s in data['streams']) s['codec_type']];
  return MediaJoinItemInfo(path: path, hasVideo: types.contains('video'),
    hasAudio: types.contains('audio'), duration: Duration(microseconds:
      (double.parse(data['format']['duration']) * 1000000).round()),
    videoStreamIndex: null, audioStreamIndex: null, width: null, height: null,
    rotationDegrees: 0, frameRate: types.contains('video') ? 25 : null);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final originalPaths = PathProviderPlatform.instance;
  late Directory work;
  late DocumentLibraryService library;
  late DocumentItem source;
  const text = 'A👨‍👩‍👧‍👦B\nC🇮🇹D';
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    work = await Directory.systemTemp.createTemp('document-split-');
    PathProviderPlatform.instance = _Paths(work.path);
    library = DocumentLibraryService();
    final folder = await library.createFolder('Books');
    source = await library.createTextDocument(
      name: 'Notes.txt',
      content: text,
      parentId: folder.id,
    );
    await library.add(source);
  });
  tearDown(() async {
    PathProviderPlatform.instance = originalPaths;
    await work.delete(recursive: true);
  });

  for (final viaButton in [false, true]) {
    testWidgets('closed document opens split via ${viaButton ? "button" : "custom action"}', (tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(MaterialApp(
          locale: const Locale('it'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: DocumentsScreen(folderId: source.parentId),
        ));
        await Future<void>.delayed(const Duration(milliseconds: 60));
      });
      await tester.pumpAndSettle();
      final list = tester.widget<UniversalAccessibleList>(find.byType(UniversalAccessibleList));
      final row = list.sections.expand((s) => s.rows).singleWhere((r) => r.id == source.id);
      expect(row.actions.singleWhere((a) => a.id == 'split_document').label, 'Dividi documento');
      expect(row.visualActions.singleWhere((a) => a.id == 'split_document').label, 'Dividi documento');
      await tester.runAsync(() async {
        if (viaButton) {
          final button = find.byTooltip('Dividi documento');
          expect(find.ancestor(of: button, matching: find.byType(ExcludeSemantics)), findsWidgets);
          await tester.ensureVisible(button);
          await tester.tap(button);
        } else {
          unawaited(Future<void>.value(list.onEvent!(AccessibleListEvent(
            type: 'customAction', id: source.id, action: 'split_document'))));
        }
        await Future<void>.delayed(const Duration(milliseconds: 80));
      });
      await tester.pumpAndSettle();
      expect(tester.widget<DocumentSplitScreen>(find.byType(DocumentSplitScreen)).text, text);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  }

  for (final extension in ['pdf', 'doc', 'docx']) {
    testWidgets('split a closed .$extension and reopen the numbered TXT files', (tester) async {
      const sentence = 'Il caffè è pronto. Seconda frase.';
      final expected = extension == 'doc' ? 'Cafè\n123\n東京\n' : sentence;
      late DocumentItem input;
      late List<int> bytes;
      await tester.runAsync(() async {
        bytes = switch (extension) {
          'doc' => await File('test/fixtures/word_mixed_cells.doc').readAsBytes(),
          'docx' => DocxExportService().buildDocx(sentence),
          _ => await PdfExportService().buildPdf(sentence),
        };
        final file = await File('${work.path}/Libro.$extension').writeAsBytes(bytes);
        input = await library.importFile(file, parentId: source.parentId);
        await library.add(input);
        await tester.pumpWidget(MaterialApp(
          locale: const Locale('it'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: DocumentsScreen(folderId: source.parentId),
        ));
      });
      Future<void> waitFor(bool Function() ready) async {
        for (var i = 0; i < 150 && !ready(); i++) {
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
          await tester.pump(const Duration(milliseconds: 30));
        }
        expect(ready(), isTrue);
      }
      Iterable<AccessibleListRow> rows() => tester
          .widgetList<UniversalAccessibleList>(find.byType(UniversalAccessibleList))
          .expand((list) => list.sections).expand((section) => section.rows);
      await waitFor(() => rows().any((row) => row.id == input.id));
      final row = rows().singleWhere((row) => row.id == input.id);
      final action = row.actions.singleWhere((action) => action.label == 'Dividi documento');
      final list = tester.widget<UniversalAccessibleList>(find.byType(UniversalAccessibleList));
      await tester.runAsync(() async {
        unawaited(Future<void>.value(list.onEvent!(AccessibleListEvent(
          type: 'customAction', id: input.id, action: action.id))));
      });
      await waitFor(() => find.byType(DocumentSplitScreen).evaluate().isNotEmpty);
      await tester.pumpAndSettle();
      expect(tester.widget<DocumentSplitScreen>(find.byType(DocumentSplitScreen)).text, expected);
      await tester.runAsync(() => tester.tap(find.widgetWithText(ListTile, 'Dividi documento')));
      await waitFor(() => rows().any((row) => row.title.startsWith('Libro - 2')));
      await tester.runAsync(() async {
        final reopened = DocumentLibraryService();
        await reopened.load();
        final parts = reopened.documents.where((doc) => doc.name.startsWith('Libro - ')).toList();
        expect(parts.map((doc) => doc.name), ['Libro - 1.txt', 'Libro - 2.txt']);
        expect(parts.every((doc) => doc.parentId == input.parentId), isTrue);
        final contents = await Future.wait(parts.map((doc) async =>
            File(await reopened.resolveFilePath(doc)).readAsString()));
        expect(contents.every((part) => part.isNotEmpty), isTrue);
        expect(contents.join(), expected);
        expect(await File(await reopened.resolveFilePath(input)).readAsBytes(), bytes);
      });
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  }

  var mediaTools = false;
  try {
    mediaTools = ['ffmpeg','ffprobe'].every((tool) => Process.runSync(tool, ['-version']).exitCode == 0);
  } on ProcessException { /* Optional host tools for real-media tests. */ }
  for (final extension in ['mp3','mp4','avi']) {
    test('split real $extension into three playable files in Documents', () async {
      final video = extension != 'mp3';
      final input = File('${work.path}/Clip.$extension');
      final generated = await Process.run('ffmpeg', ['-v','error',
        if (video) ...['-f','lavfi','-i','testsrc2=size=96x64:rate=25'],
        '-f','lavfi','-i','sine=frequency=880:sample_rate=48000','-t','6',
        if (video) ...['-c:v','mpeg4','-g', extension == 'mp4' ? '300' : '25',
          '-sc_threshold','1000000000'],
        '-c:a', extension == 'mp4' ? 'aac' : 'libmp3lame',input.path]);
      expect(generated.exitCode, 0, reason: generated.stderr.toString());
      final doc = await library.importFile(input, parentId: source.parentId);
      await library.add(doc);
      final info = await _probeMedia(await library.resolveFilePath(doc));
      final runs = <List<String>>[];
      final splitter = DocumentMediaSplitService(probe: _probeMedia, execute: (args) async {
        runs.add(args);
        return (await Process.run('ffmpeg', ['-v','error',...args])).exitCode == 0;
      });
      expect(await library.saveSplitMedia(doc, info, 3, splitter: splitter), 3);
      expect(runs.first, contains('copy'));
      if (extension == 'mp4') expect(runs.last, contains('-force_key_frames'));
      final reopened = DocumentLibraryService();
      await reopened.load();
      final parts = reopened.documents.where((d) => d.name.startsWith('Clip - '));
      expect(parts.map((d) => d.name), [for (var i = 1; i <= 3; i++) 'Clip - $i.$extension']);
      for (final part in parts) {
        expect(part.parentId, doc.parentId);
        final path = await reopened.resolveFilePath(part);
        final media = await _probeMedia(path);
        expect(media.hasAudio, isTrue);
        expect(media.hasVideo, video);
        expect(media.duration.inMilliseconds, closeTo(2000,150));
        final decode = await Process.run('ffmpeg', ['-v','error','-xerror','-i',path,'-f','null','-']);
        expect(decode.exitCode, 0, reason: decode.stderr.toString());
      }
      expect(await File(info.path).readAsBytes(), await input.readAsBytes());
    }, skip: mediaTools ? false : 'Requires FFmpeg and FFprobe');
  }

  testWidgets('media shows only number of parts, including custom', (tester) async {
    final info = MediaJoinItemInfo(path: 'clip.mp3', hasAudio: true, hasVideo: false,
      duration: const Duration(minutes: 1), videoStreamIndex: null, audioStreamIndex: 0,
      width: null, height: null, rotationDegrees: 0, frameRate: null);
    await tester.pumpWidget(MaterialApp(locale: const Locale('it'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: DocumentSplitScreen.media(document: source, info: info)));
    await tester.pumpAndSettle();
    final rows = tester.widget<UniversalAccessibleList>(find.byType(UniversalAccessibleList)).sections.single.rows;
    final slider = rows.singleWhere((r) => r.kind == 'slider');
    expect(slider.title, 'Numero di parti');
    expect(slider.options.map((o) => o.label), [for (var i=1;i<=10;i++) '$i', 'Personalizzato']);
    expect(rows.last.title, 'Dividi file media');
    await slider.onValueChanged!(10);
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('closed media exposes the split action and its sighted button', (tester) async {
    late DocumentItem doc;
    await tester.runAsync(() async {
      final file = await File('${work.path}/Audio.mp3').writeAsBytes([1]);
      doc = await library.importFile(file, parentId: source.parentId);
      await library.add(doc);
      await tester.pumpWidget(MaterialApp(locale: const Locale('it'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DocumentsScreen(folderId: source.parentId)));
      await Future<void>.delayed(const Duration(milliseconds: 80));
    });
    await tester.pumpAndSettle();
    final list = tester.widget<UniversalAccessibleList>(find.byType(UniversalAccessibleList));
    final row = list.sections.expand((s) => s.rows).singleWhere((r) => r.id == doc.id);
    expect(row.actions.singleWhere((a) => a.id == 'split_document').label, 'Dividi file media');
    final button = find.byTooltip('Dividi file media');
    expect(find.ancestor(of: button, matching: find.byType(ExcludeSemantics)), findsWidgets);
  });

  Future<List<String>> readParts() async {
    final reopened = DocumentLibraryService();
    await reopened.load();
    final docs = reopened.documents.where(
      (d) => d.parentId == source.parentId && d.id != source.id,
    );
    expect(
      await File(await reopened.resolveFilePath(source)).readAsString(),
      text,
    );
    return Future.wait(
      docs.map(
        (d) async => File(await reopened.resolveFilePath(d)).readAsString(),
      ),
    );
  }

  for (final entry in [
    (true, 3, [3, 2, 2]),
    (false, 3, [3, 3, 1]),
    (true, 1, [7]),
    (false, 10000, [7]),
  ]) {
    test(
      'save to Documents and reopen: byParts=${entry.$1}, value=${entry.$2}',
      () async {
        await library.saveSplitDocument(
          source,
          text,
          byParts: entry.$1,
          value: entry.$2,
        );
        final parts = await readParts();
        expect(parts.map((s) => s.characters.length), entry.$3);
        expect(parts.join(), text);
      },
    );
  }
  test(
    'invalid counts create no files; repeated splits preserve earlier files',
    () async {
      for (final n in [0, -1, 8]) {
        await expectLater(
          library.saveSplitDocument(source, text, byParts: true, value: n),
          throwsArgumentError,
        );
      }
      expect(await readParts(), isEmpty);
      for (var i = 0; i < 2; i++) {
        await library.saveSplitDocument(source, text, byParts: true, value: 2);
      }
      expect((await readParts()).join(), text + text);
    },
  );

  testWidgets(
    'accessible adjustments stay independent and a custom split saves files',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('it'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<int>(
                  builder: (_) =>
                      DocumentSplitScreen(document: source, text: text),
                ),
              ),
              child: const Text('Apri'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Apri'));
      await tester.pumpAndSettle();
      int node(String label) =>
          tester.getSemantics(find.bySemanticsLabel(label)).id;
      Future<void> adjust(String label, SemanticsAction action) async {
        final id = node(label);
        tester.semantics.performAction(find.semantics.byLabel(label), action);
        await tester.pumpAndSettle();
        expect(node(label), id);
      }

      const mode = 'Metodo di divisione';
      const parts = 'Numero di parti';
      const chars = 'Caratteri per parte';
      await adjust(parts, SemanticsAction.increase);
      expect(tester.getSemantics(find.bySemanticsLabel(parts)).value, '3');
      await adjust(mode, SemanticsAction.increase);
      for (var i = 0; i < 7; i++) {
        await adjust(chars, SemanticsAction.increase);
      }
      await tester.enterText(find.byType(TextField), '3');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await adjust(mode, SemanticsAction.decrease);
      expect(tester.getSemantics(find.bySemanticsLabel(parts)).value, '3');
      for (var i = 3; i <= 10; i++) {
        await adjust(parts, SemanticsAction.increase);
      }
      await tester.enterText(find.byType(TextField), '5');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await adjust(mode, SemanticsAction.increase);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '3',
      );
      await tester.runAsync(() async {
        await tester.tap(find.widgetWithText(ListTile, 'Dividi documento'));
        for (var i = 0; i < 100 && (await readParts()).length != 3; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        expect(await readParts(), ['A👨‍👩‍👧‍👦B', '\nC🇮🇹', 'D']);
      });
      await tester.pumpAndSettle();
      expect(find.text('Apri'), findsOneWidget);
    },
  );
}
