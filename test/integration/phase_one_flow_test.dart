import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:veyra/app/theme/theme_cubit.dart';
import 'package:veyra/core/crypto/onboarding_crypto_service.dart';
import 'package:veyra/core/errors/app_exception.dart';
import 'package:veyra/core/security/security_config.dart';
import 'package:veyra/core/security/vault_session.dart';
import 'package:veyra/core/storage/secure_storage_service.dart';
import 'package:veyra/features/authentication/data/repositories/secure_authentication_repository.dart';
import 'package:veyra/features/onboarding/data/repositories/secure_onboarding_repository.dart';
import 'package:veyra/features/recovery/data/repositories/secure_recovery_repository.dart';

void main() {
  test('phase one security flow preserves one master key end to end', () async {
    final MemorySecureStorageService storage = MemorySecureStorageService();
    final OnboardingCryptoService cryptoService = OnboardingCryptoService(
      kdfIterations: 1000,
    );
    final SecureOnboardingRepository onboarding = SecureOnboardingRepository(
      storage: storage,
      cryptoService: cryptoService,
    );

    expect(await onboarding.isCompleted(), isFalse);
    await onboarding.complete(
      pin: '1234',
      normalizedRecoveryAnswer: 'mi perro',
      securityQuestionId: 'pet_name',
    );
    expect(await onboarding.isCompleted(), isTrue);

    final VaultSession firstSession = VaultSession();
    final SecureAuthenticationRepository authentication =
        SecureAuthenticationRepository(
          storage: storage,
          cryptoService: cryptoService,
          vaultSession: firstSession,
        );
    await expectLater(
      authentication.unlock('9999'),
      throwsA(isA<WrongPinException>()),
    );
    await authentication.unlock('1234');
    final Uint8List originalMasterKey = await _copyMasterKey(firstSession);
    firstSession.lock();

    final SecureRecoveryRepository recovery = SecureRecoveryRepository(
      storage: storage,
      cryptoService: cryptoService,
    );
    await expectLater(
      recovery.verifyAnswer('respuesta incorrecta'),
      throwsA(isA<WrongRecoveryAnswerException>()),
    );
    await recovery.verifyAnswer('mi perro');
    await recovery.replacePin('5678');

    final VaultSession recoveredSession = VaultSession();
    final SecureAuthenticationRepository recoveredAuthentication =
        SecureAuthenticationRepository(
          storage: storage,
          cryptoService: cryptoService,
          vaultSession: recoveredSession,
        );
    await expectLater(
      recoveredAuthentication.unlock('1234'),
      throwsA(isA<WrongPinException>()),
    );
    await recoveredAuthentication.unlock('5678');
    final Uint8List recoveredMasterKey = await _copyMasterKey(recoveredSession);

    expect(recoveredMasterKey, orderedEquals(originalMasterKey));
    expect(storage.config?.failedAttempts, 0);
    expect(storage.config?.recoveryFailedAttempts, 0);

    originalMasterKey.fillRange(0, originalMasterKey.length, 0);
    recoveredMasterKey.fillRange(0, recoveredMasterKey.length, 0);
    recoveredSession.lock();
  });

  test('theme selection survives a new cubit instance', () async {
    final MemorySecureStorageService storage = MemorySecureStorageService();
    final ThemeCubit firstCubit = ThemeCubit(storage);
    await firstCubit.toggle();
    await firstCubit.close();

    final ThemeCubit restartedCubit = ThemeCubit(storage);
    await restartedCubit.load();

    expect(restartedCubit.state, ThemeMode.dark);
    await restartedCubit.close();
  });
}

Future<Uint8List> _copyMasterKey(VaultSession session) {
  return session.withMasterKey((SecretKey key) async {
    return Uint8List.fromList(await key.extractBytes());
  });
}

final class MemorySecureStorageService implements SecureStorageService {
  SecurityConfig? config;
  ThemeMode? themeMode;

  @override
  Future<bool> hasSecurityConfig() async => config != null;

  @override
  Future<SecurityConfig?> readSecurityConfig() async => config;

  @override
  Future<ThemeMode?> readThemeMode() async => themeMode;

  @override
  Future<void> writeSecurityConfig(SecurityConfig config) async {
    this.config = config;
  }

  @override
  Future<void> writeThemeMode(ThemeMode themeMode) async {
    this.themeMode = themeMode;
  }
}
