import 'dart:async';
import 'package:wakelock_plus/wakelock_plus.dart' as platform;

/// Serializes screen-awake requests. A recording owns an independent hold:
/// stopping any player cannot release it.
class WakeLockCoordinator {
  WakeLockCoordinator({required this.read, required this.write});
  final Future<bool> Function() read;
  final Future<void> Function(bool) write;
  final Set<Object> _holds = {};
  bool _requested = false;
  Future<void> _pending = Future.value();
  Future<void> _run(Future<void> Function() action) {
    final next = _pending.then((_) => action());
    _pending = next.catchError((Object _) {});
    return next;
  }

  Future<bool> get enabled async {
    await _pending;
    return read();
  }

  Future<void> toggle(bool enabled) => _run(() async {
    _requested = enabled;
    await write(enabled || _holds.isNotEmpty);
  });
  Future<void> acquire(Object owner) => _run(() async {
    if (_holds.contains(owner)) return;
    if (_holds.isEmpty) _requested = await read();
    _holds.add(owner);
    try {
      await write(true);
    } catch (_) {
      _holds.remove(owner);
      rethrow;
    }
  });
  Future<void> release(Object owner) => _run(() async {
    if (!_holds.remove(owner)) return;
    await write(_requested || _holds.isNotEmpty);
  });
  Future<void> refresh() => _run(() async {
    if (_holds.isNotEmpty) await write(true);
  });
}

/// Compatible facade used by all Sonarpad callers of the wakelock plugin.
class WakelockPlus {
  static final coordinator = WakeLockCoordinator(
    read: () => platform.WakelockPlus.enabled,
    write: (value) => platform.WakelockPlus.toggle(enable: value),
  );
  static Future<bool> get enabled => coordinator.enabled;
  static Future<void> enable() => coordinator.toggle(true);
  static Future<void> disable() => coordinator.toggle(false);
}
