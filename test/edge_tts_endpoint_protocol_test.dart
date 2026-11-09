import 'package:flutter_test/flutter_test.dart';
import 'package:sonarpad_mobile_starter/tts/edge_tts_protocol.dart';

List<int> audioFrame(List<int> payload) {
  const header = 'Path:audio\r\nX-RequestId:abc\r\n';
  final encoded = header.codeUnits;
  return [
    (encoded.length >> 8) & 255,
    encoded.length & 255,
    ...encoded,
    ...payload,
  ];
}

void main() {
  test('Edge 155 v1 remains available as compatible fallback', () {
    final uri = EdgeTtsProtocol.url(
      endpoint: EdgeTtsEndpoint.modern,
      connectionId: 'request123',
      signature: 'GEC123',
    );
    expect(uri.host, 'api.msedgeservices.com');
    expect(
      uri.queryParameters['Ocp-Apim-Subscription-Key'],
      EdgeTtsProtocol.clientToken,
    );
    expect(uri.queryParameters.containsKey('TrustedClientToken'), isFalse);
    expect(uri.queryParameters['Sec-MS-GEC-Version'], '1-155.0.4283.45');
    expect(uri.queryParameters['ConnectionId'], 'request123');
    expect(uri.queryParameters['Sec-MS-GEC'], 'GEC123');
  });

  test('Edge 157 v2 uses new service version and user agent', () {
    final uri = EdgeTtsProtocol.url(
      endpoint: EdgeTtsEndpoint.modernV2,
      connectionId: 'request157',
      signature: 'TEST-V2-SIGNATURE',
    );
    expect(uri.host, 'api.msedgeservices.com');
    expect(
      uri.queryParameters['Ocp-Apim-Subscription-Key'],
      EdgeTtsProtocol.clientToken,
    );
    expect(uri.queryParameters['Sec-MS-GEC-Version'], '2-157.0.4341.42');
    expect(uri.queryParameters['Sec-MS-GEC'], 'TEST-V2-SIGNATURE');
    expect(
      EdgeTtsProtocol.userAgent(EdgeTtsEndpoint.modernV2),
      contains('Edg/157.0.0.0'),
    );
    expect(EdgeTtsEndpoint.values.first, EdgeTtsEndpoint.modernV2);
    expect(EdgeTtsEndpoint.values[1], EdgeTtsEndpoint.modern);
    expect(EdgeTtsEndpoint.values.last, EdgeTtsEndpoint.legacy);
  });

  test('previous endpoint remains available as fallback', () {
    final uri = EdgeTtsProtocol.url(
      endpoint: EdgeTtsEndpoint.legacy,
      connectionId: 'fallback123',
      signature: 'GEC456',
    );
    expect(uri.host, 'speech.platform.bing.com');
    expect(
      uri.queryParameters['TrustedClientToken'],
      EdgeTtsProtocol.clientToken,
    );
    expect(
      uri.queryParameters.containsKey('Ocp-Apim-Subscription-Key'),
      isFalse,
    );
    expect(uri.queryParameters['Sec-MS-GEC-Version'], '1-132.0.2917.39');
  });

  test('partial audio is rejected if the socket closes before turn.end', () {
    final turn = EdgeTtsTurn();
    turn.acceptBinary(audioFrame(List<int>.filled(1800, 42)));
    expect(turn.audioBytes, 1800);
    expect(turn.ended, isFalse);
    expect(() => turn.completedAudio(), throwsStateError);
  });

  test('audio is accepted only with turn.end', () {
    final turn = EdgeTtsTurn();
    turn.acceptText('Path:turn.start\r\n');
    turn.acceptBinary(audioFrame(List<int>.filled(1800, 42)));
    turn.acceptText('X-RequestId:abc\r\nPath:turn.end\r\n');
    expect(turn.ended, isTrue);
    expect(turn.completedAudio(), hasLength(1800));
  });

  test('empty turn, non-audio frames and truncated frames are rejected', () {
    final turn = EdgeTtsTurn();
    turn.acceptBinary([0, 255, 1]);
    turn.acceptText('Path:turn.end\r\n');
    expect(() => turn.completedAudio(), throwsStateError);
  });
}
