import 'dart:io';
import 'dart:convert';

void main() async {
  const url =
      'https://mediapolis.rai.it/relinker/relinkerServlet.htm?cont=2606803&output=54';
  final request = await HttpClient().getUrl(Uri.parse(url));
  final response = await request.close();
  final bodyBytes = await response.expand((b) => b).toList();
  final body = utf8.decode(bodyBytes, allowMalformed: true);
  stdout.writeln('STATUS: \${response.statusCode}');
  stdout.writeln('REDIRECTS: \${response.redirects}');
  stdout.writeln(body);
}
