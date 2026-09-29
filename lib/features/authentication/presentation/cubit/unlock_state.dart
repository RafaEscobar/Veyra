enum UnlockStatus { idle, submitting, wrongPin, locked, unlocked, failure }

final class UnlockState {
  const UnlockState({
    this.pinLength = 0,
    this.status = UnlockStatus.idle,
    this.failedAttempts = 0,
    this.remainingLockSeconds = 0,
  });

  final int pinLength;
  final UnlockStatus status;
  final int failedAttempts;
  final int remainingLockSeconds;

  bool get acceptsInput =>
      status != UnlockStatus.submitting && status != UnlockStatus.locked;

  UnlockState copyWith({
    int? pinLength,
    UnlockStatus? status,
    int? failedAttempts,
    int? remainingLockSeconds,
  }) {
    return UnlockState(
      pinLength: pinLength ?? this.pinLength,
      status: status ?? this.status,
      failedAttempts: failedAttempts ?? this.failedAttempts,
      remainingLockSeconds: remainingLockSeconds ?? this.remainingLockSeconds,
    );
  }
}
