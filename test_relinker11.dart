import 'dart:io';

import 'package:http/http.dart' as http;

void main() async {
  const xmlUrl =
      'https://mediapolis.rai.it/relinker/relinkerServlet.htm?cont=2606803&output=7&forceUserAgent=rainet/4.0.5';
  final r = await http.get(Uri.parse(xmlUrl), headers: {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
  });
  stdout.writeln('Status: ${r.statusCode}');
  stdout.writeln(
      'Body starts with EXTM3U: ${r.body.trimLeft().startsWith('#EXTM3U')}');
  if (r.body.length > 50) {
    stdout.writeln('Body (start): ${r.body.substring(0, 50)}');
  }
}
