import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:veyra/core/constants/app_constants.dart';
import 'package:veyra/core/errors/app_exception.dart';
import 'package:veyra/core/performance/performance_monitor.dart';
import 'package:veyra/features/authentication/domain/entities/auth_lock_state.dart';
import 'package:veyra/features/authentication/domain/repositories/authentication_repository.dart';
import 'package:veyra/features/authentication/presentation/cubit/unlock_state.dart';

typedef CurrentUtcTime = DateTime Function();

final class UnlockCubit extends Cubit<UnlockState> {
  UnlockCubit(
    this._repository, {
    CurrentUtcTime? utcNow,
    this.performanceMonitor = const PerformanceMonitor(),
  }) : _utcNow = utcNow ?? _systemUtcNow,
       super(const UnlockState());

  final AuthenticationRepository _repository;
  final PerformanceMonitor performanceMonitor;
  final CurrentUtcTime _utcNow;
  String _pin = '';
  DateTime? _lockUntil;
  Timer? _countdownTimer;

  Future<void> initialize() async {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _lockUntil = null;
    _clearPin();
    try {
      final AuthLockState lockState = await _repository.getLockState();
      final DateTime? lockUntil = lockState.lockUntil;
      if (lockUntil != null && lockUntil.isAfter(_utcNow())) {
        _startLockout(lockUntil, lockState.failedAttempts);
      } else if (!isClosed) {
        emit(UnlockState(failedAttempts: lockState.failedAttempts));
      }
    } on Object catch (error, stackTrace) {
      addError(error, stackTrace);
      if (!isClosed) {
        emit(const UnlockState(status: UnlockStatus.failure));
      }
    }
  }

  void addDigit(int digit) {
    if (!state.acceptsInput ||
        digit < 0 ||
        digit > 9 ||
        _pin.length >= AppConstants.pinLength) {
      return;
    }
    _pin = '$_pin$digit';
    emit(state.copyWith(pinLength: _pin.length, status: UnlockStatus.idle));
    if (_pin.length == AppConstants.pinLength) {
      unawaited(submit());
    }
  }

  void deleteDigit() {
    if (!state.acceptsInput || _pin.isEmpty) {
      return;
    }
    _pin = _pin.substring(0, _pin.length - 1);
    emit(state.copyWith(pinLength: _pin.length, status: UnlockStatus.idle));
  }

  Future<void> submit() async {
    if (_pin.length != AppConstants.pinLength || !state.acceptsInput) {
      return;
    }
    final String pin = _pin;
    _clearPin();
    emit(state.copyWith(pinLength: 0, status: UnlockStatus.submitting));

    try {
      await performanceMonitor.measure(
        PerformanceOperation.vaultUnlock,
        () => _repository.unlock(pin),
      );
      if (!isClosed) {
        emit(const UnlockState(status: UnlockStatus.unlocked));
      }
    } on WrongPinException catch (error) {
      if (!isClosed) {
        emit(
          UnlockState(
            status: UnlockStatus.wrongPin,
            failedAttempts: error.failedAttempts,
          ),
        );
      }
    } on VaultLockedException catch (error) {
      if (!isClosed) {
        _startLockout(error.lockUntil, state.failedAttempts + 1);
      }
    } on Object catch (error, stackTrace) {
      addError(error, stackTrace);
      if (!isClosed) {
        emit(const UnlockState(status: UnlockStatus.failure));
      }
    }
  }

  void resetAfterAutoLock() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _lockUntil = null;
    _clearPin();
    if (!isClosed) {
      emit(const UnlockState());
    }
  }

  void _startLockout(DateTime lockUntil, int failedAttempts) {
    _lockUntil = lockUntil;
    _countdownTimer?.cancel();
    _emitLockTime(failedAttempts);
    _countdownTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _emitLockTime(failedAttempts),
    );
  }

  void _emitLockTime(int failedAttempts) {
    final DateTime? lockUntil = _lockUntil;
    if (lockUntil == null || isClosed) {
      return;
    }
    final int milliseconds = lockUntil.difference(_utcNow()).inMilliseconds;
    if (milliseconds <= 0) {
      _countdownTimer?.cancel();
      _countdownTimer = null;
      _lockUntil = null;
      emit(UnlockState(failedAttempts: failedAttempts));
      return;
    }
    final int seconds = (milliseconds / 1000).ceil();
    emit(
      UnlockState(
        status: UnlockStatus.locked,
        failedAttempts: failedAttempts,
        remainingLockSeconds: seconds,
      ),
    );
  }

  void _clearPin() {
    _pin = '';
  }

  @override
  Future<void> close() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _clearPin();
    return super.close();
  }
}

DateTime _systemUtcNow() => DateTime.now().toUtc();
