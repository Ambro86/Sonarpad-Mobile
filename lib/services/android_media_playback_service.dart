import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import '../utils/app_logger.dart';

/// Keeps native media playback alive on Android without changing its decoder.
/// Commands are serialized across screens; an old screen cannot stop a new
/// screen's service. Player replacements during live recovery keep the lease.
class AndroidMediaPlaybackService {
  AndroidMediaPlaybackService({bool? supported})
    : _supported = supported ?? Platform.isAndroid;

  static const _channel = MethodChannel('sonarpad/mediakit_background');
  static final _sessions = <String, AndroidMediaPlaybackService>{};
  static Future<void> _pending = Future<void>.value();
  static int _nextId = 0;
  final String _id = '${DateTime.now().microsecondsSinceEpoch}-${_nextId++}';
  final bool _supported;
  bool _wanted = false;
  bool _running = false;
  bool _disposed = false;
  int _nativeStops = 0;
  String? _title;
  String? _pauseLabel;
  Future<void> Function()? onPause;

  static Future<void> _enqueue(Future<void> Function() operation) {
    final result = _pending.then((_) => operation());
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<void> start({required String title, required String pauseLabel}) {
    if (!_supported || _disposed) return Future<void>.value();
    _wanted = true;
    _sessions[_id] = this;
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'pause') return;
      final session = _sessions[call.arguments as String?];
      if (session == null || session._disposed) return;
      session._wanted = false;
      session._running = false;
      session._nativeStops++;
      await session.onPause?.call();
    });
    return _enqueue(() async {
      if (_disposed || !_wanted) return;
      if (_running && _title == title && _pauseLabel == pauseLabel) return;
      final nativeStops = _nativeStops;
      await _channel.invokeMethod<void>('start', {
        'id': _id,
        'title': title,
        'pauseLabel': pauseLabel,
      });
      _running = nativeStops == _nativeStops;
      _title = title;
      _pauseLabel = pauseLabel;
      await AppLogger.log('MediaKit Android background service started');
    });
  }

  Future<void> update({required bool playing, required bool buffering}) {
    if (!_supported || _disposed) return Future<void>.value();
    return _enqueue(() async {
      if (!_running || !_wanted || _disposed) return;
      try {
        await _channel.invokeMethod<void>('update', {
          'id': _id,
          'playing': playing,
          'buffering': buffering,
        });
      } catch (error) {
        await AppLogger.log('MediaKit background state update failed: $error');
      }
    });
  }

  Future<void> stop() {
    _wanted = false;
    if (!_supported) return Future<void>.value();
    return _enqueue(() async {
      if (!_running) return;
      try {
        await _channel.invokeMethod<void>('stop', {'id': _id});
        _running = false;
        await AppLogger.log('MediaKit Android background service stopped');
      } catch (error) {
        await AppLogger.log('MediaKit background service stop failed: $error');
      }
    });
  }

  Future<void> dispose() async {
    _disposed = true;
    await stop();
    _sessions.remove(_id);
    onPause = null;
  }
}
