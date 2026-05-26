import 'dart:io';
import 'dart:convert';

void main() async {
  const url =
      'https://mediapolis.rai.it/relinker/relinkerServlet.htm?cont=2606803&output=7&forceUserAgent=rainet/4.0.5';
  final request = await HttpClient().getUrl(Uri.parse(url));
  final response = await request.close();
  final bodyBytes = await response.expand((b) => b).toList();
  final body = utf8.decode(bodyBytes, allowMalformed: true);
  stdout.writeln('STATUS: \${response.statusCode}');
  stdout.writeln(body);
}
