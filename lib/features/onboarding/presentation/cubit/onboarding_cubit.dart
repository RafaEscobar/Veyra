import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:veyra/core/constants/app_constants.dart';
import 'package:veyra/core/security/answer_normalizer.dart';
import 'package:veyra/features/onboarding/domain/entities/security_question.dart';
import 'package:veyra/features/onboarding/domain/repositories/onboarding_repository.dart';
import 'package:veyra/features/onboarding/presentation/cubit/onboarding_state.dart';

final class OnboardingCubit extends Cubit<OnboardingState> {
  OnboardingCubit(this._repository) : super(const OnboardingState());

  final OnboardingRepository _repository;
  String _pin = '';
  String _pinConfirmation = '';

  void reset() {
    _clearSecrets();
    emit(const OnboardingState());
  }

  void addPinDigit(int digit) {
    if (digit < 0 || digit > 9 || _pin.length >= AppConstants.pinLength) {
      return;
    }
    _pin = '$_pin$digit';
    emit(state.copyWith(pinLength: _pin.length, clearValidationError: true));
  }

  void deletePinDigit() {
    if (_pin.isEmpty) {
      return;
    }
    _pin = _pin.substring(0, _pin.length - 1);
    emit(state.copyWith(pinLength: _pin.length, clearValidationError: true));
  }

  void addConfirmationDigit(int digit) {
    if (digit < 0 ||
        digit > 9 ||
        _pinConfirmation.length >= AppConstants.pinLength) {
      return;
    }
    _pinConfirmation = '$_pinConfirmation$digit';
    emit(
      state.copyWith(
        confirmPinLength: _pinConfirmation.length,
        clearValidationError: true,
      ),
    );
  }

  void deleteConfirmationDigit() {
    if (_pinConfirmation.isEmpty) {
      return;
    }
    _pinConfirmation = _pinConfirmation.substring(
      0,
      _pinConfirmation.length - 1,
    );
    emit(
      state.copyWith(
        confirmPinLength: _pinConfirmation.length,
        clearValidationError: true,
      ),
    );
  }

  bool confirmPin() {
    if (_pin.length != AppConstants.pinLength ||
        _pinConfirmation.length != AppConstants.pinLength ||
        _pin != _pinConfirmation) {
      _pinConfirmation = '';
      emit(
        state.copyWith(
          confirmPinLength: 0,
          validationError: OnboardingValidationError.pinMismatch,
        ),
      );
      return false;
    }
    return true;
  }

  void selectQuestion(SecurityQuestion question) {
    emit(
      state.copyWith(selectedQuestion: question, clearValidationError: true),
    );
  }

  Future<void> submitAnswers({
    required String answer,
    required String confirmation,
  }) async {
    final SecurityQuestion? question = state.selectedQuestion;
    if (question == null) {
      emit(
        state.copyWith(
          validationError: OnboardingValidationError.questionRequired,
        ),
      );
      return;
    }

    final String normalizedAnswer = AnswerNormalizer.normalize(answer);
    final String normalizedConfirmation = AnswerNormalizer.normalize(
      confirmation,
    );
    if (normalizedAnswer.isEmpty) {
      emit(
        state.copyWith(
          validationError: OnboardingValidationError.answerRequired,
        ),
      );
      return;
    }
    if (normalizedAnswer != normalizedConfirmation) {
      emit(
        state.copyWith(
          validationError: OnboardingValidationError.answerMismatch,
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        status: OnboardingSubmissionStatus.submitting,
        clearValidationError: true,
      ),
    );
    try {
      await _repository.complete(
        pin: _pin,
        normalizedRecoveryAnswer: normalizedAnswer,
        securityQuestionId: question.id,
      );
      _clearSecrets();
      if (!isClosed) {
        emit(
          state.copyWith(
            pinLength: 0,
            confirmPinLength: 0,
            status: OnboardingSubmissionStatus.success,
            clearValidationError: true,
          ),
        );
      }
    } on Object catch (error, stackTrace) {
      _clearSecrets();
      addError(error, stackTrace);
      if (!isClosed) {
        emit(
          state.copyWith(
            pinLength: 0,
            confirmPinLength: 0,
            status: OnboardingSubmissionStatus.failure,
            validationError: OnboardingValidationError.setupFailed,
          ),
        );
      }
    }
  }

  void _clearSecrets() {
    _pin = '';
    _pinConfirmation = '';
  }

  @override
  Future<void> close() {
    _clearSecrets();
    return super.close();
  }
}
