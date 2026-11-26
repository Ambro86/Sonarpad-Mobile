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
  Duration seekDelay = Duration.zero;
  bool ignoreLoadPosition = true, ignoreSeek = false, silent = false;
  String state = 'PLAYING';
  String? idleReason;
  String content = '';
  bool destroyed = false;
  @override
  InternetAddress get address => InternetAddress.loopbackIPv4;
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
          final target = (request['currentTime'] as num).toDouble();
          if (seekDelay == Duration.zero) {
            position = target;
          } else {
            Timer(seekDelay, () => position = target);
          }
        }
        reply = {
          'type': 'MEDIA_STATUS',
          'status': [
            {
              'mediaSessionId': 7,
              'playerState': state,
              'idleReason': idleReason,
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
  test('local document LOAD streams the selected file and stops serving on close', () async {
    final dir = await Directory.systemTemp.createTemp('cast_test');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/caffè test.mp3');
    await file.writeAsBytes([10, 20, 30, 40]);
    final receiver = ReceiverSocket();
    final session = ChromecastSession(socketFactory: (_) async => receiver);
    addTearDown(session.close);
    await session.connect(device);
    await session.load(url: file.uri.toString(), mime: 'audio/mpeg', title: 'Local',
        position: Duration.zero);
    final url = Uri.parse(receiver.content);
    expect(url.scheme, 'http');
    final client = HttpClient()..findProxy = (_) => 'DIRECT';
    addTearDown(() => client.close(force: true));
    final head = await (await client.openUrl('HEAD', url)).close();
    expect(head.contentLength, 4);
    expect(head.headers.contentType?.mimeType, 'audio/mpeg');
    await head.drain<void>();
    for (final (range, status, bytes) in [
      (null, 200, [10, 20, 30, 40]),
      ('bytes=1-2', 206, [20, 30]),
      ('bytes=-1', 206, [40]),
      ('bytes=2-', 206, [30, 40]),
      ('bytes=9-', 416, <int>[]),
    ]) {
      final request = await client.getUrl(url);
      if (range != null) request.headers.set('Range', range);
      final response = await request.close();
      expect(response.statusCode, status);
      expect(await response.expand((b) => b).toList(), bytes);
    }
    final other = await (await client.getUrl(url.replace(path: '/other'))).close();
    expect(other.statusCode, 404);
    await other.drain<void>();
    await session.close();
    await expectLater((() async => (await client.getUrl(url)).close())(),
        throwsA(isA<IOException>()));
  });
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
  test('SEEK acknowledgement can precede the actual receiver position', () async {
    final receiver = ReceiverSocket()
      ..seekDelay = const Duration(milliseconds: 550);
    final session = ChromecastSession(socketFactory: (_) async => receiver);
    addTearDown(session.close);
    await session.connect(device);
    await session.load(
      url: 'https://example.org/song.mp3',
      mime: 'audio/mpeg',
      title: 'Song',
      position: const Duration(seconds: 35),
    );
    expect(session.status.playing, isTrue);
    expect(session.status.position, const Duration(seconds: 35));
    expect(session.positionRestoreFailed, isFalse);
  });
  test('Paused-at-end completion excludes ordinary pause, loading and disconnect', () {
    ChromecastStatus status({String state = 'PAUSED', int position = 132591,
        int duration = 132632, bool disconnected = false, String? reason}) =>
        ChromecastStatus(state: state, sessionId: 1, idleReason: reason,
          position: Duration(milliseconds: position),
          duration: Duration(milliseconds: duration), disconnected: disconnected);
    expect(status().completed, isTrue);
    expect(status(position: 132632).completed, isTrue);
    expect(status(position: 120000).completed, isFalse);
    expect(status(position: 132000).completed, isFalse);
    expect(status(duration: 0).completed, isFalse);
    expect(status(position: 0, duration: 0).completed, isFalse);
    expect(status(state: 'PLAYING').completed, isFalse);
    expect(status(state: 'BUFFERING').completed, isFalse);
    expect(status(disconnected: true).completed, isFalse);
    expect(status(reason: 'ERROR').completed, isFalse);
  });
  test('Only IDLE FINISHED status marks natural idle completion', () async {
    final receiver = ReceiverSocket();
    final session = ChromecastSession(socketFactory: (_) async => receiver);
    addTearDown(session.close);
    await session.connect(device);
    await session.load(url: 'https://example.org/song.mp3', mime: 'audio/mpeg',
      title: 'Song', position: Duration.zero);
    for (final reason in ['CANCELLED', 'ERROR', 'INTERRUPTED', 'FINISHED']) {
      receiver.state = 'IDLE';
      receiver.idleReason = reason;
      if (reason == 'ERROR') {
        await expectLater(session.refresh(), throwsStateError);
      } else {
        await session.refresh();
      }
      expect(session.status.completed, reason == 'FINISHED');
    }
  });
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
