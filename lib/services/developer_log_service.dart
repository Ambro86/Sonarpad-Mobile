import 'dart:convert';

import 'package:http/http.dart' as http;

class DeveloperLogService {
  static final Uri _endpoint =
      Uri.parse('https://sonarpad.com/api/logdeveloper.php');

  static Future<bool> sendReport({
    required String log,
    required String report,
    String name = '',
  }) async {
    try {
      final response = await http
          .post(
            _endpoint,
            headers: const {
              'Content-Type': 'application/json; charset=utf-8',
              'Accept': 'application/json',
              'User-Agent': 'Sonarpad-Mobile',
            },
            body: jsonEncode({
              'name': name.trim(),
              'report': report.trim(),
              'log': log,
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return false;
      }

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      return decoded is Map<String, dynamic> && decoded['ok'] == true;
    } catch (_) {
      return false;
    }
  }
}
