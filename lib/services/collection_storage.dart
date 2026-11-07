import 'dart:async';

/// One queue for local edits and cloud application, including their reads.
/// Nested service calls participate in the current transaction.
class CollectionStorage {
  static Future<void>? _tail;
  static final Object _zoneKey = Object();

  static Future<T> run<T>(Future<T> Function() action) {
    if (Zone.current[_zoneKey] == true) return action();
    final result = (_tail ?? Future<void>.value()).then(
      (_) => runZoned(action, zoneValues: {_zoneKey: true}),
    );
    late final Future<void> settled;
    void release() {
      // Keep queued writes serialized, but do not retain an idle caller's zone.
      if (identical(_tail, settled)) _tail = null;
    }
    settled = result.then<void>(
      (_) => release(),
      onError: (Object error, StackTrace stack) => release(),
    );
    _tail = settled;
    return result;
  }
}
