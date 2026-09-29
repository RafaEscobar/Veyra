import 'dart:convert';
import 'dart:typed_data';

import 'package:veyra/core/crypto/onboarding_crypto_service.dart';
import 'package:veyra/core/errors/app_exception.dart';
import 'package:veyra/core/security/lockout_policy.dart';
import 'package:veyra/core/security/pin_key_replacement.dart';
import 'package:veyra/core/security/security_config.dart';
import 'package:veyra/core/storage/flutter_secure_storage_service.dart';
import 'package:veyra/core/storage/secure_storage_service.dart';
import 'package:veyra/features/onboarding/domain/entities/security_question.dart';
import 'package:veyra/features/recovery/domain/entities/recovery_info.dart';
import 'package:veyra/features/recovery/domain/repositories/recovery_repository.dart';

typedef RecoveryUtcNow = DateTime Function();

final class SecureRecoveryRepository implements RecoveryRepository {
  SecureRecoveryRepository({
    SecurityConfigStorage? storage,
    OnboardingCryptoService? cryptoService,
    RecoveryUtcNow? utcNow,
  }) : _storage = storage ?? const FlutterSecureStorageService(),
       _cryptoService = cryptoService ?? OnboardingCryptoService(),
       _utcNow = utcNow ?? _systemUtcNow;

  final SecurityConfigStorage _storage;
  final OnboardingCryptoService _cryptoService;
  final RecoveryUtcNow _utcNow;
  Uint8List? _authorizedAnswerBytes;

  @override
  Future<RecoveryInfo> getInfo() async {
    SecurityConfig config = await _requireConfig();
    final DateTime? lockUntil = config.recoveryLockUntil;
    if (lockUntil != null && !lockUntil.isAfter(_utcNow())) {
      config = config.copyWith(clearRecoveryLockUntil: true);
      await _storage.writeSecurityConfig(config);
    }
    return RecoveryInfo(
      questionPrompt: _questionPrompt(config.securityQuestionId),
      failedAttempts: config.recoveryFailedAttempts,
      lockUntil: config.recoveryLockUntil,
    );
  }

  @override
  Future<void> verifyAnswer(String normalizedAnswer) async {
    cancel();
    final SecurityConfig config = await _requireConfig();
    final DateTime now = _utcNow();
    final DateTime? existingLock = config.recoveryLockUntil;
    if (existingLock != null && existingLock.isAfter(now)) {
      throw RecoveryLockedException(lockUntil: existingLock);
    }

    Uint8List? masterKey;
    try {
      masterKey = await _cryptoService.unwrapWithRecoveryAnswer(
        config,
        normalizedAnswer,
      );
      await _storage.writeSecurityConfig(
        config.copyWith(
          recoveryFailedAttempts: 0,
          clearRecoveryLockUntil: true,
        ),
      );
      _storeAuthorizedAnswer(normalizedAnswer);
    } on VaultFileCorruptedException {
      await _registerFailedAttempt(config, now);
    } finally {
      masterKey?.fillRange(0, masterKey.length, 0);
    }
  }

  @override
  Future<void> replacePin(String newPin) async {
    final Uint8List? authorizedAnswerBytes = _authorizedAnswerBytes;
    if (authorizedAnswerBytes == null) {
      throw const RecoverySessionMissingException();
    }

    Uint8List? masterKey;
    try {
      final SecurityConfig config = await _requireConfig();
      final String authorizedAnswer = utf8.decode(authorizedAnswerBytes);
      masterKey = await _cryptoService.unwrapWithRecoveryAnswer(
        config,
        authorizedAnswer,
      );
      final PinKeyReplacement replacement = await _cryptoService
          .createPinReplacement(
            masterKey: masterKey,
            newPin: newPin,
            iterations: config.kdfIterations,
          );
      await _storage.writeSecurityConfig(
        config.copyWith(
          pinSalt: replacement.pinSalt,
          encryptedMasterKeyWithPin: replacement.encryptedMasterKey,
          failedAttempts: 0,
          clearLockUntil: true,
          recoveryFailedAttempts: 0,
          clearRecoveryLockUntil: true,
        ),
      );
    } finally {
      masterKey?.fillRange(0, masterKey.length, 0);
      cancel();
    }
  }

  @override
  void cancel() {
    final Uint8List? answerBytes = _authorizedAnswerBytes;
    answerBytes?.fillRange(0, answerBytes.length, 0);
    _authorizedAnswerBytes = null;
  }

  Future<SecurityConfig> _requireConfig() async {
    final SecurityConfig? config = await _storage.readSecurityConfig();
    if (config == null) {
      throw const SecurityConfigNotFoundException();
    }
    return config;
  }

  Future<Never> _registerFailedAttempt(
    SecurityConfig config,
    DateTime now,
  ) async {
    final int failedAttempts = config.recoveryFailedAttempts + 1;
    final Duration? duration = LockoutPolicy.durationAfterFailure(
      failedAttempts,
    );
    final DateTime? lockUntil = duration == null ? null : now.add(duration);
    await _storage.writeSecurityConfig(
      config.copyWith(
        recoveryFailedAttempts: failedAttempts,
        recoveryLockUntil: lockUntil,
        clearRecoveryLockUntil: lockUntil == null,
      ),
    );

    if (lockUntil != null) {
      throw RecoveryLockedException(lockUntil: lockUntil);
    }
    throw WrongRecoveryAnswerException(failedAttempts: failedAttempts);
  }

  void _storeAuthorizedAnswer(String normalizedAnswer) {
    cancel();
    _authorizedAnswerBytes = Uint8List.fromList(utf8.encode(normalizedAnswer));
  }

  String _questionPrompt(String questionId) {
    for (final SecurityQuestion question in SecurityQuestion.values) {
      if (question.id == questionId) {
        return question.prompt;
      }
    }
    throw const FormatException('Unknown security question.');
  }
}

DateTime _systemUtcNow() => DateTime.now().toUtc();
