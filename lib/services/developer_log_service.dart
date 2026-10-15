import 'dart:convert';

import 'package:http/http.dart' as http;

class DeveloperLogService {
  static final Uri _endpoint = Uri.parse(
    'https://sonarpad.com/api/logdeveloper.php',
  );

  static bool isValidReplyEmail(String value) {
    final email = value.trim();
    if (email.isEmpty) return true;
    if (email.length > 254 || email.codeUnits.any((c) => c > 127)) return false;
    final parts = email.split('@');
    if (parts.length != 2) return false;
    final local = parts[0];
    final domain = parts[1];
    return local.isNotEmpty &&
        local.length <= 64 &&
        !local.startsWith('.') &&
        !local.endsWith('.') &&
        !local.contains('..') &&
        RegExp(r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+$").hasMatch(local) &&
        domain.contains('.') &&
        domain
            .split('.')
            .every(
              (part) =>
                  part.isNotEmpty &&
                  part.length <= 63 &&
                  !part.startsWith('-') &&
                  !part.endsWith('-') &&
                  RegExp(r'^[a-zA-Z0-9-]+$').hasMatch(part),
            );
  }

  static Future<bool> sendReport({
    required String log,
    required String report,
    String name = '',
    String email = '',
  }) async {
    if (!isValidReplyEmail(email)) return false;
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
              'email': email.trim(),
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
