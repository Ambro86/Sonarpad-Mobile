import 'dart:io';
import 'dart:convert';

void main() async {
  const url =
      'https://mediapolis.rai.it/relinker/relinkerServlet.htm?cont=2606803&output=45';
  final request = await HttpClient().getUrl(Uri.parse(url));
  // non seguiamo redirect automaticamente per vedere se fa redirect
  request.followRedirects = false;
  final response = await request.close();
  final bodyBytes = await response.expand((b) => b).toList();
  final body = utf8.decode(bodyBytes, allowMalformed: true);
  stdout.writeln('STATUS: \${response.statusCode}');
  stdout.writeln('LOCATION: \${response.headers.value("location")}');
  stdout.writeln(body);
}
