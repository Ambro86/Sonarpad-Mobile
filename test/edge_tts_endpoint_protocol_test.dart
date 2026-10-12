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
  test('modern endpoint uses subscription key and current version', () {
    final uri = EdgeTtsProtocol.url(
      endpoint: EdgeTtsEndpoint.modern,
      connectionId: 'request123',
      signature: 'GEC123',
    );
    expect(uri.host, 'api.msedgeservices.com');
    expect(uri.queryParameters['Ocp-Apim-Subscription-Key'],
        EdgeTtsProtocol.clientToken);
    expect(uri.queryParameters.containsKey('TrustedClientToken'), isFalse);
    expect(uri.queryParameters['Sec-MS-GEC-Version'], '1-155.0.4283.45');
    expect(uri.queryParameters['ConnectionId'], 'request123');
    expect(uri.queryParameters['Sec-MS-GEC'], 'GEC123');
  });

  test('previous endpoint remains available as fallback', () {
    final uri = EdgeTtsProtocol.url(
      endpoint: EdgeTtsEndpoint.legacy,
      connectionId: 'fallback123',
      signature: 'GEC456',
    );
    expect(uri.host, 'speech.platform.bing.com');
    expect(uri.queryParameters['TrustedClientToken'],
        EdgeTtsProtocol.clientToken);
    expect(uri.queryParameters.containsKey('Ocp-Apim-Subscription-Key'),
        isFalse);
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
