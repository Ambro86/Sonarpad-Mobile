import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonarpad_mobile_starter/services/pdf_export_service.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

const _turkishText = 'İstanbul, Iğdır, Şişli: Çç Ğğ İı Öö Şş Üü âîû. '
    '“Türkçe” — özgürlük, ışık ve sağlık; 20 €.';

class _MissingFontBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async =>
      throw StateError('Font asset unavailable');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Turkish text and punctuation survive normalization', () {
    expect(normalizePdfExportText(_turkishText), _turkishText);
    expect(normalizePdfExportText('\uFEFFİlk satır\r\nİkinci\rÜçüncü\u200B'),
        'İlk satır\nİkinci\nÜçüncü');
  });

  test('PDF round trip preserves all Turkish letters and real punctuation',
      () async {
    final bytes = await PdfExportService().buildPdf(_turkishText);
    final document = PdfDocument(inputBytes: bytes);
    try {
      final extracted = PdfTextExtractor(document).extractText();
      expect(extracted.replaceAll(RegExp(r'\s+'), ' ').trim(), _turkishText);
      expect(extracted, isNot(contains('?')));
    } finally {
      document.dispose();
    }
  });

  test('PDF pagination preserves the first and last Turkish paragraphs',
      () async {
    final paragraphs = List.generate(150, (index) => 'Paragraf $index: $_turkishText');
    final bytes = await PdfExportService().buildPdf(paragraphs.join('\n\n'));
    final document = PdfDocument(inputBytes: bytes);
    try {
      expect(document.pages.count, greaterThan(1));
      final extracted = PdfTextExtractor(document).extractText();
      expect(extracted, contains('Paragraf 0:'));
      expect(extracted, contains('Paragraf 149:'));
      expect(
        RegExp(r'Paragraf (\d+):')
            .allMatches(extracted)
            .map((match) => int.parse(match.group(1)!)),
        List.generate(150, (index) => index),
      );
      expect(extracted, contains('İstanbul'));
      expect(extracted, contains('Iğdır'));
    } finally {
      document.dispose();
    }
  });

  test('A missing embedded font fails instead of silently damaging text', () async {
    await expectLater(
      PdfExportService(assets: _MissingFontBundle()).buildPdf(_turkishText),
      throwsStateError,
    );
  });
}
