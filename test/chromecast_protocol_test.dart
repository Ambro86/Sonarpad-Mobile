import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
// ignore: implementation_imports
import 'package:dart_cast/src/protocols/chromecast/castv2_channel.dart';
// ignore: implementation_imports
import 'package:dart_cast/src/protocols/chromecast/proto/cast_channel.dart';
import 'package:sonarpad_mobile_starter/services/chromecast_session.dart';

// Exercise real framing, request correlation, status parsing and LOAD/SEEK.
class ReceiverSocket extends Stream<Uint8List> implements Socket {
  final incoming = StreamController<Uint8List>();
  final requests = <Map<String, dynamic>>[];
  double position = 0;
  bool ignoreLoadPosition = true, ignoreSeek = false, silent = false;
  String state = 'PLAYING';
  String content = '';
  bool destroyed = false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
  @override
  StreamSubscription<Uint8List> listen(
    void Function(Uint8List)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => incoming.stream.listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );
  @override
  void add(List<int> bytes) {
    CastV2Channel.parseMessages(Stream.value(bytes)).listen((message) {
      final request = jsonDecode(message.payloadUtf8) as Map<String, dynamic>;
      requests.add(request);
      if (silent || !request.containsKey('requestId') || destroyed) return;
      Map<String, dynamic> reply;
      if (request['type'] == 'LAUNCH') {
        reply = {
          'type': 'RECEIVER_STATUS',
          'status': {
            'applications': [
              {'appId': 'CC1AD845', 'transportId': 'transport'},
            ],
          },
        };
      } else {
        if (request['type'] == 'LOAD') {
          content = request['media']['contentId'] as String;
          position = ignoreLoadPosition
              ? 0
              : (request['currentTime'] as num).toDouble();
          state = request['autoplay'] == true ? 'PLAYING' : 'PAUSED';
        }
        if (request['type'] == 'SEEK' && !ignoreSeek) {
          position = (request['currentTime'] as num).toDouble();
        }
        reply = {
          'type': 'MEDIA_STATUS',
          'status': [
            {
              'mediaSessionId': 7,
              'playerState': state,
              'currentTime': position,
              'media': {'contentId': content, 'duration': 216},
            },
          ],
        };
      }
      final response = CastMessage()
        ..protocolVersion = CastMessage_ProtocolVersion.CASTV2_1_0
        ..sourceId = message.destinationId
        ..destinationId = message.sourceId
        ..namespace_ = message.namespace_
        ..payloadType = CastMessage_PayloadType.STRING
        ..payloadUtf8 = jsonEncode({
          ...reply,
          'requestId': request['requestId'],
        });
      incoming.add(CastV2Channel.frameMessage(response));
    });
  }

  @override
  Future<void> flush() async {}
  @override
  void destroy() {
    destroyed = true;
    unawaited(incoming.close());
  }
}

void main() {
  const device = ChromecastDevice('id', 'Receiver', 'localhost', 8009);
  for (final ignore in [false, true]) {
    test('LOAD at 40 seconds: receiver ignores position=$ignore', () async {
      final receiver = ReceiverSocket()..ignoreLoadPosition = ignore;
      final session = ChromecastSession(socketFactory: (_) async => receiver);
      addTearDown(session.close);
      await session.connect(device);
      await session.load(
        url: 'https://example.org/song.mp3',
        mime: 'audio/mpeg',
        title: 'Song',
        position: const Duration(seconds: 40),
      );
      expect(session.status.playing, isTrue);
      expect(session.status.position, const Duration(seconds: 40));
      expect(session.positionRestoreFailed, isFalse);
      expect(
        receiver.requests.where((r) => r['type'] == 'SEEK').length,
        ignore ? 1 : 0,
      );
    });
  }
  test(
    'Ignored SEEK reports failure but playing media does not time out',
    () async {
      final receiver = ReceiverSocket()..ignoreSeek = true;
      final session = ChromecastSession(socketFactory: (_) async => receiver);
      addTearDown(session.close);
      await session.connect(device);
      await session.load(
        url: 'https://example.org/song.mp3',
        mime: 'audio/mpeg',
        title: 'Song',
        position: const Duration(seconds: 40),
      );
      expect(session.status.playing, isTrue);
      expect(session.positionRestoreFailed, isTrue);
    },
  );
  test('Closing cancels an unanswered request immediately', () async {
    final receiver = ReceiverSocket();
    final session = ChromecastSession(socketFactory: (_) async => receiver);
    await session.connect(device);
    receiver.silent = true;
    final pending = expectLater(session.refresh(), throwsStateError);
    await session.close();
    await pending;
    expect(receiver.destroyed, isTrue);
  });
}
