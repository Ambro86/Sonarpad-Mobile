import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final service = File(
    'lib/services/ai_audiodescription_service.dart',
  ).readAsStringSync();

  test('streamed direct upload starts HTTP send before feeding request body', () {
    final methodStart = service.indexOf('Future<http.Response> _streamFileUpload(');
    expect(methodStart, greaterThanOrEqualTo(0));
    final methodEnd = service.indexOf('String _extractCandidateText', methodStart);
    expect(methodEnd, greaterThan(methodStart));
    final method = service.substring(methodStart, methodEnd);

    final sendIndex = method.indexOf('.send(request)');
    final bodyIndex = method.indexOf('request.sink.addStream(bodyStream)');
    expect(sendIndex, greaterThanOrEqualTo(0));
    expect(bodyIndex, greaterThan(sendIndex));
    expect(method, contains('SEND_STARTED'));
    expect(method, contains('BODY_PROGRESS'));
    expect(method, contains('BODY_STREAMED'));
    expect(method, contains('unawaited(request.sink.close())'));
    expect(method, isNot(contains('await request.sink.close()')));
  });

  test('direct upload cancellation is raced and translated to app cancellation', () {
    final methodStart = service.indexOf('Future<http.Response> _streamFileUpload(');
    final methodEnd = service.indexOf('String _extractCandidateText', methodStart);
    final method = service.substring(methodStart, methodEnd);

    expect(method, contains('_cancelSignal.future.then<http.StreamedResponse>'));
    expect(method, contains('_cancelSignal.future.then<http.Response>'));
    expect(method, contains('CANCELLED_BY_CLIENT_CLOSE'));
    expect(method, contains("throw const _AudioDescriptionCancelled()"));
  });
}
