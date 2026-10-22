import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../utils/app_logger.dart';

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
    this.playbackRate = 1,
    this.supportedMediaCommands = 0,
    this.sessionId,
    this.disconnected = false,
  });
  final String state;
  final Duration position, duration;
  final double volume, playbackRate;
  final int supportedMediaCommands;
  bool get supportsPlaybackRate => supportedMediaCommands & (1 << 13) != 0;
  final int? sessionId;
  final bool disconnected;
  bool get playing => state == 'PLAYING';
}

/// Cast V2 media sender. Discovery is supplied by native Bonjour/Android NSD.
/// TLS Cast receivers use local certificates, not public web PKI certificates.
/// This transport does not attest Google device credentials.
class ChromecastSession {
  ChromecastSession({Future<Socket> Function(ChromecastDevice)? socketFactory})
    : _socketFactory = socketFactory;
  final Future<Socket> Function(ChromecastDevice)? _socketFactory;
  bool positionRestoreFailed = false;
  Future<void>? _closing;
  static const _receiver = 'urn:x-cast:com.google.cast.receiver';
  static const _media = 'urn:x-cast:com.google.cast.media';
  static const _connection = 'urn:x-cast:com.google.cast.tp.connection';
  static const _heartbeat = 'urn:x-cast:com.google.cast.tp.heartbeat';
  final _updates = StreamController<ChromecastStatus>.broadcast();
  final _pending = <int, Completer<Map<String, dynamic>>>{};
  Socket? _socket;
  StreamSubscription<CastMessage>? _messages;
  Timer? _poll;
  bool _polling = false, _closed = false;
  int _sequence = 0;
  String? _transport;
  String? _expectedContentId;
  bool _mediaConfirmed = false;
  double _receiverVolume = 1;
  String? _loggedState;
  int? _loggedPosition;
  int _ignoredStatuses = 0;
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
    final elapsed = Stopwatch()..start();
    final type = data['type'];
    if (type != 'GET_STATUS') AppLogger.log('Cast: request id=$id type=$type');
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
      if (type != 'GET_STATUS') {
        AppLogger.log(
          'Cast: reply id=$id type=$type result=${reply['type']} elapsedMs=${elapsed.elapsedMilliseconds}',
        );
      }
      return reply;
    } catch (error) {
      AppLogger.log(
        'Cast: request failed id=$id type=$type elapsedMs=${elapsed.elapsedMilliseconds} error=${error.runtimeType} closed=$_closed',
      );
      rethrow;
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
            playbackRate: status.playbackRate,
            supportedMediaCommands: status.supportedMediaCommands,
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
          if (!belongsToLoad && ++_ignoredStatuses <= 3) {
            AppLogger.log(
              'Cast: ignored unrelated media status session=${value['mediaSessionId']} hasContentId=${contentId != null}',
            );
          }
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
              playbackRate:
                  (value['playbackRate'] as num?)?.toDouble() ??
                  status.playbackRate,
              supportedMediaCommands:
                  (value['supportedMediaCommands'] as num?)?.toInt() ??
                  status.supportedMediaCommands,
              sessionId: value['mediaSessionId'] as int?,
            );
            if (_loggedState != status.state ||
                _loggedPosition == null ||
                (status.position.inSeconds - _loggedPosition!).abs() >= 10) {
              AppLogger.log(
                'Cast: status state=${status.state} session=${status.sessionId} positionMs=${status.position.inMilliseconds} durationMs=${status.duration.inMilliseconds} rate=${status.playbackRate} commands=${status.supportedMediaCommands}',
              );
              _loggedState = status.state;
              _loggedPosition = status.position.inSeconds;
            }
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
    AppLogger.log(
      'Cast: connection lost state=${status.state} positionMs=${status.position.inMilliseconds} pending=${_pending.length}',
    );
    _poll?.cancel();
    status = ChromecastStatus(
      state: status.state,
      position: status.position,
      duration: status.duration,
      volume: status.volume,
      playbackRate: status.playbackRate,
      supportedMediaCommands: status.supportedMediaCommands,
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
    AppLogger.log('Cast: connecting');
    _socket =
        await (_socketFactory?.call(device) ??
            SecureSocket.connect(
              device.host,
              device.port,
              onBadCertificate: (_) => true,
              timeout: const Duration(seconds: 8),
            ));
    if (_closed) {
      _socket?.destroy();
      throw StateError('cast_cancelled');
    }
    _messages = CastV2Channel.parseMessages(
      _socket!,
    ).listen(_receive, onError: (Object _) => _lost(), onDone: _lost);
    AppLogger.log('Cast: transport connected; launching receiver');
    _send(_connection, 'receiver-0', {'type': 'CONNECT'});
    final reply = await _request(_receiver, 'receiver-0', {
      'type': 'LAUNCH',
      'appId': 'CC1AD845',
    });
    final applications = reply['status']['applications'] as List;
    final app = applications.firstWhere((a) => a['appId'] == 'CC1AD845');
    _transport = app['transportId'] as String;
    AppLogger.log('Cast: receiver launched');
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
    positionRestoreFailed = false;
    _expectedContentId = url;
    AppLogger.log(
      'Cast: load requested positionMs=${position.inMilliseconds} live=$live',
    );
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
          status.state == (autoplay ? 'PLAYING' : 'PAUSED')) {
        AppLogger.log(
          'Cast: media ready state=${status.state} positionMs=${status.position.inMilliseconds}',
        );
        // LOAD.currentTime is ignored by some receivers. Readiness and seeking
        // are separate: a playing receiver must never wait for the clock to
        // happen to reach the requested position.
        if (!live && (status.position - position).inSeconds.abs() > 5) {
          try {
            await (() async {
              await seek(position);
              final seekDeadline = DateTime.now().add(
                const Duration(milliseconds: 2500),
              );
              do {
                if (_closed) throw StateError('cast_cancelled');
                await refresh();
                if ((status.position - position).inSeconds.abs() <= 5) break;
                await Future<void>.delayed(const Duration(milliseconds: 200));
              } while (!_closed && DateTime.now().isBefore(seekDeadline));
            })().timeout(const Duration(seconds: 3));
            positionRestoreFailed =
                (status.position - position).inSeconds.abs() > 5;
          } catch (_) {
            if (_closed) throw StateError('cast_cancelled');
            positionRestoreFailed = true;
          }
          AppLogger.log(
            'Cast: position restore requestedMs=${position.inMilliseconds} actualMs=${status.position.inMilliseconds} failed=$positionRestoreFailed',
          );
        }
        if (_closed) throw StateError('cast_cancelled');
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 500));
    } while (!_closed && DateTime.now().isBefore(deadline));
    AppLogger.log(
      'Cast: load timeout confirmed=$_mediaConfirmed state=${status.state} positionMs=${status.position.inMilliseconds}',
    );
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

  Future<void> setPlaybackRate(double rate) async {
    if (!status.supportsPlaybackRate ||
        !rate.isFinite ||
        rate < 0.5 ||
        rate > 2) {
      throw UnsupportedError('cast_playback_rate_unavailable');
    }
    final previous = status.playbackRate;
    try {
      await command('SET_PLAYBACK_RATE', {'playbackRate': rate});
      await refresh();
      if ((status.playbackRate - rate).abs() > 0.01) {
        throw StateError('cast_playback_rate_not_applied');
      }
    } catch (_) {
      // A receiver may acknowledge a request without applying the rate.
      try {
        await command('SET_PLAYBACK_RATE', {'playbackRate': previous});
        await refresh();
      } catch (_) {
        /* The next status still reports the receiver's actual rate. */
      }
      rethrow;
    }
  }

  Future<void> setVolume(double volume) async {
    await _request(_receiver, 'receiver-0', {
      'type': 'SET_VOLUME',
      'volume': {'level': volume.clamp(0.0, 1.0)},
    });
    await refresh();
  }

  Future<void> close({bool stop = true}) => _closing ??= _close(stop);

  Future<void> _close(bool stop) async {
    _poll?.cancel();
    // Send STOP without waiting for an acknowledgement before cancelling the
    // pending operations. A silent receiver must not trap the user here.
    if (stop && status.sessionId != null && !status.disconnected && !_closed) {
      try {
        _send(_media, _transport!, {
          'type': 'STOP',
          'mediaSessionId': status.sessionId,
          'requestId': ++_sequence,
        });
      } catch (_) {
        /* Receiver may already be offline. */
      }
    }
    _closed = true;
    for (final pending in _pending.values) {
      if (!pending.isCompleted) {
        pending.completeError(StateError('cast_closed'));
      }
    }
    try {
      await _socket?.flush().timeout(const Duration(milliseconds: 500));
    } catch (_) {
      /* Best effort delivery before closing the connection. */
    }
    _socket?.destroy();
    AppLogger.log('Cast: transport closed stop=$stop');
    await _messages?.cancel();
    await _updates.close();
  }
}
