import 'dart:convert';
import 'package:archive/archive.dart';
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
          final payload = jsonDecode(request.body) as Map<String, dynamic>;
          final zip = ZipDecoder().decodeBytes(
            base64Decode(payload.remove('diagnostics_zip_base64') as String),
          );
          expect(zip.files.single.name, 'sonarpad-log.txt');
          expect(
            utf8.decode(zip.files.single.content as List<int>),
            'diagnostic log',
          );
          expect(payload.remove('platform'), startsWith('Sonarpad Mobile'));
          expect(payload, {
            'name': 'name',
            'email': email.trim(),
            'report': 'report',
          });
          return http.Response('{"ok":true,"attachment_received":true}', 200);
        }),
      );
      expect(result, isTrue);
    }
  });
  test(
    'Success requires ZIP receipt, not only an old endpoint acknowledgement',
    () async {
      final result = await http.runWithClient(
        () => DeveloperLogService.sendReport(
          log: 'Accenti: è più 漢字',
          report: 'report',
        ),
        () => MockClient((request) async {
          final payload = jsonDecode(request.body) as Map;
          final zip = ZipDecoder().decodeBytes(
            base64Decode(payload['diagnostics_zip_base64'] as String),
          );
          expect(
            utf8.decode(zip.files.single.content as List<int>),
            'Accenti: è più 漢字',
          );
          return http.Response('{"ok":true}', 200);
        }),
      );
      expect(result, isFalse);
    },
  );
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
