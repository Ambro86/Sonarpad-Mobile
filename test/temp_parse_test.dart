import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonarpad_mobile_starter/services/html_reader_service.dart';

void main() {
  test('Temp Parse', () async {
    final inputFile = File(r'C:\rustnotepad\rustnotepad\target\debug\debug_last_fetch.txt');
    if (!inputFile.existsSync()) {
      print('Skipping test, input file not found');
      return;
    }
    
    final html = await inputFile.readAsString();
    final result = HtmlReaderService.readerModeExtract(html, 'it');
    
    final outputFile = File(r'C:\Users\ambro\Documents\parsed_article.txt');
    await outputFile.writeAsString(result?.content ?? 'Nessun risultato');
    // ignore: avoid_print
    print('Scritto con successo in ${outputFile.path}');
  });
}
