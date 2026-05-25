import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:syncfusion_flutter_pdf/pdf.dart';

Future<void> main() async {
  // Download aspirina PDF
  const url =
      'https://api.aifa.gov.it/aifa-bdf-eif-be/1.0.0/organizzazione/22/farmaci/4763/stampati?ts=FI';
  final response = await http.get(
    Uri.parse(url),
    headers: {'User-Agent': 'SonarpadMobile/1.0'},
  );

  if (response.statusCode != 200) {
    stdout.writeln('Failed to download PDF: ${response.statusCode}');
    return;
  }

  final pdfBytes = response.bodyBytes;
  final document = PdfDocument(inputBytes: pdfBytes);
  final textExtractor = PdfTextExtractor(document);
  final text = textExtractor.extractText();
  document.dispose();

  stdout.writeln('Extracted text length: ${text.length}');

  // Test le regex
  final s1 = RegExp(r'(?:\n|^)\s*1\.\s+[Cc]he\s+cos');
  final s2 = RegExp(r'(?:\n|^)\s*2\.\s+[Cc]osa\s+deve');
  final s3 = RegExp(r'(?:\n|^)\s*3\.\s+[Cc]ome\s+(?:prendere|usare|assumere)');
  final s4 = RegExp(r'(?:\n|^)\s*4\.\s+[Pp]ossibili\s+effetti');

  stdout.writeln('Match 1 with newline: ${s1.hasMatch(text)}');
  stdout.writeln('Match 2 with newline: ${s2.hasMatch(text)}');
  stdout.writeln('Match 3 with newline: ${s3.hasMatch(text)}');
  stdout.writeln('Match 4 with newline: ${s4.hasMatch(text)}');

  // Test without newline requirement
  final s1No = RegExp(r'1\.\s+[Cc]he\s+cos');
  final s2No = RegExp(r'2\.\s+[Cc]osa\s+deve');
  stdout.writeln('Match 1 without newline: ${s1No.hasMatch(text)}');
  stdout.writeln('Match 2 without newline: ${s2No.hasMatch(text)}');

  if (s1.hasMatch(text)) {
    final match = s1.firstMatch(text)!;
    stdout.writeln(
      'Context around Match 1:\n'
      '${text.substring(match.start, match.start + 50)}',
    );
  } else if (s1No.hasMatch(text)) {
    final match = s1No.firstMatch(text)!;
    stdout.writeln(
      'Context around Match 1 (no newline):\n'
      '${text.substring(match.start - 20, match.start + 50)}',
    );
  }
}
