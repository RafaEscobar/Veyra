import 'dart:typed_data';

import 'package:veyra/core/crypto/onboarding_crypto_service.dart';
import 'package:veyra/core/errors/app_exception.dart';
import 'package:veyra/core/security/lockout_policy.dart';
import 'package:veyra/core/security/security_config.dart';
import 'package:veyra/core/security/vault_session.dart';
import 'package:veyra/core/storage/flutter_secure_storage_service.dart';
import 'package:veyra/core/storage/secure_storage_service.dart';
import 'package:veyra/features/authentication/domain/entities/auth_lock_state.dart';
import 'package:veyra/features/authentication/domain/repositories/authentication_repository.dart';

typedef UtcNow = DateTime Function();

final class SecureAuthenticationRepository implements AuthenticationRepository {
  SecureAuthenticationRepository({
    SecurityConfigStorage? storage,
    OnboardingCryptoService? cryptoService,
    VaultSession? vaultSession,
    UtcNow? utcNow,
  }) : _storage = storage ?? const FlutterSecureStorageService(),
       _cryptoService = cryptoService ?? OnboardingCryptoService(),
       _vaultSession = vaultSession ?? VaultSession(),
       _utcNow = utcNow ?? _systemUtcNow;

  final SecurityConfigStorage _storage;
  final OnboardingCryptoService _cryptoService;
  final VaultSession _vaultSession;
  final UtcNow _utcNow;

  @override
  Future<AuthLockState> getLockState() async {
    final SecurityConfig config = await _requireConfig();
    final DateTime? lockUntil = config.lockUntil;
    if (lockUntil != null && !lockUntil.isAfter(_utcNow())) {
      final SecurityConfig updated = config.copyWith(clearLockUntil: true);
      await _storage.writeSecurityConfig(updated);
      return AuthLockState(
        failedAttempts: updated.failedAttempts,
        lockUntil: null,
      );
    }
    return AuthLockState(
      failedAttempts: config.failedAttempts,
      lockUntil: lockUntil,
    );
  }

  @override
  Future<void> unlock(String pin) async {
    final SecurityConfig config = await _requireConfig();
    final DateTime now = _utcNow();
    final DateTime? existingLock = config.lockUntil;
    if (existingLock != null && existingLock.isAfter(now)) {
      throw VaultLockedException(lockUntil: existingLock);
    }

    Uint8List? masterKey;
    try {
      masterKey = await _cryptoService.unwrapWithPin(config, pin);
      await _storage.writeSecurityConfig(
        config.copyWith(failedAttempts: 0, clearLockUntil: true),
      );
      _vaultSession.open(masterKey);
    } on VaultFileCorruptedException {
      await _registerFailedAttempt(config, now);
    } finally {
      masterKey?.fillRange(0, masterKey.length, 0);
    }
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
    final int failedAttempts = config.failedAttempts + 1;
    final Duration? lockDuration = LockoutPolicy.durationAfterFailure(
      failedAttempts,
    );
    final DateTime? lockUntil = lockDuration == null
        ? null
        : now.add(lockDuration);
    await _storage.writeSecurityConfig(
      config.copyWith(
        failedAttempts: failedAttempts,
        lockUntil: lockUntil,
        clearLockUntil: lockUntil == null,
      ),
    );

    if (lockUntil != null) {
      throw VaultLockedException(lockUntil: lockUntil);
    }
    throw WrongPinException(failedAttempts: failedAttempts);
  }
}

DateTime _systemUtcNow() => DateTime.now().toUtc();
