import 'dart:async';
import 'dart:convert';
import 'dart:io';

// Pinned protocol codec; transport lifetime is owned here so sockets are destroyed.
// ignore: implementation_imports
import 'package:dart_cast/src/protocols/chromecast/castv2_channel.dart';
// ignore: implementation_imports
import 'package:dart_cast/src/protocols/chromecast/proto/cast_channel.dart';

class ChromecastDevice {
  const ChromecastDevice(this.id, this.name, this.host, this.port);
  final String id, name, host;
  final int port;
}

class ChromecastStatus {
  const ChromecastStatus({
    this.state = 'IDLE',
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.volume = 1,
    this.sessionId,
    this.disconnected = false,
  });
  final String state;
  final Duration position, duration;
  final double volume;
  final int? sessionId;
  final bool disconnected;
  bool get playing => state == 'PLAYING';
}

/// Cast V2 media sender. Discovery is supplied by native Bonjour/Android NSD.
/// TLS Cast receivers use local certificates, not public web PKI certificates.
/// This transport does not attest Google device credentials.
class ChromecastSession {
  static const _receiver = 'urn:x-cast:com.google.cast.receiver';
  static const _media = 'urn:x-cast:com.google.cast.media';
  static const _connection = 'urn:x-cast:com.google.cast.tp.connection';
  static const _heartbeat = 'urn:x-cast:com.google.cast.tp.heartbeat';
  final _updates = StreamController<ChromecastStatus>.broadcast();
  final _pending = <int, Completer<Map<String, dynamic>>>{};
  SecureSocket? _socket;
  StreamSubscription<CastMessage>? _messages;
  Timer? _poll;
  bool _polling = false, _closed = false;
  int _sequence = 0;
  String? _transport;
  String? _expectedContentId;
  bool _mediaConfirmed = false;
  double _receiverVolume = 1;
  ChromecastStatus status = const ChromecastStatus();
  Stream<ChromecastStatus> get updates => _updates.stream;

  void _send(String namespace, String destination, Map<String, dynamic> data) {
    if (_socket == null || _closed) throw StateError('cast_disconnected');
    final message = CastMessage()
      ..protocolVersion = CastMessage_ProtocolVersion.CASTV2_1_0
      ..sourceId = 'sender-sonarpad'
      ..destinationId = destination
      ..namespace_ = namespace
      ..payloadType = CastMessage_PayloadType.STRING
      ..payloadUtf8 = jsonEncode(data);
    _socket!.add(CastV2Channel.frameMessage(message));
  }

  Future<Map<String, dynamic>> _request(
    String namespace,
    String destination,
    Map<String, dynamic> data,
  ) async {
    final id = ++_sequence;
    final completer = Completer<Map<String, dynamic>>();
    _pending[id] = completer;
    try {
      _send(namespace, destination, {...data, 'requestId': id});
      final reply = await completer.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw TimeoutException('cast_${data['type']}_timeout'),
      );
      if ([
        'INVALID_REQUEST',
        'LOAD_FAILED',
        'LAUNCH_ERROR',
      ].contains(reply['type'])) {
        throw StateError('cast_request_rejected');
      }
      return reply;
    } finally {
      _pending.remove(id);
    }
  }

  void _receive(CastMessage message) {
    if (message.payloadUtf8.isEmpty || _closed) return;
    try {
      final data = jsonDecode(message.payloadUtf8) as Map<String, dynamic>;
      if (message.namespace_ == _heartbeat && data['type'] == 'PING') {
        _send(_heartbeat, message.sourceId, {'type': 'PONG'});
      }
      if (data['type'] == 'RECEIVER_STATUS') {
        final receiverStatus = data['status'] as Map?;
        final volume = receiverStatus?['volume'] as Map?;
        if (volume?['level'] is num) {
          _receiverVolume = (volume!['level'] as num).toDouble();
          status = ChromecastStatus(
            state: status.state,
            position: status.position,
            duration: status.duration,
            sessionId: status.sessionId,
            disconnected: status.disconnected,
            volume: _receiverVolume,
          );
          _updates.add(status);
        }
      }
      if (data['type'] == 'MEDIA_STATUS') {
        final list = data['status'] as List? ?? [];
        if (list.isNotEmpty) {
          final value = list.first as Map;
          final info = value['media'] as Map?;
          final contentId = info?['contentId'];
          final belongsToLoad =
              _expectedContentId == null ||
              contentId == _expectedContentId ||
              (contentId == null &&
                  _mediaConfirmed &&
                  value['mediaSessionId'] == status.sessionId);
          if (belongsToLoad) {
            _mediaConfirmed = true;
            status = ChromecastStatus(
              state: value['playerState'] as String? ?? 'IDLE',
              position: Duration(
                milliseconds: ((value['currentTime'] as num? ?? 0) * 1000)
                    .round(),
              ),
              duration: info?['duration'] is num
                  ? Duration(
                      milliseconds: ((info!['duration'] as num) * 1000).round(),
                    )
                  : status.duration,
              volume: _receiverVolume,
              sessionId: value['mediaSessionId'] as int?,
            );
            _updates.add(status);
            if (value['idleReason'] == 'ERROR') {
              final pending = _pending[data['requestId']];
              if (pending != null && !pending.isCompleted) {
                pending.completeError(StateError('cast_media_failed'));
              }
            }
          }
        }
      }
      final pending = _pending[data['requestId']];
      if (pending != null && !pending.isCompleted) pending.complete(data);
    } catch (_) {
      _lost();
    }
  }

  void _lost() {
    if (_closed || status.disconnected) return;
    _poll?.cancel();
    status = ChromecastStatus(
      state: status.state,
      position: status.position,
      duration: status.duration,
      volume: status.volume,
      sessionId: status.sessionId,
      disconnected: true,
    );
    _updates.add(status);
    for (final pending in _pending.values) {
      if (!pending.isCompleted) {
        pending.completeError(StateError('cast_connection_lost'));
      }
    }
  }

  Future<void> connect(ChromecastDevice device) async {
    _socket = await SecureSocket.connect(
      device.host,
      device.port,
      onBadCertificate: (_) => true,
      timeout: const Duration(seconds: 8),
    );
    if (_closed) {
      _socket?.destroy();
      throw StateError('cast_cancelled');
    }
    _messages = CastV2Channel.parseMessages(
      _socket!,
    ).listen(_receive, onError: (Object _) => _lost(), onDone: _lost);
    _send(_connection, 'receiver-0', {'type': 'CONNECT'});
    final reply = await _request(_receiver, 'receiver-0', {
      'type': 'LAUNCH',
      'appId': 'CC1AD845',
    });
    final applications = reply['status']['applications'] as List;
    final app = applications.firstWhere((a) => a['appId'] == 'CC1AD845');
    _transport = app['transportId'] as String;
    _send(_connection, _transport!, {'type': 'CONNECT'});
    _poll = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (_polling || _closed) return;
      _polling = true;
      try {
        _send(_heartbeat, 'receiver-0', {'type': 'PING'});
        await refresh();
      } catch (_) {
        _lost();
      } finally {
        _polling = false;
      }
    });
  }

  Future<void> refresh() async {
    await _request(_media, _transport!, {'type': 'GET_STATUS'});
  }

  Future<void> load({
    required String url,
    required String mime,
    required String title,
    required Duration position,
    bool live = false,
    bool autoplay = true,
  }) async {
    _expectedContentId = url;
    _mediaConfirmed = false;
    status = const ChromecastStatus();
    await _request(_media, _transport!, {
      'type': 'LOAD',
      'autoplay': autoplay,
      'currentTime': live ? 0 : position.inMilliseconds / 1000,
      'media': {
        'contentId': url,
        'contentType': mime,
        'streamType': live ? 'LIVE' : 'BUFFERED',
        'metadata': {'metadataType': 0, 'title': title},
      },
    });
    final deadline = DateTime.now().add(const Duration(seconds: 30));
    do {
      await refresh();
      if (status.disconnected) throw StateError('cast_connection_lost');
      if (_mediaConfirmed &&
          status.sessionId != null &&
          (live || (status.position - position).inSeconds.abs() <= 5) &&
          status.state == (autoplay ? 'PLAYING' : 'PAUSED')) {
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 500));
    } while (!_closed && DateTime.now().isBefore(deadline));
    throw TimeoutException('cast_load_timeout');
  }

  Future<void> command(
    String type, [
    Map<String, dynamic> extra = const {},
  ]) async {
    if (status.disconnected || status.sessionId == null) {
      throw StateError('cast_disconnected');
    }
    await _request(_media, _transport!, {
      'type': type,
      'mediaSessionId': status.sessionId,
      ...extra,
    });
  }

  Future<void> seek(Duration target) async {
    final paused = !status.playing;
    final seconds =
        target.inMilliseconds.clamp(
          0,
          status.duration > Duration.zero
              ? status.duration.inMilliseconds
              : 1 << 52,
        ) /
        1000;
    await command('SEEK', {
      'currentTime': seconds,
      'resumeState': paused ? 'PLAYBACK_PAUSE' : 'PLAYBACK_START',
    });
    if (paused) await command('PAUSE');
  }

  Future<void> setVolume(double volume) async {
    await _request(_receiver, 'receiver-0', {
      'type': 'SET_VOLUME',
      'volume': {'level': volume.clamp(0.0, 1.0)},
    });
    await refresh();
  }

  Future<void> close({bool stop = true}) async {
    if (_closed) return;
    _poll?.cancel();
    if (stop && status.sessionId != null && !status.disconnected) {
      try {
        await command('STOP');
      } catch (_) {
        /* Receiver may be offline. */
      }
    }
    _closed = true;
    _socket?.destroy();
    await _messages?.cancel();
    for (final pending in _pending.values) {
      if (!pending.isCompleted) {
        pending.completeError(StateError('cast_closed'));
      }
    }
    await _updates.close();
  }
}
