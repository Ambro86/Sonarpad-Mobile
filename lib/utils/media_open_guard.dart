/// Prevents overlapping media-open operations from the same screen.
///
/// The acquisition is deliberately synchronous: a second activation arriving
/// before the first async resolver/Navigator operation yields cannot enter the
/// protected section.
class MediaOpenGuard {
  String? _activeKey;

  bool get isActive => _activeKey != null;
  String? get activeKey => _activeKey;

  bool tryAcquire(String key) {
    if (_activeKey != null) return false;
    _activeKey = key;
    return true;
  }

  void release(String key) {
    if (_activeKey == key) {
      _activeKey = null;
    }
  }
}
