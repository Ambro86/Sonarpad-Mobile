import 'dart:convert';

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
  });
}
