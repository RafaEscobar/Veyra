import 'dart:async';

typedef AutoLockCallback = Future<void> Function();
typedef AutoLockNow = DateTime Function();

final class VaultAutoLockManager {
  VaultAutoLockManager({
    required this.timeout,
    required this.onLock,
    AutoLockNow? now,
  }) : _now = now ?? DateTime.now;

  final Duration timeout;
  final AutoLockCallback onLock;
  final AutoLockNow _now;

  Timer? _timer;
  DateTime? _backgroundedAt;
  bool _active = false;
  bool _locking = false;
  bool _disposed = false;

  bool get isActive => _active;

  void activate() {
    if (_disposed) {
      return;
    }
    _active = true;
    _locking = false;
    _backgroundedAt = null;
    _arm(timeout);
  }

  void registerActivity() {
    if (!_active || _disposed || _backgroundedAt != null) {
      return;
    }
    _arm(timeout);
  }

  void movedToBackground() {
    if (!_active || _disposed || _backgroundedAt != null) {
      return;
    }
    _backgroundedAt = _now();
    _arm(timeout);
  }

  void resumed() {
    if (!_active || _disposed) {
      return;
    }
    final DateTime? backgroundedAt = _backgroundedAt;
    _backgroundedAt = null;
    if (backgroundedAt != null &&
        _now().difference(backgroundedAt) >= timeout) {
      unawaited(lock());
      return;
    }
    _arm(timeout);
  }

  Future<void> detached() => lock();

  Future<void> lock() async {
    if (!_active || _locking || _disposed) {
      return;
    }
    _locking = true;
    _active = false;
    _backgroundedAt = null;
    _timer?.cancel();
    _timer = null;
    try {
      await onLock();
    } finally {
      _locking = false;
    }
  }

  void _arm(Duration duration) {
    _timer?.cancel();
    _timer = Timer(duration, () => unawaited(lock()));
  }

  void dispose() {
    _disposed = true;
    _active = false;
    _timer?.cancel();
    _timer = null;
  }
}
