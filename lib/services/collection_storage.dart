import 'dart:async';

/// One queue for local edits and cloud application, including their reads.
/// Nested service calls participate in the current transaction.
class CollectionStorage {
  static Future<void> _tail = Future<void>.value();
  static final Object _zoneKey = Object();

  static Future<T> run<T>(Future<T> Function() action) {
    if (Zone.current[_zoneKey] == true) return action();
    final result = _tail.then(
      (_) => runZoned(action, zoneValues: {_zoneKey: true}),
    );
    _tail = result.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );
    return result;
  }
}
