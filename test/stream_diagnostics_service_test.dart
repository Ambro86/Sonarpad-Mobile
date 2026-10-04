import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sonarpad_mobile_starter/services/stream_diagnostics_service.dart';

Uint8List _bytes(String text) => Uint8List.fromList(utf8.encode(text));

List<Map<String, dynamic>> _events(List<String> log) => log
    .where((line) => line.startsWith('STREAM_DIAG '))
    .map((line) => jsonDecode(line.substring('STREAM_DIAG '.length))
        as Map<String, dynamic>)
    .toList();

void _closeResponse(HttpResponse response) {
  unawaited(
    response.close().then<void>((_) {}, onError: (Object _, StackTrace _) {}),
  );
}

void main() {
  test('open/playing flags at zero do not clear reconnecting or failure', () {
    final state = StreamPlaybackRecoveryState()..begin();
    expect(state.phase, StreamConnectionPhase.opening);
    state.error(automaticRecoveryPending: true);
    expect(state.canRetry, isTrue);
    expect(state.isReconnecting, isTrue);
    expect(state.observe(position: Duration.zero, playing: true, buffering: false), isFalse);
    expect(state.isReconnecting, isTrue);
    expect(state.observe(position: const Duration(seconds: 1), playing: true, buffering: true), isFalse);
    state.fail();
    expect(state.phase, StreamConnectionPhase.failed);
    expect(state.observe(position: const Duration(seconds: 2), playing: true, buffering: false), isTrue);
    expect(state.hasProgress, isTrue);
    expect(state.canRetry, isFalse);
    state.begin(reconnecting: true);
    expect(state.hasProgress, isFalse);
    expect(state.isReconnecting, isTrue);
  });

  test('no automatic fallback pending means retry, not endless reconnecting', () {
    final state = StreamPlaybackRecoveryState()..begin();
    state.error(automaticRecoveryPending: false);
    expect(state.phase, StreamConnectionPhase.failed);
    expect(state.isReconnecting, isFalse);
    expect(state.canRetry, isTrue);
  });

  test('query credentials, URL user-info and signed path are redacted', () {
    const url = 'https://user:password@cdn.example/live/exp=1791164764~hmac=pathSecret/chunk.m3u8?tk2=querySecret&hdnea=anotherSecret';
    final clean = StreamDiagnosticsSession.safeUrl(url);
    expect(clean, contains('cdn.example'));
    expect(clean, contains('chunk.m3u8'));
    for (final secret in ['user:password', 'pathSecret', 'querySecret', 'anotherSecret']) {
      expect(clean, isNot(contains(secret)));
    }
    final line = StreamDiagnosticsSession.redact('Failed to open $url.');
    expect(line, isNot(contains('querySecret')));
    expect(line, isNot(contains('pathSecret')));
    expect(StreamDiagnosticsSession.redact('Authorization: Bearer secretValue'),
        isNot(contains('secretValue')));
    expect(StreamDiagnosticsSession.redact('Cookie: access=secretCookie'),
        isNot(contains('secretCookie')));
  });

  test('classifies errors, not arbitrary numbers in a URL', () {
    expect(StreamDiagnosticsSession.classifyError(TimeoutException('test')), 'timeout');
    expect(StreamDiagnosticsSession.classifyError(const HandshakeException('test')), 'tls');
    expect(StreamDiagnosticsSession.classifyError('Failed host lookup: test.invalid'), 'dns');
    expect(StreamDiagnosticsSession.classifyError('HTTP error 403 Forbidden'), 'http_403');
    expect(StreamDiagnosticsSession.classifyError('Failed https://test.example/403.m3u8'), 'unknown');
  });

  test('HLS master parses audio and sorted diagnostic variants', () {
    final manifest = StreamDiagnosticPlaylist.parse(_bytes('''#EXTM3U
#EXT-X-MEDIA:TYPE=AUDIO,LANGUAGE="des",URI="ad.m3u8"
#EXT-X-MEDIA:TYPE=AUDIO,LANGUAGE="ita",URI="ita.m3u8"
#EXT-X-STREAM-INF:BANDWIDTH=3000000,CODECS="avc1.64001e,mp4a.40.2"
high.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=500000
low.m3u8
'''));
    expect(manifest.isHls, isTrue);
    expect(manifest.audioRenditions, 2);
    expect(manifest.variants.first.uri, 'low.m3u8');
    expect(manifest.segments, isEmpty);
  });

  test('HLS init map, sequence, encryption and implicit byte ranges', () {
    final manifest = StreamDiagnosticPlaylist.parse(_bytes('''#EXTM3U
#EXT-X-TARGETDURATION:10
#EXT-X-MEDIA-SEQUENCE:42
#EXT-X-KEY:METHOD=AES-128,URI="never-fetch.key"
#EXT-X-MAP:URI="init.mp4",BYTERANGE="80@12"
#EXTINF:10,
#EXT-X-BYTERANGE:100@400
combined.mp4
#EXTINF:10,
#EXT-X-BYTERANGE:100
combined.mp4
#EXT-X-ENDLIST
'''));
    expect(manifest.mediaSequence, '42');
    expect(manifest.targetDuration, '10');
    expect(manifest.endList, isTrue);
    expect(manifest.segments.last.offset, 500);
    expect(manifest.segments.last.initOffset, 12);
    expect(manifest.segments.last.encryptionMethod, 'AES-128');
    expect(manifest.segments.last.initUri, 'init.mp4');
  });

  test('logging exceptions and closed sessions cannot escape into the player', () async {
    final broken = StreamDiagnosticsSession(channel: 'test', videoEnabled: false,
        writeLog: (_) => throw StateError('broken logger'));
    broken.record('test');
    broken.close();
    final lines = <String>[];
    final session = StreamDiagnosticsSession(channel: 'test', videoEnabled: false,
        writeLog: lines.add);
    session.close();
    final count = lines.length;
    session.record('ignored');
    await session.probeFailure(url: 'http://127.0.0.1:1/test.m3u8', stage: 'ad',
        reason: 'test', headers: {});
    expect(lines.length, count);
  });

  test('HTTP probe follows redirects, samples bytes and never fetches keys', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final lines = <String>[];
    final requests = <String>[];
    final ranges = <String?>[];
    final userAgents = <String?>[];
    final authorization = <String?>[];
    final subscription = server.listen((request) {
      requests.add(request.uri.path);
      ranges.add(request.headers.value(HttpHeaders.rangeHeader));
      userAgents.add(request.headers.value(HttpHeaders.userAgentHeader));
      authorization.add(request.headers.value(HttpHeaders.authorizationHeader));
      final response = request.response;
      if (request.uri.path == '/start') {
        response.statusCode = 302;
        response.headers.set('Location', '/live/master.m3u8?tk2=redirectSecret');
      } else if (request.uri.path == '/live/master.m3u8') {
        response.headers.contentType = ContentType('application', 'vnd.apple.mpegurl');
        response.write('#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=10\nlow.m3u8\n');
      } else if (request.uri.path == '/live/low.m3u8') {
        response.write('#EXTM3U\n#EXT-X-KEY:METHOD=AES-128,URI="keySecret.key"\n'
            '#EXT-X-MAP:URI="init.mp4"\n#EXTINF:10,\nsegment.ts\n');
      } else {
        // Deliberately ignore Range to check the client-side hard cap.
        response.add(List<int>.filled(48 * 1024, 0x47));
      }
      _closeResponse(response);
    });
    final session = StreamDiagnosticsSession(channel: 'test', videoEnabled: false,
        writeLog: lines.add);
    try {
      await session.probeFailure(url: 'http://127.0.0.1:${server.port}/start?tk2=inputSecret',
          stage: 'ad', reason: 'test', headers: {
            'User-Agent': 'TestPlayer/1.0', 'Authorization': 'Bearer privateCredential',
          });
      expect(requests, ['/start', '/live/master.m3u8', '/live/low.m3u8', '/live/init.mp4', '/live/segment.ts']);
      expect(requests.any((path) => path.contains('.key')), isFalse);
      expect(userAgents.every((value) => value == 'TestPlayer/1.0'), isTrue);
      expect(authorization.every((value) => value == null), isTrue);
      expect(ranges.last, 'bytes=0-16383');
      final events = _events(lines);
      final samples = events.where((event) => event['event'] == 'http_probe_body' &&
          event['resource'] == 'segment_sample');
      expect(samples.single['bytes'], StreamDiagnosticsSession.maxSampleBytes);
      expect(samples.single['capped'], isTrue);
      expect(samples.single['rangeHonored'], isFalse);
      expect(events.last['outcome'], 'segment_bytes_received_not_decode_confirmation');
      for (final secret in ['inputSecret', 'redirectSecret', 'privateCredential', 'keySecret']) {
        expect(lines.join('\n'), isNot(contains(secret)));
      }
    } finally {
      session.close();
      await subscription.cancel();
      await server.close(force: true);
    }
  });

  test('HTTP status is recorded and probes stop after two runs per attempt', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    var hits = 0;
    final subscription = server.listen((request) {
      hits++;
      request.response.statusCode = 403;
      _closeResponse(request.response);
    });
    final lines = <String>[];
    final session = StreamDiagnosticsSession(channel: 'test', videoEnabled: false,
        writeLog: lines.add);
    try {
      for (var i = 0; i < 3; i++) {
        await session.probeFailure(url: 'http://127.0.0.1:${server.port}/$i.m3u8',
            stage: 'test', reason: 'test', headers: {});
      }
      expect(hits, 2);
      final headers = _events(lines).where((event) => event['event'] == 'http_probe_headers');
      expect(headers.every((event) => event['status'] == 403), isTrue);
    } finally {
      session.close();
      await subscription.cancel();
      await server.close(force: true);
    }
  });

  test('HTTP timeout is bounded and recorded without throwing', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final subscription = server.listen((request) { /* Deliberately no headers. */ });
    final lines = <String>[];
    final session = StreamDiagnosticsSession(channel: 'test', videoEnabled: false,
        writeLog: lines.add, requestTimeout: const Duration(milliseconds: 200),
        probeTimeout: const Duration(seconds: 1));
    try {
      await session.probeFailure(url: 'http://127.0.0.1:${server.port}/hang',
          stage: 'test', reason: 'test', headers: {}).timeout(const Duration(seconds: 3));
      final errors = _events(lines).where((event) => event['event'] == 'http_probe_error');
      expect(errors.any((event) => event['category'] == 'timeout'), isTrue);
    } finally {
      session.close();
      await subscription.cancel();
      await server.close(force: true);
    }
  });

  test('screen exit cancels private probe sockets and further requests', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final received = Completer<void>();
    var hits = 0;
    final subscription = server.listen((request) {
      hits++;
      if (!received.isCompleted) received.complete();
    });
    final lines = <String>[];
    final session = StreamDiagnosticsSession(channel: 'test', videoEnabled: false,
        writeLog: lines.add, requestTimeout: const Duration(seconds: 1));
    try {
      final pending = session.probeFailure(url: 'http://127.0.0.1:${server.port}/hang',
          stage: 'test', reason: 'test', headers: {});
      await received.future.timeout(const Duration(seconds: 2));
      session.close('test_exit');
      await pending.timeout(const Duration(seconds: 2));
      expect(hits, 1);
      expect(_events(lines).last['event'], 'session_end');
    } finally {
      session.close();
      await subscription.cancel();
      await server.close(force: true);
    }
  });
}
