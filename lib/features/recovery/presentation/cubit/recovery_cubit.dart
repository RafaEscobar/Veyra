import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:veyra/core/constants/app_constants.dart';
import 'package:veyra/core/errors/app_exception.dart';
import 'package:veyra/core/security/answer_normalizer.dart';
import 'package:veyra/features/recovery/domain/entities/recovery_info.dart';
import 'package:veyra/features/recovery/domain/repositories/recovery_repository.dart';
import 'package:veyra/features/recovery/presentation/cubit/recovery_state.dart';

typedef RecoveryCurrentUtcTime = DateTime Function();

final class RecoveryCubit extends Cubit<RecoveryState> {
  RecoveryCubit(this._repository, {RecoveryCurrentUtcTime? utcNow})
    : _utcNow = utcNow ?? _systemUtcNow,
      super(const RecoveryState());

  final RecoveryRepository _repository;
  final RecoveryCurrentUtcTime _utcNow;
  String _newPin = '';
  String _newPinConfirmation = '';
  DateTime? _lockUntil;
  Timer? _countdownTimer;

  Future<void> initialize() async {
    try {
      final RecoveryInfo info = await _repository.getInfo();
      final DateTime? lockUntil = info.lockUntil;
      if (lockUntil != null && lockUntil.isAfter(_utcNow())) {
        _startLockout(lockUntil, info.failedAttempts, info.questionPrompt);
      } else if (!isClosed) {
        emit(
          RecoveryState(
            status: RecoveryStatus.ready,
            questionPrompt: info.questionPrompt,
            failedAttempts: info.failedAttempts,
          ),
        );
      }
    } on Object catch (error, stackTrace) {
      addError(error, stackTrace);
      if (!isClosed) {
        emit(const RecoveryState(status: RecoveryStatus.failure));
      }
    }
  }

  Future<void> verifyAnswer(String answer) async {
    if (!state.acceptsAnswer) {
      return;
    }
    final String normalizedAnswer = AnswerNormalizer.normalize(answer);
    if (normalizedAnswer.isEmpty) {
      emit(
        state.copyWith(validationError: RecoveryValidationError.answerRequired),
      );
      return;
    }

    emit(
      state.copyWith(
        status: RecoveryStatus.submitting,
        clearValidationError: true,
      ),
    );
    try {
      await _repository.verifyAnswer(normalizedAnswer);
      if (!isClosed) {
        emit(
          state.copyWith(
            step: RecoveryStep.newPin,
            status: RecoveryStatus.ready,
            failedAttempts: 0,
            clearValidationError: true,
          ),
        );
      }
    } on WrongRecoveryAnswerException catch (error) {
      if (!isClosed) {
        emit(
          state.copyWith(
            status: RecoveryStatus.wrongAnswer,
            failedAttempts: error.failedAttempts,
            clearValidationError: true,
          ),
        );
      }
    } on RecoveryLockedException catch (error) {
      if (!isClosed) {
        _startLockout(
          error.lockUntil,
          state.failedAttempts + 1,
          state.questionPrompt,
        );
      }
    } on Object catch (error, stackTrace) {
      addError(error, stackTrace);
      if (!isClosed) {
        emit(state.copyWith(status: RecoveryStatus.failure));
      }
    }
  }

  void addNewPinDigit(int digit) {
    if (!_acceptsPinInput(RecoveryStep.newPin) ||
        digit < 0 ||
        digit > 9 ||
        _newPin.length >= AppConstants.pinLength) {
      return;
    }
    _newPin = '$_newPin$digit';
    emit(state.copyWith(pinLength: _newPin.length, clearValidationError: true));
  }

  void deleteNewPinDigit() {
    if (!_acceptsPinInput(RecoveryStep.newPin) || _newPin.isEmpty) {
      return;
    }
    _newPin = _newPin.substring(0, _newPin.length - 1);
    emit(state.copyWith(pinLength: _newPin.length));
  }

  void continueToConfirmation() {
    if (_newPin.length != AppConstants.pinLength) {
      return;
    }
    _newPinConfirmation = '';
    emit(
      state.copyWith(
        step: RecoveryStep.confirmPin,
        confirmPinLength: 0,
        clearValidationError: true,
      ),
    );
  }

  void addConfirmationDigit(int digit) {
    if (!_acceptsPinInput(RecoveryStep.confirmPin) ||
        digit < 0 ||
        digit > 9 ||
        _newPinConfirmation.length >= AppConstants.pinLength) {
      return;
    }
    _newPinConfirmation = '$_newPinConfirmation$digit';
    emit(
      state.copyWith(
        confirmPinLength: _newPinConfirmation.length,
        clearValidationError: true,
      ),
    );
  }

  void deleteConfirmationDigit() {
    if (!_acceptsPinInput(RecoveryStep.confirmPin) ||
        _newPinConfirmation.isEmpty) {
      return;
    }
    _newPinConfirmation = _newPinConfirmation.substring(
      0,
      _newPinConfirmation.length - 1,
    );
    emit(state.copyWith(confirmPinLength: _newPinConfirmation.length));
  }

  Future<void> saveNewPin() async {
    if (_newPin.length != AppConstants.pinLength ||
        _newPinConfirmation.length != AppConstants.pinLength ||
        state.status == RecoveryStatus.submitting) {
      return;
    }
    if (_newPin != _newPinConfirmation) {
      _newPinConfirmation = '';
      emit(
        state.copyWith(
          confirmPinLength: 0,
          validationError: RecoveryValidationError.pinMismatch,
        ),
      );
      return;
    }

    final String newPin = _newPin;
    _clearPins();
    emit(
      state.copyWith(
        pinLength: 0,
        confirmPinLength: 0,
        status: RecoveryStatus.submitting,
        clearValidationError: true,
      ),
    );
    try {
      await _repository.replacePin(newPin);
      if (!isClosed) {
        emit(
          state.copyWith(
            status: RecoveryStatus.completed,
            clearValidationError: true,
          ),
        );
      }
    } on Object catch (error, stackTrace) {
      addError(error, stackTrace);
      if (!isClosed) {
        emit(state.copyWith(status: RecoveryStatus.failure));
      }
    }
  }

  bool _acceptsPinInput(RecoveryStep step) {
    return state.step == step && state.status == RecoveryStatus.ready;
  }

  void _startLockout(
    DateTime lockUntil,
    int failedAttempts,
    String questionPrompt,
  ) {
    _lockUntil = lockUntil;
    _countdownTimer?.cancel();
    _emitLockTime(failedAttempts, questionPrompt);
    _countdownTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _emitLockTime(failedAttempts, questionPrompt),
    );
  }

  void _emitLockTime(int failedAttempts, String questionPrompt) {
    final DateTime? lockUntil = _lockUntil;
    if (lockUntil == null || isClosed) {
      return;
    }
    final int milliseconds = lockUntil.difference(_utcNow()).inMilliseconds;
    if (milliseconds <= 0) {
      _countdownTimer?.cancel();
      _countdownTimer = null;
      _lockUntil = null;
      emit(
        RecoveryState(
          status: RecoveryStatus.ready,
          questionPrompt: questionPrompt,
          failedAttempts: failedAttempts,
        ),
      );
      return;
    }
    emit(
      RecoveryState(
        status: RecoveryStatus.locked,
        questionPrompt: questionPrompt,
        failedAttempts: failedAttempts,
        remainingLockSeconds: (milliseconds / 1000).ceil(),
      ),
    );
  }

  void _clearPins() {
    _newPin = '';
    _newPinConfirmation = '';
  }

  @override
  Future<void> close() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _clearPins();
    _repository.cancel();
    return super.close();
  }
}

DateTime _systemUtcNow() => DateTime.now().toUtc();
