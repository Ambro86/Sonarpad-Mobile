import 'dart:io';
import 'dart:convert';

void main() async {
  const url =
      'https://mediapolis.rai.it/relinker/desrai1_160/chunklist_ao.m3u8?baseuri=%2Fraiuno1%2Fhls%2F&tstart=0&tend=1779792267&tk2=297a85275b5e9f55f5e8b70262cc71ceb1708fdeeccd98884e2afd5d91546cb1';
  final request = await HttpClient().getUrl(Uri.parse(url));
  final response = await request.close();
  final bodyBytes = await response.expand((b) => b).toList();
  final body = utf8.decode(bodyBytes, allowMalformed: true);
  stdout.writeln('STATUS: \${response.statusCode}');
  stdout.writeln(body);
}
