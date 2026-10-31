import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:sonarpad_mobile_starter/services/document_text_extractor.dart';
import 'package:sonarpad_mobile_starter/services/pdf_password_service.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<Uint8List> fixture({bool encrypted = true}) async {
    final pdf = PdfDocument();
    try {
      pdf.pages.add().graphics.drawString(
        'First page with original layout',
        PdfStandardFont(PdfFontFamily.helvetica, 15),
        bounds: const Rect.fromLTWH(40, 70, 300, 50),
      );
      pdf.pages.add().graphics.drawString(
        'Second page',
        PdfStandardFont(PdfFontFamily.courier, 20),
        bounds: const Rect.fromLTWH(60, 100, 300, 50),
      );
      if (encrypted) {
        pdf.security
          ..userPassword = 'test-password'
          ..ownerPassword = 'different-owner';
      }
      return Uint8List.fromList(await pdf.save());
    } finally {
      pdf.dispose();
    }
  }

  test(
    'missing and wrong passwords are typed and do not leak secrets',
    () async {
      final bytes = await fixture();
      for (final password in [null, 'wrong-private-value']) {
        expect(
          () => openPdfWithPassword(bytes, password: password),
          throwsA(isA<PdfPasswordRequired>()),
        );
      }
      expect(
        const PdfPasswordRequired().toString(),
        isNot(contains('wrong-private-value')),
      );
    },
  );

  test('export preserves pages, geometry, text and source bytes', () async {
    final bytes = await fixture();
    final before = List<int>.from(bytes);
    final exported = await pdfWithoutPassword(bytes, 'test-password');
    final original = openPdfWithPassword(bytes, password: 'test-password');
    final copy = openPdfWithPassword(exported);
    try {
      expect(copy.pages.count, original.pages.count);
      expect(
        PdfTextExtractor(copy).extractText(),
        PdfTextExtractor(original).extractText(),
      );
      for (var i = 0; i < copy.pages.count; i++) {
        expect(copy.pages[i].size, original.pages[i].size);
      }
      expect(bytes, before);
      expect(
        () => openPdfWithPassword(bytes),
        throwsA(isA<PdfPasswordRequired>()),
      );
    } finally {
      original.dispose();
      copy.dispose();
    }
  });

  test(
    'extractor asks for password, retries and still reads ordinary PDFs',
    () async {
      final dir = await Directory.systemTemp.createTemp('sonarpad-pdf-test-');
      final file = File('${dir.path}/test.pdf');
      try {
        await file.writeAsBytes(await fixture());
        final extractor = DocumentTextExtractor();
        for (final password in [null, 'wrong-private-value']) {
          final result = await extractor.extract(
            path: file.path,
            extension: 'pdf',
            pdfPassword: password,
          );
          expect(result.passwordRequired, isTrue);
          expect(result.error, isNull);
          expect(result.text, isEmpty);
        }
        final result = await extractor.extract(
          path: file.path,
          extension: 'pdf',
          pdfPassword: 'test-password',
        );
        expect(result.passwordRequired, isFalse);
        expect(result.text, contains('First page'));
        await file.writeAsBytes(await fixture(encrypted: false));
        final plain = await extractor.extract(
          path: file.path,
          extension: 'pdf',
        );
        expect(plain.passwordRequired, isFalse);
        expect(plain.text, contains('First page'));
      } finally {
        await dir.delete(recursive: true);
      }
    },
  );

  final privatePath = Platform.environment['SONARPAD_TEST_PDF_PATH'];
  final password = Platform.environment['SONARPAD_TEST_PDF_PASSWORD'];
  test('private PDF opens and exports without changing the source', () async {
    final source = File(privatePath!);
    final before = await source.readAsBytes();
    final extractor = DocumentTextExtractor();
    final locked = await extractor.extract(path: source.path, extension: 'pdf');
    expect(locked.passwordRequired, isTrue);
    final opened = await extractor.extract(
      path: source.path,
      extension: 'pdf',
      pdfPassword: password,
    );
    expect(opened.text.isNotEmpty, isTrue);
    // Optional regression assertions for the privately supplied extraction
    // sample. Only boolean/count failures are reported, never document text.
    if (Platform.environment['SONARPAD_TEST_PDF_GLYPH_REGRESSION'] == '1') {
      expect(opened.text.contains('Nome Paziente'), isTrue);
      expect('l'.allMatches(opened.text).length, 350);
      expect('i'.allMatches(opened.text).length, greaterThanOrEqualTo(629));
    }
    final exported = await pdfWithoutPassword(before, password!);
    final original = openPdfWithPassword(before, password: password);
    final copy = openPdfWithPassword(exported);
    try {
      expect(copy.pages.count == original.pages.count, isTrue);
      expect(
        PdfTextExtractor(copy).extractText() ==
            PdfTextExtractor(original).extractText(),
        isTrue,
      );
      for (var i = 0; i < copy.pages.count; i++) {
        expect(copy.pages[i].size == original.pages[i].size, isTrue);
      }
      expect(
        (await source.readAsBytes()).toString() == before.toString(),
        isTrue,
      );
      // Optional local artifact for independent visual verification; never logged.
      final output = Platform.environment['SONARPAD_TEST_PDF_OUTPUT'];
      if (output != null) await File(output).writeAsBytes(exported);
    } finally {
      original.dispose();
      copy.dispose();
    }
  }, skip: privatePath == null || password == null);
}
