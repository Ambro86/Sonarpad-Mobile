import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonarpad_mobile_starter/services/html_reader_service.dart';

void main() {
  group('HtmlReaderService', () {
    test('passes all fixtures', () {
      final dir = Directory('test/fixtures');
      if (!dir.existsSync()) {
        fail('Fixtures directory not found');
      }

      final files = dir.listSync().whereType<File>().toList();
      expect(files.isNotEmpty, isTrue, reason: 'No fixtures found');

      for (var file in files) {
        if (!file.path.endsWith('.html') && !file.path.endsWith('.txt')) {
          continue;
        }
        
        final htmlContent = file.readAsStringSync();
        final article = HtmlReaderService.readerModeExtract(htmlContent, 'it');
        
        expect(article, isNotNull, reason: 'Failed to extract article for ${file.path}');
        expect(article!.title.isNotEmpty, isTrue, reason: 'Empty title for ${file.path}');
        expect(article.content.length > 50, isTrue, reason: 'Content too short for ${file.path}');
        // You could add specific checks here if you had the expected output, 
        // but passing the extraction and not returning null/empty is a strong start.
      }
    });
  });
}
