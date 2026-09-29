enum RecoveryStep { answer, newPin, confirmPin }

enum RecoveryStatus {
  loading,
  ready,
  submitting,
  wrongAnswer,
  locked,
  completed,
  failure,
}

enum RecoveryValidationError { answerRequired, pinMismatch }

final class RecoveryState {
  const RecoveryState({
    this.step = RecoveryStep.answer,
    this.status = RecoveryStatus.loading,
    this.questionPrompt = '',
    this.pinLength = 0,
    this.confirmPinLength = 0,
    this.failedAttempts = 0,
    this.remainingLockSeconds = 0,
    this.validationError,
  });

  final RecoveryStep step;
  final RecoveryStatus status;
  final String questionPrompt;
  final int pinLength;
  final int confirmPinLength;
  final int failedAttempts;
  final int remainingLockSeconds;
  final RecoveryValidationError? validationError;

  bool get isPinComplete => pinLength == 4;
  bool get isConfirmationComplete => confirmPinLength == 4;
  bool get acceptsAnswer =>
      status == RecoveryStatus.ready || status == RecoveryStatus.wrongAnswer;

  RecoveryState copyWith({
    RecoveryStep? step,
    RecoveryStatus? status,
    String? questionPrompt,
    int? pinLength,
    int? confirmPinLength,
    int? failedAttempts,
    int? remainingLockSeconds,
    RecoveryValidationError? validationError,
    bool clearValidationError = false,
  }) {
    return RecoveryState(
      step: step ?? this.step,
      status: status ?? this.status,
      questionPrompt: questionPrompt ?? this.questionPrompt,
      pinLength: pinLength ?? this.pinLength,
      confirmPinLength: confirmPinLength ?? this.confirmPinLength,
      failedAttempts: failedAttempts ?? this.failedAttempts,
      remainingLockSeconds: remainingLockSeconds ?? this.remainingLockSeconds,
      validationError: clearValidationError
          ? null
          : validationError ?? this.validationError,
    );
  }
}
