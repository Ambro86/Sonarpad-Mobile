import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonarpad_mobile_starter/services/audio_description_fallbacks.dart';

void main() {
  for (final body in [
    '<!DOCTYPE HTML><html>Not Found</html>',
    '  <HTML>404</HTML>',
  ]) {
    test('HTML 404 retries only on Sonarpad API: $body', () {
      expect(
        AudioDescriptionFallbacks.classifyHttp(
          statusCode: 404,
          body: body,
          sonarpadApi: true,
        ),
        AdFailureKind.transient,
      );
      expect(
        AudioDescriptionFallbacks.classifyHttp(statusCode: 404, body: body),
        AdFailureKind.permanentClient,
      );
    });
  }
  for (final body in [
    '{"error":"file_not_found"}',
    '{"error":{"status":"NOT_FOUND","message":"model missing"}}',
    'Not Found',
  ]) {
    test('real missing resources retain their existing handling: $body', () {
      expect(
        AudioDescriptionFallbacks.classifyHttp(
          statusCode: 404,
          body: body,
          sonarpadApi: true,
        ),
        AdFailureKind.permanentClient,
      );
    });
  }
  test('normal responses and permission errors stay unchanged', () {
    for (final status in [200, 400, 401, 403, 429, 500, 503]) {
      expect(
        AudioDescriptionFallbacks.classifyHttp(
          statusCode: status,
          body: '<html>response</html>',
          sonarpadApi: true,
        ),
        AudioDescriptionFallbacks.classifyHttp(
          statusCode: status,
          body: '<html>response</html>',
        ),
      );
    }
  });
  test(
    'existing POST retry keeps cancellation, body and idempotency headers',
    () {
      final source = File(
        'lib/services/ai_audiodescription_service.dart',
      ).readAsStringSync();
      final start = source.indexOf(
        '  Future<http.Response> _postJsonWithRetry(',
      );
      final end = source.indexOf('  Future<', start + 20);
      final method = source.substring(start, end);
      expect(
        method,
        contains(
          "sonarpadApi: uri.toString().startsWith('\$_sonarpadAiBase/')",
        ),
      );
      expect(method, contains('_checkCancel();'));
      expect(
        method,
        contains('.post(uri, headers: headers, body: encodedBody)'),
      );
      expect(method, contains('failure == AdFailureKind.transient'));
      expect(
        method,
        contains(
          '_cancelableDelay(AudioDescriptionFallbacks.transientRetryDelaySeconds)',
        ),
      );
      expect(method, isNot(contains('Uuid')));
      expect(method, isNot(contains('idempotencyKey =')));
    },
  );
}
