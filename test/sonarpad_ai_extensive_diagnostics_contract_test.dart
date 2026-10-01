import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final service = File(
    'lib/services/ai_audiodescription_service.dart',
  ).readAsStringSync();
  final screen = File(
    'lib/screens/create_ai_audiodescription_screen.dart',
  ).readAsStringSync();
  final logger = File('lib/utils/app_logger.dart').readAsStringSync();

  test('paid Sonarpad AI has extensive diagnostics', () {
    expect(service, contains('SONARPAD_AI_DIAG'));
    expect(service, contains('_sonarpadCodeDiagnostics'));
    expect(service, contains('_secretFingerprint'));
    expect(service, contains('deviceIdFingerprint'));
    expect(service, contains('UPLOAD_START_PARSED'));
    expect(service, contains('DIRECT_UPLOAD_PARSED'));
    expect(service, contains('UPLOAD_COMPLETE_PARSED'));
    expect(service, contains('GENERATE_PARSED'));
    expect(service, contains('CLEANUP_RESPONSE'));
    expect(service, contains('classification=\${failure.name}'));
  });

  test('diagnostics redact paid AI secrets', () {
    expect(service, contains("lower == 'code'"));
    expect(service, contains("lower.contains('token')"));
    expect(service, contains("lower == 'authorization'"));
    expect(service, contains("lower == 'upload_url'"));
    expect(service, contains('<redacted'));
    expect(service, isNot(contains("'code=\$trimmed'")));
  });

  test('paid AI UI logs activation, balance and creation path', () {
    expect(screen, contains('SONARPAD_AI_DIAG UI activate pressed'));
    expect(screen, contains('SONARPAD_AI_DIAG UI balance refresh start'));
    expect(screen, contains('SONARPAD_AI_DIAG UI create preflight'));
    expect(screen, contains('SONARPAD_AI_DIAG UI provider changed'));
  });

  test('debug log retains enough history for verbose paid AI diagnostics', () {
    expect(logger, contains('_maxLogBytes = 8 * 1024 * 1024'));
    expect(logger, contains('if (size > _maxLogBytes)'));
  });
}
