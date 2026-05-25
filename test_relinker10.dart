import 'package:http/http.dart' as http;
void main() async {
  var xmlUrl = 'https://mediapolis.rai.it/relinker/relinkerServlet.htm?cont=2606803&output=7&forceUserAgent=rainet/4.0.5';
  var r = await http.get(Uri.parse(xmlUrl), headers: {'User-Agent': 'Sonarpad TV/1.0'});
  print('Status: ${r.statusCode}');
  print('Body starts with EXTM3U: ${r.body.trimLeft().startsWith('#EXTM3U')}');
  if (r.body.length > 50) {
    print('Body (start): ${r.body.substring(0, 50)}');
  }
}
