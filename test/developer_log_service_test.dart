import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sonarpad_mobile_starter/services/developer_log_service.dart';

void main() {
  test('Email is optional and invalid addresses are rejected', () {
    for (final value in ['', '  ', ' persona@example.com ', 'a+b@example.it']) {
      expect(DeveloperLogService.isValidReplyEmail(value), isTrue);
    }
    for (final value in [
      'abc',
      'a@@example.com',
      'a@',
      'a b@example.com',
      'a@example..com',
      'a@example.com\r\nBcc: x@y.it',
    ]) {
      expect(DeveloperLogService.isValidReplyEmail(value), isFalse);
    }
  });
  test('Report sends trimmed optional email and preserves log', () async {
    for (final email in ['', ' persona@example.com ']) {
      final result = await http.runWithClient(
        () => DeveloperLogService.sendReport(
          log: 'diagnostic log',
          report: ' report ',
          name: ' name ',
          email: email,
        ),
        () => MockClient((request) async {
          expect(jsonDecode(request.body), {
            'name': 'name',
            'email': email.trim(),
            'report': 'report',
            'log': 'diagnostic log',
          });
          return http.Response('{"ok":true}', 200);
        }),
      );
      expect(result, isTrue);
    }
  });
  test('Invalid email never sends a request', () async {
    final result = await http.runWithClient(
      () => DeveloperLogService.sendReport(
        log: 'log',
        report: 'report',
        email: 'invalid',
      ),
      () => MockClient((_) async => throw StateError('Must not send')),
    );
    expect(result, isFalse);
  });
}
