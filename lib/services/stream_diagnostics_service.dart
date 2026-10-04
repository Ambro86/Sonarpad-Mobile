import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Read-only diagnostics. This never changes the player's URL, headers, codec,
/// timeouts or fallback policy. HTTP probes use a separate Dart HTTP client:
/// their success is NOT proof that the native player decoded or played audio.
class StreamDiagnosticsSession {
  StreamDiagnosticsSession({
    required this.channel,
    required this.videoEnabled,
    required void Function(String) writeLog,
    this.requestTimeout = const Duration(seconds: 4),
    this.probeTimeout = const Duration(seconds: 16),
  }) : _writeLog = writeLog {
    record('session_start', {
      'channel': channel,
      'videoEnabled': videoEnabled,
      'os': Platform.operatingSystem,
      'osVersion': Platform.operatingSystemVersion,
      'revision': 'stream-diag-v1',
      'probeTransport': 'dart_http_not_native_player',
      'probeCookies': 'separate_client_no_player_cookie_jar',
    });
  }

  static int _sequence = 0;
  static const maxProbeRuns = 2;
  static const maxPlaylistBytes = 128 * 1024;
  static const maxSampleBytes = 16 * 1024;
  static const maxRequestsPerProbe = 4;

  final String channel;
  final bool videoEnabled;
  final Duration requestTimeout;
  final Duration probeTimeout;
  final void Function(String) _writeLog;
  final String id =
      'STR-${DateTime.now().microsecondsSinceEpoch}-${++_sequence}';
  final Stopwatch _clock = Stopwatch()..start();
  final Set<HttpClient> _clients = <HttpClient>{};
  final Set<String> _probedUrls = <String>{};
  bool _closed = false;
  bool _probeRunning = false;
  int _probeRuns = 0;
  int _nativeMessages = 0;

  void record(String event, [Map<String, Object?> fields = const {}]) {
    if (_closed) return;
    try {
      final payload = <String, Object?>{
        'id': id,
        'elapsedMs': _clock.elapsedMilliseconds,
        'event': event,
        ...fields.map((key, value) => MapEntry(key, _safeValue(value))),
      };
      _writeLog('STREAM_DIAG ${jsonEncode(payload)}');
    } catch (_) {
      // A diagnostic/logging failure must never become a playback failure.
    }
  }

  void nativeMessage({
    required String stage,
    required String level,
    required String prefix,
    required String text,
  }) {
    if (_nativeMessages >= 40) return;
    _nativeMessages++;
    record('native_log', {
      'stage': stage,
      'level': level,
      'prefix': prefix,
      'text': text,
      'category': classifyError(text),
    });
    if (_nativeMessages == 40) record('native_log_limit');
  }

  /// At most two runs per user attempt, never concurrent. No requests are
  /// made for normal playback. Cancellation closes only diagnostic sockets.
  Future<void> probeFailure({
    required String url,
    required String stage,
    required String reason,
    required Map<String, String> headers,
  }) async {
    if (_closed ||
        _probeRunning ||
        _probeRuns >= maxProbeRuns ||
        _probedUrls.contains(url)) {
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri == null || !_isHttp(uri)) return;
    _probeRunning = true;
    _probedUrls.add(url);
    final run = ++_probeRuns;
    var expired = false;
    final budget = Timer(probeTimeout, () {
      expired = true;
      for (final client in _clients.toList()) {
        client.close(force: true);
      }
    });
    var requests = 0;
    var outcome = 'incomplete';
    record('probe_start', {
      'run': run,
      'stage': stage,
      'reason': reason,
      'url': safeUrl(url),
      'expiresInSeconds': tokenExpiresInSeconds(url),
      'transport': 'dart_http_not_native_player',
      'maxResources': maxRequestsPerProbe,
      'maxPlaylistBytes': maxPlaylistBytes,
      'maxSampleBytes': maxSampleBytes,
    });
    try {
      Future<_StreamProbeResponse?> fetch(Uri target, String resource,
          {bool sample = false, int offset = 0}) async {
        if (_closed || expired || requests >= maxRequestsPerProbe) return null;
        requests++;
        return _fetch(
          target,
          headers: headers,
          run: run,
          stage: stage,
          resource: resource,
          limit: sample ? maxSampleBytes : maxPlaylistBytes,
          sample: sample,
          offset: offset,
        );
      }

      var response = await fetch(uri, 'selected_playlist');
      if (response == null || !response.ok) {
        outcome = 'selected_playlist_unavailable';
        return;
      }
      var playlist = StreamDiagnosticPlaylist.parse(response.body);
      _recordPlaylist(playlist, run, 'selected_playlist');
      // For a master with no separate AUDIO rendition, inspect its lowest
      // bandwidth variant. This is probe-only, not the player's choice.
      if (playlist.segments.isEmpty && playlist.variants.isNotEmpty) {
        final variant = playlist.variants.first;
        record('probe_variant', {
          'run': run,
          'selection': 'lowest_bandwidth_probe_only',
          'bandwidth': variant.bandwidth,
        });
        final target = response.uri.resolve(variant.uri);
        response = await fetch(target, 'variant_playlist');
        if (response == null || !response.ok) {
          outcome = 'variant_playlist_unavailable';
          return;
        }
        playlist = StreamDiagnosticPlaylist.parse(response.body);
        _recordPlaylist(playlist, run, 'variant_playlist');
      }
      if (playlist.segments.isEmpty) {
        outcome = playlist.isHls ? 'playlist_has_no_segments' : 'not_hls';
        return;
      }
      final candidates = playlist.segments.where((item) => !item.isGap).toList();
      if (candidates.isEmpty) {
        outcome = 'playlist_only_gap_segments';
        return;
      }
      final segment = candidates.last;
      if (segment.byteRange != null && (segment.offset == null || segment.offset! < 0)) {
        outcome = 'segment_byte_range_offset_unknown';
        return;
      }
      // Encryption is logged by method only. Never request keys or licenses.
      record('probe_segment_selection', {
        'run': run,
        'selection': 'last_listed_complete_segment_probe_only',
        'encryption': segment.encryptionMethod,
        'hasInitMap': segment.initUri != null,
        'byteRange': segment.byteRange,
      });
      final initUri = segment.initUri;
      if (initUri != null) {
        await fetch(response.uri.resolve(initUri), 'initialization_sample',
            sample: true, offset: segment.initOffset ?? 0);
      }
      final sample = await fetch(
        response.uri.resolve(segment.uri),
        'segment_sample',
        sample: true,
        offset: segment.offset ?? 0,
      );
      outcome = sample != null && sample.ok && sample.body.isNotEmpty
          ? 'segment_bytes_received_not_decode_confirmation'
          : 'segment_sample_unavailable';
    } catch (error) {
      outcome = 'probe_exception';
      record('probe_error', {
        'run': run,
        'category': classifyError(error),
        'error': error.toString(),
      });
    } finally {
      budget.cancel();
      record('probe_end', {
        'run': run,
        'requests': requests,
        'outcome': expired ? 'probe_time_budget_reached' : outcome,
      });
      _probeRunning = false;
    }
  }

  void _recordPlaylist(
      StreamDiagnosticPlaylist playlist, int run, String resource) {
    record('playlist_summary', {
      'run': run,
      'resource': resource,
      'hls': playlist.isHls,
      'variants': playlist.variants.length,
      'audioRenditions': playlist.audioRenditions,
      'segments': playlist.segments.length,
      'mediaSequence': playlist.mediaSequence,
      'targetDuration': playlist.targetDuration,
      'endList': playlist.endList,
      'hasGap': playlist.hasGap,
    });
  }

  Future<_StreamProbeResponse?> _fetch(
    Uri uri, {
    required Map<String, String> headers,
    required int run,
    required String stage,
    required String resource,
    required int limit,
    required bool sample,
    required int offset,
  }) async {
    if (_closed || !_isHttp(uri)) return null;
    final clock = Stopwatch()..start();
    final client = HttpClient()..connectionTimeout = requestTimeout;
    _clients.add(client);
    HttpClientRequest? request;
    var phase = 'connect';
    int? status;
    var readBytes = 0;
    try {
      // Automatic redirects create a new request with the client's default
      // User-Agent before copying the original headers. Setting it only on
      // request.headers lets Dart's default replace the player's value.
      // Set the private client's default too, without changing the player.
      for (final entry in headers.entries) {
        if (entry.key.toLowerCase() == HttpHeaders.userAgentHeader) {
          client.userAgent = entry.value;
        }
      }
      record('http_probe_start', {
        'run': run,
        'stage': stage,
        'resource': resource,
        'url': safeUrl(uri.toString()),
        'range': sample ? 'bytes=$offset-${offset + limit - 1}' : 'none',
        'requestHeaderNames': headers.keys.toList(),
      });
      request = await client.getUrl(uri).timeout(requestTimeout);
      // Also consume a late abort error if the screen closes before close().
      unawaited(
        request.done.then<void>((_) {}, onError: (Object _, StackTrace _) {}),
      );
      if (_closed) return null;
      request.followRedirects = true;
      request.maxRedirects = 4;
      request.persistentConnection = false;
      // Do not send account credentials/cookies to a diagnostic endpoint.
      // TV playback currently uses User-Agent; preserve its exact value.
      for (final entry in headers.entries) {
        if (const {'user-agent', 'accept', 'referer', 'origin'}
            .contains(entry.key.toLowerCase())) {
          request.headers.set(entry.key, entry.value);
        }
      }
      if (sample) {
        request.headers.set(HttpHeaders.rangeHeader,
            'bytes=$offset-${offset + limit - 1}');
      }
      phase = 'headers';
      final response = await request.close().timeout(requestTimeout);
      status = response.statusCode;
      var effectiveUri = uri;
      final redirects = <Map<String, Object?>>[];
      for (final redirect in response.redirects) {
        effectiveUri = effectiveUri.resolveUri(redirect.location);
        redirects.add({
          'status': redirect.statusCode,
          'url': safeUrl(effectiveUri.toString()),
        });
      }
      record('http_probe_headers', {
        'run': run,
        'resource': resource,
        'status': status,
        'headersMs': clock.elapsedMilliseconds,
        'url': safeUrl(effectiveUri.toString()),
        'redirects': redirects,
        'headers': safeResponseHeaders(response.headers),
        'setCookieCount': response.headers['set-cookie']?.length ?? 0,
        'remoteFamily': response.connectionInfo?.remoteAddress.type.toString(),
      });
      if (status != HttpStatus.ok && status != HttpStatus.partialContent) {
        return _StreamProbeResponse(effectiveUri, status, Uint8List(0));
      }
      phase = 'body';
      final bytes = BytesBuilder(copy: false);
      var truncated = false;
      var firstBytes = true;
      await for (final chunk in response.timeout(requestTimeout)) {
        if (_closed) return null;
        if (firstBytes && chunk.isNotEmpty) {
          firstBytes = false;
          record('http_probe_first_bytes', {
            'run': run,
            'resource': resource,
            'firstBytesMs': clock.elapsedMilliseconds,
          });
        }
        final remaining = limit - bytes.length;
        if (chunk.length >= remaining) {
          bytes.add(chunk.sublist(0, remaining));
          truncated = true;
          readBytes = bytes.length;
          break;
        }
        bytes.add(chunk);
        readBytes = bytes.length;
      }
      final body = bytes.takeBytes();
      record('http_probe_body', {
        'run': run,
        'resource': resource,
        'status': status,
        'bytes': body.length,
        'elapsedMs': clock.elapsedMilliseconds,
        'capped': truncated,
        'rangeHonored': sample ? status == HttpStatus.partialContent : null,
        'contentKind': sample ? 'binary_sample_not_decoded' : _contentKind(body),
      });
      return _StreamProbeResponse(effectiveUri, status, body);
    } catch (error) {
      record('http_probe_error', {
        'run': run,
        'resource': resource,
        'phase': phase,
        'status': status,
        'bytes': readBytes,
        'elapsedMs': clock.elapsedMilliseconds,
        'type': error.runtimeType.toString(),
        'category': classifyError(error),
        'osError': error is SocketException ? error.osError?.errorCode : null,
        'error': error.toString(),
      });
      return null;
    } finally {
      // A Future timeout alone does not cancel I/O. Close our private client,
      // including active sockets, both on timeout and on a capped sample.
      try {
        request?.abort();
      } catch (_) {
        // Cleanup is best-effort and must never escape a diagnostic future.
      }
      client.close(force: true);
      _clients.remove(client);
    }
  }

  void close([String reason = 'screen_closed']) {
    if (_closed) return;
    record('session_end', {'reason': reason});
    _closed = true;
    for (final client in _clients.toList()) {
      client.close(force: true);
    }
    _clients.clear();
    _clock.stop();
  }

  static bool _isHttp(Uri uri) =>
      (uri.scheme == 'https' || uri.scheme == 'http') && uri.host.isNotEmpty;

  static String _contentKind(Uint8List bytes) {
    final text = utf8.decode(bytes, allowMalformed: true).trimLeft();
    if (text.startsWith('#EXTM3U')) return 'hls';
    if (text.startsWith('<')) return 'html_or_xml';
    if (text.startsWith('{') || text.startsWith('[')) return 'json';
    return text.isEmpty ? 'empty' : 'other';
  }

  static String classifyError(Object error) {
    if (error is TimeoutException) return 'timeout';
    if (error is TlsException) return 'tls';
    final text = error.toString().toLowerCase();
    if (text.contains('timed out') ||
        text.contains('timeout') ||
        (Platform.isIOS && text.contains('0xffffffc4'))) {
      return 'timeout';
    }
    if (text.contains('failed host lookup') ||
        text.contains('name or service not known') ||
        text.contains('nodename nor servname')) {
      return 'dns';
    }
    if (text.contains('certificate') ||
        text.contains('ssl') ||
        text.contains('handshake')) {
      return 'tls';
    }
    for (final code in [401, 403, 404, 410, 429, 500, 502, 503, 504]) {
      if (RegExp('(?:http(?: error)?|status(?:code)?|server returned)'
              r'\s*[:=]?\s*' '$code' r'\b').hasMatch(text)) {
        return 'http_$code';
      }
    }
    if (error is SocketException ||
        text.contains('tcp:') ||
        text.contains('connection reset')) {
      return 'socket';
    }
    return 'unknown';
  }

  static Map<String, String> safeResponseHeaders(HttpHeaders headers) {
    final result = <String, String>{};
    for (final key in const [
      'content-type', 'content-length', 'content-range', 'accept-ranges',
      'server', 'date', 'age', 'cache-control', 'x-cache', 'retry-after',
    ]) {
      final values = headers[key];
      if (values != null) result[key] = redact(values.join(', '));
    }
    return result;
  }

  static Map<String, String> safeHttpHeaders(Map<String, String> headers) =>
      Map.fromEntries(headers.entries.where((entry) => const {
        'content-type', 'content-length', 'server', 'date', 'age',
        'cache-control', 'x-cache', 'retry-after',
      }.contains(entry.key.toLowerCase())).map(
          (entry) => MapEntry(entry.key, redact(entry.value))));

  static String safeUrl(String value) {
    try {
      final uri = Uri.tryParse(value);
      if (uri == null) return '<invalid_url>';
      final path = uri.path.split('/').map((part) {
        final lower = part.toLowerCase();
        return part.length > 100 || lower.contains('hmac=') ||
                lower.contains('exp=') || lower.contains('token=') ||
                lower.contains('signature=')
            ? '<signed_path>'
            : part;
      }).join('/');
      final port = uri.hasPort ? ':${uri.port}' : '';
      final authority = uri.hasAuthority ? '${uri.scheme}://${uri.host}$port' : '';
      final safeQuery = uri.queryParameters.keys
          .map((key) => '$key=<redacted>').join('&');
      final query = uri.hasQuery ? '?$safeQuery' : '';
      return '$authority$path$query';
    } catch (_) {
      return '<invalid_url>';
    }
  }

  static int? tokenExpiresInSeconds(String value) {
    try {
      final decoded = Uri.decodeComponent(value);
      final match = RegExp(r'(?:[?~&/]exp=)(\d{9,12})').firstMatch(decoded);
      final seconds = int.tryParse(match?.group(1) ?? '');
      if (seconds == null) return null;
      return seconds - DateTime.now().millisecondsSinceEpoch ~/ 1000;
    } catch (_) {
      return null;
    }
  }

  static String redact(String text) {
    var value = text.replaceAllMapped(
      RegExp(r'''https?://[^\s"']+'''),
      (match) => safeUrl(match.group(0)!),
    );
    value = value.replaceAllMapped(
      RegExp(r'(authorization|set-cookie|cookie)\s*[:=]\s*[^\r\n]*',
          caseSensitive: false),
      (match) => '${match.group(1)}=<redacted>',
    );
    value = value.replaceAllMapped(
      RegExp(r'(hdnea|hdntl|tk2|token|hmac|signature|api_key|authorization|cookie)\s*[=:]\s*[^\s<>]+',
          caseSensitive: false),
      (match) => '${match.group(1)}=<redacted>',
    );
    return value.length > 1000 ? '${value.substring(0, 1000)}<truncated>' : value;
  }

  static Object? _safeValue(Object? value) {
    if (value is String) return redact(value);
    if (value is Map) {
      return value.map((key, val) => MapEntry(key.toString(), _safeValue(val)));
    }
    if (value is Iterable) return value.map(_safeValue).toList();
    return value;
  }
}

class _StreamProbeResponse {
  const _StreamProbeResponse(this.uri, this.status, this.body);
  final Uri uri;
  final int status;
  final Uint8List body;
  bool get ok => status == 200 || status == 206;
}

/// Minimal HLS inspection for diagnostics only. Not used to resolve playback.
class StreamDiagnosticPlaylist {
  bool isHls = false;
  bool endList = false;
  bool hasGap = false;
  int audioRenditions = 0;
  String? mediaSequence;
  String? targetDuration;
  final List<StreamDiagnosticVariant> variants = [];
  final List<StreamDiagnosticSegment> segments = [];

  static Map<String, String> attributes(String text) => {
    for (final match in RegExp(r'([A-Z0-9-]+)=(?:"([^"]*)"|([^,]*))')
        .allMatches(text))
      match.group(1)!: match.group(2) ?? match.group(3) ?? '',
  };

  static StreamDiagnosticPlaylist parse(Uint8List bytes) {
    final result = StreamDiagnosticPlaylist();
    final body = utf8.decode(bytes, allowMalformed: true).trimLeft();
    result.isHls = body.startsWith('#EXTM3U');
    if (!result.isHls) return result;
    int? bandwidth;
    var expectVariant = false;
    String? mapUri;
    int? mapOffset;
    String encryption = 'NONE';
    String? byteRange;
    int? previousEnd;
    String? previousUri;
    var isGap = false;
    for (final source in const LineSplitter().convert(body)) {
      final line = source.trim();
      if (line.isEmpty) continue;
      if (line.startsWith('#EXT-X-MEDIA:')) {
        final attrs = attributes(line);
        if (attrs['TYPE'] == 'AUDIO') result.audioRenditions++;
      } else if (line.startsWith('#EXT-X-STREAM-INF:')) {
        bandwidth = int.tryParse(attributes(line)['BANDWIDTH'] ?? '');
        expectVariant = true;
      } else if (line.startsWith('#EXT-X-MEDIA-SEQUENCE:')) {
        result.mediaSequence = line.split(':').last;
      } else if (line.startsWith('#EXT-X-TARGETDURATION:')) {
        result.targetDuration = line.split(':').last;
      } else if (line.startsWith('#EXT-X-KEY:')) {
        encryption = attributes(line)['METHOD'] ?? 'unknown';
      } else if (line.startsWith('#EXT-X-MAP:')) {
        final attrs = attributes(line);
        mapUri = attrs['URI'];
        final parts = (attrs['BYTERANGE'] ?? '').split('@');
        mapOffset = parts.length == 2 ? int.tryParse(parts[1]) : 0;
      } else if (line.startsWith('#EXT-X-BYTERANGE:')) {
        byteRange = line.split(':').last;
      } else if (line == '#EXT-X-ENDLIST') {
        result.endList = true;
      } else if (line == '#EXT-X-GAP') {
        result.hasGap = true;
        isGap = true;
      } else if (!line.startsWith('#')) {
        if (expectVariant) {
          result.variants.add(StreamDiagnosticVariant(line, bandwidth));
          expectVariant = false;
        } else {
          int? offset;
          if (byteRange != null) {
            final parts = byteRange.split('@');
            final length = int.tryParse(parts[0]);
            offset = parts.length == 2
                ? int.tryParse(parts[1])
                : (previousUri == line ? previousEnd : null);
            previousEnd = length != null && offset != null ? offset + length : null;
          } else {
            previousEnd = null;
          }
          previousUri = line;
          result.segments.add(StreamDiagnosticSegment(
            uri: line,
            initUri: mapUri,
            initOffset: mapOffset,
            encryptionMethod: encryption,
            byteRange: byteRange,
            offset: offset,
            isGap: isGap,
          ));
          byteRange = null;
          isGap = false;
        }
      }
    }
    result.variants.sort((a, b) =>
        (a.bandwidth ?? 0x7fffffff).compareTo(b.bandwidth ?? 0x7fffffff));
    return result;
  }
}

class StreamDiagnosticVariant {
  const StreamDiagnosticVariant(this.uri, this.bandwidth);
  final String uri;
  final int? bandwidth;
}

class StreamDiagnosticSegment {
  const StreamDiagnosticSegment({
    required this.uri,
    required this.encryptionMethod,
    this.initUri,
    this.initOffset,
    this.byteRange,
    this.offset,
    this.isGap = false,
  });
  final String uri;
  final String encryptionMethod;
  final String? initUri;
  final int? initOffset;
  final String? byteRange;
  final int? offset;
  final bool isGap;
}

enum StreamConnectionPhase { idle, opening, reconnecting, playing, failed }

/// UI state only: it deliberately cannot stop, open or replace any player.
class StreamPlaybackRecoveryState {
  StreamConnectionPhase phase = StreamConnectionPhase.idle;
  bool hasProgress = false;

  bool get isReconnecting => phase == StreamConnectionPhase.reconnecting;
  bool get canRetry => isReconnecting || phase == StreamConnectionPhase.failed;

  void begin({bool reconnecting = false}) {
    hasProgress = false;
    phase = reconnecting
        ? StreamConnectionPhase.reconnecting
        : StreamConnectionPhase.opening;
  }

  void reconnect() => phase = StreamConnectionPhase.reconnecting;

  void fail() => phase = StreamConnectionPhase.failed;

  void error({required bool automaticRecoveryPending}) {
    phase = automaticRecoveryPending
        ? StreamConnectionPhase.reconnecting
        : StreamConnectionPhase.failed;
  }

  bool observe({
    required Duration position,
    required bool playing,
    required bool buffering,
  }) {
    if (position <= Duration.zero || !playing || buffering) return false;
    hasProgress = true;
    final changed = phase != StreamConnectionPhase.playing;
    phase = StreamConnectionPhase.playing;
    return changed;
  }
}
