import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sonarpad_mobile_starter/services/document_text_extractor.dart';

// Synthetic CID font: the code for "l" is 0x000a, not a line feed.
// No personal document or embedded font is stored in this fixture.
List<int> _fixture() {
  const cmap =
      '/CIDInit /ProcSet findresource begin 12 dict begin begincmap '
      '/CIDSystemInfo << /Registry (Adobe) /Ordering (UCS) /Supplement 0 >> def '
      '/CMapName /Test def /CMapType 2 def '
      '1 begincodespacerange <0000> <ffff> endcodespacerange '
      '3 beginbfchar <000a> <006c> <0012> <0069> <0020> <0020> endbfchar '
      'endcmap CMapName currentdict /CMap defineresource pop end end';
  const content = 'BT /F1 12 Tf 40 700 Td <000a0012000a0012> Tj ET';
  final objects = [
    '<< /Type /Catalog /Pages 2 0 R >>',
    '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 600 800] '
        '/Resources << /Font << /F1 4 0 R >> >> /Contents 7 0 R >>',
    '<< /Type /Font /Subtype /Type0 /BaseFont /Arial '
        '/Encoding /Identity-H /DescendantFonts [5 0 R] /ToUnicode 6 0 R >>',
    '<< /Type /Font /Subtype /CIDFontType2 /BaseFont /Arial '
        '/CIDSystemInfo << /Registry (Adobe) /Ordering (Identity) /Supplement 0 >> '
        '/DW 250 /FontDescriptor 8 0 R >>',
    '<< /Length ${cmap.length} >>\nstream\n$cmap\nendstream',
    '<< /Length ${content.length} >>\nstream\n$content\nendstream',
    '<< /Type /FontDescriptor /FontName /Arial /Flags 32 '
        '/FontBBox [0 -200 1000 900] /ItalicAngle 0 /Ascent 900 '
        '/Descent -200 /CapHeight 700 /StemV 80 >>',
  ];
  final pdf = StringBuffer('%PDF-1.4\n');
  final offsets = <int>[0];
  for (var i = 0; i < objects.length; i++) {
    offsets.add(pdf.length);
    pdf.write('${i + 1} 0 obj\n${objects[i]}\nendobj\n');
  }
  final xref = pdf.length;
  pdf.write('xref\n0 ${offsets.length}\n0000000000 65535 f \n');
  for (final offset in offsets.skip(1)) {
    pdf.write('${offset.toString().padLeft(10, '0')} 00000 n \n');
  }
  pdf.write(
    'trailer\n<< /Size ${offsets.length} /Root 1 0 R >>\n'
    'startxref\n$xref\n%%EOF',
  );
  return ascii.encode(pdf.toString());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('PDF extraction preserves narrow glyphs in a CID subset font', () async {
    final dir = await Directory.systemTemp.createTemp('sonarpad-cid-test-');
    try {
      final file = await File(
        '${dir.path}/synthetic.pdf',
      ).writeAsBytes(_fixture());
      final result = await DocumentTextExtractor().extract(
        path: file.path,
        extension: 'pdf',
      );
      expect(result.error, isNull);
      expect(result.text.replaceAll(RegExp(r'\s+'), ''), 'lili');
    } finally {
      await dir.delete(recursive: true);
    }
  });
}
