abstract final class LockoutPolicy {
  static const int attemptsPerTier = 5;

  static Duration? durationAfterFailure(int failedAttempts) {
    if (failedAttempts < attemptsPerTier ||
        failedAttempts % attemptsPerTier != 0) {
      return null;
    }
    if (failedAttempts >= 15) {
      return const Duration(minutes: 10);
    }
    if (failedAttempts >= 10) {
      return const Duration(minutes: 2);
    }
    return const Duration(seconds: 30);
  }
}
