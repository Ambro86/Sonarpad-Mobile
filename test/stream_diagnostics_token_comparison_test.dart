import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sonarpad_mobile_starter/services/stream_diagnostics_service.dart';

const _signature =
    '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef';
const _rai5Host = 'raicinque1-push.cdn.netrw.it';
const _movieHost = 'raimovie1-push.cdn.netrw.it';

String _tokenQuery(DateTime now, {int validFor = 300}) {
  final epoch = now.millisecondsSinceEpoch ~/ 1000;
  return 'hdnea=st=${epoch - 1}~exp=${epoch + validFor}~acl=/*~hmac=$_signature';
}

Uri _playlist(String host, String name, String kind, String query) => Uri.parse(
    'https://$host/rai/hls/live/$name/$kind${name}_160/'
    'chunklist_ao.m3u8?$query');

Uri _segment(Uri playlist) => playlist.resolve('session01/media_ao_123.ts');

StreamDiagnosticTokenComparison _plan(
  Uri playlist, {
  String channel = 'Rai 5',
  bool videoEnabled = false,
  Uri? resolved,
  Uri? segment,
  Uri? sampledSegment,
  DateTime? now,
}) {
  final child = segment ?? _segment(playlist);
  return StreamDiagnosticTokenComparison.evaluate(
    channel: channel,
    videoEnabled: videoEnabled,
    selectedPlaylist: playlist,
    resolvedPlaylist: resolved ?? playlist,
    segment: child,
    sampledSegment: sampledSegment ?? child,
    now: now,
  );
}

List<Map<String, dynamic>> _events(List<String> lines) => lines
    .where((line) => line.startsWith('STREAM_DIAG '))
    .map((line) => jsonDecode(line.substring('STREAM_DIAG '.length))
        as Map<String, dynamic>)
    .toList();

// Test-only transport mapping: real local HTTP requests retain logical official
// URLs in the production policy. No DNS, CDN, TLS bypass or production allowlist
// changes are involved. Automatic redirects, if accidentally enabled for the
// comparison, would reach /redirect-target on this same local test server.
class _LocalOverrides extends HttpOverrides {
  _LocalOverrides(this.port, this.urls);
  final int port;
  final List<Uri> urls;

  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      _LocalClient(super.createHttpClient(context), port, urls);
}

class _LocalClient implements HttpClient {
  _LocalClient(this.client, this.port, this.urls);
  final HttpClient client;
  final int port;
  final List<Uri> urls;

  @override
  set connectionTimeout(Duration? value) => client.connectionTimeout = value;

  @override
  set userAgent(String? value) => client.userAgent = value;

  @override
  Future<HttpClientRequest> getUrl(Uri url) {
    urls.add(url);
    return client.getUrl(
        url.replace(scheme: 'http', host: '127.0.0.1', port: port));
  }

  @override
  void close({bool force = false}) => client.close(force: force);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ProbeResult {
  _ProbeResult(this.lines, this.urls, this.received);
  final List<String> lines;
  final List<Uri> urls;
  final List<Map<String, Object?>> received;

  List<Map<String, dynamic>> get events => _events(lines);
  Iterable<Map<String, dynamic>> named(String name) =>
      events.where((event) => event['event'] == name);
}

Future<_ProbeResult> _exercise({
  String channel = 'Rai 5',
  bool videoEnabled = false,
  String? segmentReference,
  int baselineStatus = 403,
  int tokenStatus = 206,
  String contentType = 'video/mp2t',
  int tokenBytes = 64,
  int sampleByte = 0x47,
  bool includeInit = false,
  bool hangComparison = false,
  bool cancelComparison = false,
  bool absoluteRedirect = false,
  int runs = 1,
}) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final lines = <String>[];
  final urls = <Uri>[];
  final received = <Map<String, Object?>>[];
  final query = _tokenQuery(DateTime.now());
  final movie = channel == 'Rai Movie';
  final name = movie ? 'raimovie' : 'rai5';
  final host = movie ? _movieHost : _rai5Host;
  final root = '/rai/hls/live/$name/';
  final sampleCounts = <String, int>{};
  late StreamDiagnosticsSession session;
  final subscription = server.listen((request) {
    final response = request.response;
    received.add({
      'path': request.uri.path,
      'query': request.uri.query,
      'range': request.headers.value(HttpHeaders.rangeHeader),
      'agent': request.headers.value(HttpHeaders.userAgentHeader),
      'authorization': request.headers.value(HttpHeaders.authorizationHeader),
      'cookie': request.headers.value(HttpHeaders.cookieHeader),
    });
    if (request.uri.path.endsWith('chunklist_ao.m3u8')) {
      response.headers.set(HttpHeaders.contentTypeHeader,
          'application/vnd.apple.mpegurl');
      response.write('#EXTM3U\n#EXT-X-TARGETDURATION:10\n'
          '#EXT-X-KEY:METHOD=AES-128,URI="private.key"\n');
      if (includeInit) {
        response.write('#EXT-X-MAP:URI="init.mp4"\n');
      }
      final reference = segmentReference ?? 'session01/media_ao_123.ts';
      response.write('#EXTINF:10,\n$reference\n');
    } else if (request.uri.path.endsWith('init.mp4')) {
      response.add([0, 0, 0, 0]);
    } else if (request.uri.path.endsWith('.ts')) {
      final count = (sampleCounts[request.uri.path] ?? 0) + 1;
      sampleCounts[request.uri.path] = count;
      final comparison = count == 2;
      if (comparison && cancelComparison) {
        session.close('test_cancel_comparison');
        return;
      }
      if (comparison && hangComparison) {
        return;
      }
      final status = comparison ? tokenStatus : baselineStatus;
      response.statusCode = status;
      if (status >= 300 && status < 400) {
        final destination = absoluteRedirect
            ? 'http://localhost:${server.port}'
            : '';
        response.headers.set(HttpHeaders.locationHeader,
            '$destination/redirect-target?$query');
      } else if (status == 200 || status == 206) {
        response.headers.set(HttpHeaders.contentTypeHeader, contentType);
        final size = comparison ? tokenBytes : 64;
        if (status == 206 && size > 0) {
          response.headers.set(HttpHeaders.contentRangeHeader,
              'bytes 0-${size - 1}/$size');
        }
        if (contentType == 'text/html') {
          response.write('<html>not a media sample</html>');
        } else {
          response.add(List<int>.filled(size, sampleByte));
        }
      }
    } else {
      // No diagnostic is permitted to retrieve the key or follow the token
      // comparison redirect. Keep these endpoints local to detect violations.
      response.statusCode = 404;
    }
    unawaited(response.close().then<void>((_) {},
        onError: (Object _, StackTrace _) {}));
  });
  session = StreamDiagnosticsSession(
    channel: channel,
    videoEnabled: videoEnabled,
    writeLog: lines.add,
    requestTimeout: const Duration(seconds: 4),
    probeTimeout: const Duration(seconds: 16),
  );
  try {
    await HttpOverrides.runWithHttpOverrides(() async {
      for (var run = 0; run < runs; run++) {
        // A different token on run 3 also verifies the run cap, not just URL
        // de-duplication. First two runs are the AD and ITA renditions.
        final runQuery = run < 2
            ? query
            : _tokenQuery(DateTime.now(), validFor: 600);
        final kind = run == 1 ? 'ita' : 'des';
        await session.probeFailure(
          url: _playlist(host, name, kind, runQuery).toString(),
          stage: '$root$kind',
          reason: 'test_stall',
          headers: {
            'User-Agent': 'TestPlayer/3.0',
            'Authorization': 'Bearer doNotSend',
            'Cookie': 'session=doNotSend',
          },
        );
      }
    }, _LocalOverrides(server.port, urls)).timeout(const Duration(seconds: 30));
    return _ProbeResult(lines, urls, received);
  } finally {
    session.close();
    await subscription.cancel();
    await server.close(force: true);
  }
}

void main() {
  final now = DateTime.utc(2030, 1, 1);
  final playlist = _playlist(_rai5Host, 'rai5', 'des', _tokenQuery(now));

  for (final channel in ['Rai 5', 'Rai Movie']) {
    for (final kind in ['des', 'ita']) {
      test('only scoped $channel $kind segment receives the exact raw query', () {
        final movie = channel == 'Rai Movie';
        final source = _playlist(movie ? _movieHost : _rai5Host,
            movie ? 'raimovie' : 'rai5', kind, _tokenQuery(now));
        final plan = _plan(source, channel: channel, now: now);
        expect(plan.reason, 'eligible');
        expect(plan.expiresInSeconds, 300);
        expect(plan.target?.query, source.query);
        expect(plan.target?.path,
            _segment(source).path);
        expect(plan.target?.host, source.host);
        expect(_segment(source).hasQuery, isFalse);
      });
    }
  }

  test('encoded token remains encoded without query-map normalization', () {
    final query = 'hdnea=${Uri.encodeQueryComponent(_tokenQuery(now).substring(6))}';
    final source = playlist.replace(query: query);
    final plan = _plan(source, now: now);
    expect(plan.reason, 'eligible');
    expect(plan.target!.query, source.query);
    expect(plan.target.toString(), '${_segment(source)}?${source.query}');
  });

  test('unrelated channels and video playback are excluded', () {
    expect(_plan(playlist, channel: 'Rai News 24', now: now).target, isNull);
    expect(_plan(playlist, videoEnabled: true, now: now).reason, 'video_mode');
  });

  for (final changed in [
    playlist.replace(scheme: 'http'),
    playlist.replace(host: 'evil.example'),
    playlist.replace(host: '$_rai5Host.evil.example'),
    playlist.replace(port: 444),
    playlist.replace(userInfo: 'user:password'),
    playlist.replace(fragment: 'signedFragment'),
    playlist.replace(path: '/other/chunklist_ao.m3u8'),
  ]) {
    test('unsafe playlist origin or path is excluded: ${changed.host} ${changed.path} ${changed.scheme} ${changed.port} ${changed.userInfo} ${changed.fragment}', () {
      expect(_plan(changed, now: now).target, isNull);
    });
  }

  for (final reference in [
    'https://other.example/media_ao_123.ts',
    'http://$_rai5Host/rai/hls/live/rai5/desrai5_160/session01/media_ao_123.ts',
    'session01/media_ao_123.ts?hdnea=alreadySigned',
    'session01/media_ao_123.ts?signature=alreadySigned',
    'session01/media_ao_123.ts?',
    'session01/media_ao_123.ts#fragment',
    'exp=123~hmac=signedPath/media_ao_123.ts',
    '../itarai5_160/session01/media_ao_123.ts',
    'private.key',
    'init.mp4',
  ]) {
    test('existing signatures and out-of-scope segment are never changed: $reference', () {
      final child = playlist.resolve(reference);
      final before = child.toString();
      expect(_plan(playlist, segment: child, now: now).target, isNull);
      expect(child.toString(), before);
    });
  }

  test('redirected playlist or baseline segment is not a valid A/B pair', () {
    expect(_plan(playlist, resolved: playlist.replace(query: '${playlist.query}&new=1'),
        now: now).reason, 'resource_redirected');
    expect(_plan(playlist, sampledSegment: playlist.resolve('session01/media_ao_124.ts'),
        now: now).reason, 'resource_redirected');
  });

  for (final query in [
    '',
    'hdnea=<redacted>',
    '${_tokenQuery(now)}&hdnea=other',
    '${_tokenQuery(now)}&tk2=anotherCredential',
    _tokenQuery(now, validFor: -1),
    _tokenQuery(now, validFor: 0),
    'hdnea=exp=1893456300~exp=1893456500~hmac=$_signature',
    'hdnea=exp=1893456300~hmac=%0a$_signature',
  ]) {
    test('ambiguous, invalid or expired token is excluded: $query', () {
      expect(_plan(playlist.replace(query: query), now: now).target, isNull);
    });
  }

  for (final channel in ['Rai 5', 'Rai Movie']) {
    test('$channel diagnostic compares 403 with token 206, without changing playback', () async {
      final result = await _exercise(channel: channel);
      final comparison = result.named('token_comparison_result').single;
      expect(comparison['baselineStatus'], 403);
      expect(comparison['tokenStatus'], 206);
      expect(comparison['tokenBytes'], 64);
      expect(comparison['playbackChanged'], isFalse);
      expect(comparison['outcome'],
          'token_sample_bytes_received_not_playback_confirmation');
      expect(result.received, hasLength(3));
      expect(result.urls[1].hasQuery, isFalse);
      expect(result.received[1]['query'], '');
      expect(result.received[2]['query'], result.received[0]['query']);
      expect(result.urls[2].query, result.urls[0].query);
      expect(result.urls[2].path, result.urls[1].path);
      expect(result.received[1]['range'], result.received[2]['range']);
      for (final request in result.received) {
        expect(request['agent'], 'TestPlayer/3.0');
        expect(request['authorization'], isNull);
        expect(request['cookie'], isNull);
        expect(request['path'].toString(), isNot(contains('.key')));
      }
      expect(result.lines.join('\n'), isNot(contains(_signature)));
      expect(result.lines.join('\n'), isNot(contains('doNotSend')));
      expect(result.named('probe_end').single['requests'], 3);
      expect(result.named('probe_end').single['outcome'],
          'segment_sample_unavailable');
    });
  }

  for (final status in [200, 206, 404, 500]) {
    test('baseline $status does not trigger token comparison', () async {
      final result = await _exercise(baselineStatus: status);
      expect(result.received, hasLength(2));
      expect(result.named('token_comparison_start'), isEmpty);
    });
  }

  test('two refusals do not claim that Rai or the player is broken', () async {
    final result = await _exercise(tokenStatus: 403);
    expect(result.named('token_comparison_result').single['outcome'],
        'both_requests_forbidden');
  });

  for (final absolute in [false, true]) {
    final kind = absolute ? 'cross-origin' : 'relative';
    test('token comparison cannot follow $kind redirects', () async {
      final result = await _exercise(tokenStatus: 302, absoluteRedirect: absolute);
      expect(result.received, hasLength(3));
      expect(result.received.any((request) => request['path'] == '/redirect-target'), isFalse);
      expect(result.named('http_probe_redirect_not_followed'), hasLength(1));
      expect(result.named('token_comparison_result').single['outcome'],
          'comparison_redirect_not_followed');
      expect(result.lines.join('\n'), isNot(contains(_signature)));
    });
  }

  test('HTML error pages are not considered successful media samples', () async {
    final result = await _exercise(tokenStatus: 200, contentType: 'text/html');
    expect(result.named('token_comparison_result').single['outcome'],
        'comparison_non_media_response');
  });

  for (final firstByte in [0x3c, 0x7b, 0x5b]) {
    test('encrypted bytes beginning with $firstByte are not assumed to be text', () async {
      final result = await _exercise(sampleByte: firstByte);
      expect(result.named('token_comparison_result').single['outcome'],
          'token_sample_bytes_received_not_playback_confirmation');
    });
  }

  test('empty response and HTTP failure are inconclusive comparison outcomes', () async {
    final empty = await _exercise(tokenBytes: 0);
    expect(empty.named('token_comparison_result').single['outcome'],
        'comparison_empty_body');
    final failure = await _exercise(tokenStatus: 500);
    expect(failure.named('token_comparison_result').single['outcome'],
        'comparison_http_error');
  });

  test('comparison respects the byte cap even when Range is ignored', () async {
    final result = await _exercise(tokenStatus: 200, tokenBytes: 48 * 1024);
    final body = result.named('http_probe_body').last;
    expect(body['bytes'], StreamDiagnosticsSession.maxSampleBytes);
    expect(body['capped'], isTrue);
    expect(body['rangeHonored'], isFalse);
  });

  test('init sample and comparison stay within four resources and never fetch keys', () async {
    final result = await _exercise(includeInit: true);
    expect(result.received, hasLength(4));
    expect(result.named('probe_end').single['requests'], 4);
    expect(result.named('token_comparison_result'), hasLength(1));
    expect(result.received.any((request) => request['path'].toString().endsWith('.key')), isFalse);
  });

  test('token comparisons preserve the two-run limit', () async {
    final result = await _exercise(runs: 3);
    expect(result.named('probe_start'), hasLength(2));
    expect(result.named('token_comparison_result'), hasLength(2));
    expect(result.received, hasLength(6));
  });

  test('Rai News, video mode and already-signed segments do not get augmented', () async {
    for (final result in [
      await _exercise(channel: 'Rai News 24'),
      await _exercise(videoEnabled: true),
      await _exercise(segmentReference: 'session01/media_ao_123.ts?signature=existing'),
      await _exercise(segmentReference: 'https://other.example/session01/media_ao_123.ts'),
    ]) {
      expect(result.received, hasLength(2));
      expect(result.named('token_comparison_start'), isEmpty);
      expect(result.named('token_comparison_skipped'), hasLength(1));
    }
  });

  test('comparison timeout is bounded and does not escape the diagnostic future', () async {
    final result = await _exercise(hangComparison: true);
    expect(result.named('http_probe_error').last['category'], 'timeout');
    expect(result.named('token_comparison_result').single['outcome'],
        'comparison_request_failed');
  });

  test('closing during comparison cancels sockets with no later diagnostic events', () async {
    final result = await _exercise(cancelComparison: true);
    expect(result.received, hasLength(3));
    expect(result.named('token_comparison_result'), isEmpty);
    expect(result.events.last['event'], 'session_end');
    expect(result.events.last['reason'], 'test_cancel_comparison');
  });
}
