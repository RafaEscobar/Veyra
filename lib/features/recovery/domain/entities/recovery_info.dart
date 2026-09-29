final class RecoveryInfo {
  const RecoveryInfo({
    required this.questionPrompt,
    required this.failedAttempts,
    required this.lockUntil,
  });

  final String questionPrompt;
  final int failedAttempts;
  final DateTime? lockUntil;
}
