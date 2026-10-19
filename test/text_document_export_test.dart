import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html;
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonarpad_mobile_starter/services/text_document_export_service.dart';
import 'package:sonarpad_mobile_starter/services/document_text_extractor.dart';
import 'package:sonarpad_mobile_starter/services/document_library_service.dart';

class _Paths extends PathProviderPlatform {
  _Paths(this.root);
  final String root;
  @override
  Future<String?> getApplicationDocumentsPath() async => root;
  @override
  Future<String?> getApplicationSupportPath() async => root;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temp;
  late PathProviderPlatform oldPaths;
  final exporter = TextDocumentExportService();
  const sample =
      'Caffè, İstanbul, Iğdır, Şişli, Україна, 中文, 😀.\n'
      'Seconda riga & simboli < > " apostrofo \'.\n\n'
      '# Titolo Markdown\n- voce **importante**\n\nUltimo paragrafo.';

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('sonarpad-text-export-');
    oldPaths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _Paths(temp.path);
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() async {
    PathProviderPlatform.instance = oldPaths;
    await temp.delete(recursive: true);
  });

  for (final format in TextDocumentExportFormat.values) {
    test(
      '$format writes a real UTF-8 file, imports and reopens in Documents',
      () async {
        final extension = format == TextDocumentExportFormat.markdown
            ? 'md'
            : 'html';
        final file = await exporter.write(
          path: '${temp.path}/İstanbul_export.$extension',
          text: sample,
          format: format,
          title: 'Titolo & İstanbul',
          language: 'tr_TR',
        );
        expect(await file.exists(), isTrue);
        final content = utf8.decode(
          await file.readAsBytes(),
          allowMalformed: false,
        );
        if (format == TextDocumentExportFormat.markdown) {
          expect(content, sample);
        } else {
          final document = html.parse(content);
          expect(
            document.querySelector('meta[charset]')!.attributes['charset'],
            'utf-8',
          );
          expect(document.documentElement!.attributes['lang'], 'tr-TR');
          expect(document.querySelector('title')!.text, 'Titolo & İstanbul');
          expect(
            document.querySelectorAll('main p').map((p) => p.text).join('\n\n'),
            sample,
          );
        }
        final library = DocumentLibraryService();
        final imported = await library.importFile(
          file,
          originalName: 'Esportato.$extension',
        );
        await library.add(imported);
        final reopened = DocumentLibraryService();
        await reopened.load();
        final doc = reopened.documents.single;
        expect(doc.extension, extension);
        final path = await reopened.resolveFilePath(doc);
        expect(await File(path).readAsBytes(), await file.readAsBytes());
        final extracted = await DocumentTextExtractor().extract(
          path: path,
          extension: extension,
        );
        expect(extracted.error, isNull);
        expect(
          extracted.text.replaceAll(RegExp(r'\s+'), ' ').trim(),
          sample.replaceAll(RegExp(r'\s+'), ' '),
        );
      },
    );
  }

  test(
    'HTML exports literal tags without executing scripts or loading remote resources',
    () async {
      const source =
          '<script>alert("x")</script>\n<img src="https://example.org/x" onerror="alert(1)">\nA & B';
      final file = await exporter.write(
        path: '${temp.path}/safe.html',
        text: source,
        format: TextDocumentExportFormat.html,
        title: '</title><script>bad()</script>',
        language: 'it" onload="bad()',
      );
      final parsed = html.parse(await file.readAsString());
      expect(parsed.querySelectorAll('script,img,iframe'), isEmpty);
      expect(parsed.documentElement!.attributes['lang'], 'und');
      expect(parsed.querySelector('main p')!.text, source);
      expect(
        parsed.querySelector('title')!.text,
        '</title><script>bad()</script>',
      );
    },
  );

  test(
    'Both exports retain the entire long document and normalize line endings',
    () async {
      final paragraphs = List.generate(
        1000,
        (i) => 'Paragrafo $i: İstanbul è leggibile.',
      );
      final source = paragraphs.join('\r\n\r\n');
      for (final format in TextDocumentExportFormat.values) {
        final file = await exporter.write(
          path: '${temp.path}/long.${format.name}',
          text: source,
          format: format,
          title: 'Lungo',
        );
        final data = await file.readAsString();
        final recovered = format == TextDocumentExportFormat.markdown
            ? data
            : html
                  .parse(data)
                  .querySelectorAll('main p')
                  .map((p) => p.text)
                  .join('\n\n');
        expect(recovered, paragraphs.join('\n\n'));
      }
    },
  );
}
