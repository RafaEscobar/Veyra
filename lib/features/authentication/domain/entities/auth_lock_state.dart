final class AuthLockState {
  const AuthLockState({required this.failedAttempts, required this.lockUntil});

  final int failedAttempts;
  final DateTime? lockUntil;
}
