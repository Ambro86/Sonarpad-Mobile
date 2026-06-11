import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sonarpad_mobile_starter/services/document_text_extractor.dart';

void main() {
  group('DocumentTextExtractor encoding', () {
    test('decodes Czech Windows-1250 text', () {
      const bytes = [
        0x50,
        0xF8,
        0xED,
        0x6C,
        0x69,
        0x9A,
        0x20,
        0x9E,
        0x6C,
        0x75,
        0x9D,
        0x6F,
        0x75,
        0xE8,
        0x6B,
        0xFD,
        0x20,
        0x6B,
        0xF9,
        0xF2,
        0x20,
        0xFA,
        0x70,
        0xEC,
        0x6C,
        0x20,
        0xEF,
        0xE1,
        0x62,
        0x65,
        0x6C,
        0x73,
        0x6B,
        0xE9,
        0x20,
        0xF3,
        0x64,
        0x79,
        0x2E,
      ];

      final decoded = DocumentTextExtractor.decodeDocumentTextBytes(bytes);

      expect(decoded, 'Příliš žluťoučký kůň úpěl ďábelské ódy.');
    });

    test('repairs Czech UTF-8 mojibake text', () {
      final bytes = utf8.encode('PÅ™Ã­liÅ¡ kÅ¯Åˆ ÃºpÄ›l.');

      final decoded = DocumentTextExtractor.decodeDocumentTextBytes(bytes);

      expect(decoded, 'Příliš kůň úpěl.');
    });

    test('keeps Italian Windows-1252 accents', () {
      const bytes = [
        0x4C,
        0x75,
        0x61,
        0x6E,
        0x61,
        0x20,
        0x61,
        0x72,
        0x72,
        0x69,
        0x76,
        0xF2,
        0x20,
        0x61,
        0x6C,
        0x6C,
        0x92,
        0x61,
        0x6C,
        0x74,
        0x65,
        0x7A,
        0x7A,
        0x61,
        0x2E,
      ];

      final decoded = DocumentTextExtractor.decodeDocumentTextBytes(bytes);

      expect(decoded, 'Luana arrivò all’altezza.');
    });
    test('decodes UTF-16 and UTF-32 text with or without BOM', () {
      final expected = String.fromCharCodes([
        0x0043,
        0x0069,
        0x0074,
        0x0074,
        0x00E0,
      ]);

      expect(
        DocumentTextExtractor.decodeDocumentTextBytes(
          const [
            0xFF,
            0xFE,
            0x43,
            0x00,
            0x69,
            0x00,
            0x74,
            0x00,
            0x74,
            0x00,
            0xE0,
            0x00,
          ],
        ),
        expected,
      );
      expect(
        DocumentTextExtractor.decodeDocumentTextBytes(
          const [0x43, 0x00, 0x69, 0x00, 0x74, 0x00, 0x74, 0x00, 0xE0, 0x00],
        ),
        expected,
      );
      expect(
        DocumentTextExtractor.decodeDocumentTextBytes(
          const [
            0xFF,
            0xFE,
            0x00,
            0x00,
            0x43,
            0x00,
            0x00,
            0x00,
            0x69,
            0x00,
            0x00,
            0x00,
            0x74,
            0x00,
            0x00,
            0x00,
            0x74,
            0x00,
            0x00,
            0x00,
            0xE0,
            0x00,
            0x00,
            0x00,
          ],
        ),
        expected,
      );
    });

    test('decodes common non-western Windows ANSI code pages', () {
      final cases = <List<int>, String>{
        const [0xCF, 0xF0, 0xE8, 0xE2, 0xE5, 0xF2]: String.fromCharCodes([
          0x041F,
          0x0440,
          0x0438,
          0x0432,
          0x0435,
          0x0442,
        ]),
        const [0xCA, 0xE1, 0xEB, 0xE7, 0xEC, 0xDD, 0xF1, 0xE1]:
            String.fromCharCodes([
          0x039A,
          0x03B1,
          0x03BB,
          0x03B7,
          0x03BC,
          0x03AD,
          0x03C1,
          0x03B1,
        ]),
        const [0xDE, 0x65, 0x68, 0x69, 0x72, 0x20, 0xFD, 0xFE, 0xFD, 0xF0, 0xFD]:
            String.fromCharCodes([
          0x015E,
          0x0065,
          0x0068,
          0x0069,
          0x0072,
          0x0020,
          0x0131,
          0x015F,
          0x0131,
          0x011F,
          0x0131,
        ]),
        const [0xF9, 0xEC, 0xE5, 0xED, 0x20, 0xA4]: String.fromCharCodes([
          0x05E9,
          0x05DC,
          0x05D5,
          0x05DD,
          0x0020,
          0x20AA,
        ]),
        const [0xE3, 0xD1, 0xCD, 0xC8, 0xC7]: String.fromCharCodes([
          0x0645,
          0x0631,
          0x062D,
          0x0628,
          0x0627,
        ]),
      };

      for (final entry in cases.entries) {
        expect(
          DocumentTextExtractor.decodeDocumentTextBytes(entry.key),
          entry.value,
        );
      }
    });

    test('extracts small TXT, HTML and RTF samples', () async {
      final dir = await Directory.systemTemp.createTemp('sonarpad_extract_');
      try {
        final extractor = DocumentTextExtractor();
        final txt = File('${dir.path}/accenti.txt');
        final html = File('${dir.path}/pagina.html');
        final rtf = File('${dir.path}/nota.rtf');
        final expectedTxt = String.fromCharCodes([
          0x0043,
          0x0061,
          0x0066,
          0x00E8,
          0x0020,
          0x0065,
          0x0020,
          0x0063,
          0x0069,
          0x0074,
          0x0074,
          0x00E0,
        ]);

        await txt.writeAsBytes(const [
          0x43,
          0x61,
          0x66,
          0xE8,
          0x20,
          0x65,
          0x20,
          0x63,
          0x69,
          0x74,
          0x74,
          0xE0,
        ]);
        await html.writeAsString(
          '<html><body><h1>Titolo</h1><p>$expectedTxt</p></body></html>',
        );
        await rtf.writeAsBytes(const [
          0x4E,
          0x6F,
          0x74,
          0x61,
          0x20,
          0xE8,
        ]);

        expect(
          (await extractor.extract(path: txt.path, extension: 'txt')).text,
          expectedTxt,
        );
        expect(
          (await extractor.extract(path: html.path, extension: 'html')).text,
          contains(expectedTxt),
        );
        expect(
          (await extractor.extract(path: rtf.path, extension: 'rtf')).text,
          String.fromCharCodes([0x004E, 0x006F, 0x0074, 0x0061, 0x0020, 0x00E8]),
        );
      } finally {
        await dir.delete(recursive: true);
      }
    });
  });
}
