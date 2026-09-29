abstract interface class OnboardingRepository {
  Future<bool> isCompleted();

  Future<void> complete({
    required String pin,
    required String normalizedRecoveryAnswer,
    required String securityQuestionId,
  });
}
