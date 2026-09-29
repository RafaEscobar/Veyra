import 'package:veyra/features/onboarding/domain/entities/security_question.dart';

enum OnboardingSubmissionStatus { idle, submitting, success, failure }

enum OnboardingValidationError {
  pinMismatch,
  questionRequired,
  answerRequired,
  answerMismatch,
  setupFailed,
}

final class OnboardingState {
  const OnboardingState({
    this.pinLength = 0,
    this.confirmPinLength = 0,
    this.selectedQuestion,
    this.status = OnboardingSubmissionStatus.idle,
    this.validationError,
  });

  final int pinLength;
  final int confirmPinLength;
  final SecurityQuestion? selectedQuestion;
  final OnboardingSubmissionStatus status;
  final OnboardingValidationError? validationError;

  bool get isPinComplete => pinLength == 4;
  bool get isConfirmationComplete => confirmPinLength == 4;

  OnboardingState copyWith({
    int? pinLength,
    int? confirmPinLength,
    SecurityQuestion? selectedQuestion,
    OnboardingSubmissionStatus? status,
    OnboardingValidationError? validationError,
    bool clearValidationError = false,
  }) {
    return OnboardingState(
      pinLength: pinLength ?? this.pinLength,
      confirmPinLength: confirmPinLength ?? this.confirmPinLength,
      selectedQuestion: selectedQuestion ?? this.selectedQuestion,
      status: status ?? this.status,
      validationError: clearValidationError
          ? null
          : validationError ?? this.validationError,
    );
  }
}
