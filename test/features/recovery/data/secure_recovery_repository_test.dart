import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:veyra/core/crypto/onboarding_crypto_service.dart';
import 'package:veyra/core/errors/app_exception.dart';
import 'package:veyra/core/security/encrypted_value.dart';
import 'package:veyra/core/security/security_config.dart';
import 'package:veyra/core/storage/secure_storage_service.dart';
import 'package:veyra/features/recovery/data/repositories/secure_recovery_repository.dart';
import 'package:veyra/features/recovery/domain/entities/recovery_info.dart';

void main() {
  late OnboardingCryptoService cryptoService;
  late MemorySecurityConfigStorage storage;
  late MutableClock clock;
  late SecureRecoveryRepository repository;

  setUp(() async {
    cryptoService = OnboardingCryptoService(kdfIterations: 1000);
    storage = MemorySecurityConfigStorage(
      await cryptoService.createSecurityConfig(
        pin: '1234',
        normalizedRecoveryAnswer: 'mi perro',
        securityQuestionId: 'pet_name',
      ),
    );
    clock = MutableClock(DateTime.utc(2026, 9, 26, 12));
    repository = SecureRecoveryRepository(
      storage: storage,
      cryptoService: cryptoService,
      utcNow: clock.call,
    );
  });

  tearDown(() => repository.cancel());

  test('shows only the configured security question', () async {
    final RecoveryInfo info = await repository.getInfo();

    expect(info.questionPrompt, '¿Cuál era el nombre de tu primera mascota?');
  });

  test(
    'replaces only the PIN wrapper while preserving the master key',
    () async {
      final SecurityConfig originalConfig = storage.value;
      final Uint8List originalMasterKey = await cryptoService
          .unwrapWithRecoveryAnswer(originalConfig, 'mi perro');

      await repository.verifyAnswer('mi perro');
      await repository.replacePin('5678');

      final SecurityConfig updatedConfig = storage.value;
      final Uint8List recoveredWithNewPin = await cryptoService.unwrapWithPin(
        updatedConfig,
        '5678',
      );
      expect(recoveredWithNewPin, orderedEquals(originalMasterKey));
      expect(updatedConfig.pinSalt, isNot(originalConfig.pinSalt));
      expect(
        updatedConfig.encryptedMasterKeyWithPin.cipherText,
        isNot(originalConfig.encryptedMasterKeyWithPin.cipherText),
      );
      expect(
        updatedConfig.encryptedMasterKeyWithRecovery.cipherText,
        originalConfig.encryptedMasterKeyWithRecovery.cipherText,
      );
      expect(updatedConfig.recoverySalt, originalConfig.recoverySalt);
      await expectLater(
        cryptoService.unwrapWithPin(updatedConfig, '1234'),
        throwsA(isA<VaultFileCorruptedException>()),
      );

      originalMasterKey.fillRange(0, originalMasterKey.length, 0);
      recoveredWithNewPin.fillRange(0, recoveredWithNewPin.length, 0);
    },
  );

  test('fifth wrong answer persists a recovery lockout', () async {
    for (int attempt = 1; attempt < 5; attempt++) {
      await expectLater(
        repository.verifyAnswer('incorrecta'),
        throwsA(isA<WrongRecoveryAnswerException>()),
      );
    }
    await expectLater(
      repository.verifyAnswer('incorrecta'),
      throwsA(isA<RecoveryLockedException>()),
    );

    expect(storage.value.recoveryFailedAttempts, 5);
    expect(
      storage.value.recoveryLockUntil,
      clock.value.add(const Duration(seconds: 30)),
    );

    final SecureRecoveryRepository restarted = SecureRecoveryRepository(
      storage: storage,
      cryptoService: cryptoService,
      utcNow: clock.call,
    );
    final RecoveryInfo persistedInfo = await restarted.getInfo();
    expect(persistedInfo.lockUntil, storage.value.recoveryLockUntil);
    restarted.cancel();
  });

  test(
    'does not retain a decrypted master key between recovery steps',
    () async {
      await repository.verifyAnswer('mi perro');
      final EncryptedValue wrapper =
          storage.value.encryptedMasterKeyWithRecovery;
      final Uint8List manipulated = base64Decode(wrapper.cipherText);
      manipulated[0] ^= 0x80;
      storage.value = storage.value.copyWith(
        encryptedMasterKeyWithRecovery: EncryptedValue(
          cipherText: base64Encode(manipulated),
          nonce: wrapper.nonce,
          mac: wrapper.mac,
        ),
      );

      await expectLater(
        repository.replacePin('5678'),
        throwsA(isA<VaultFileCorruptedException>()),
      );
      await expectLater(
        repository.replacePin('5678'),
        throwsA(isA<RecoverySessionMissingException>()),
      );
      manipulated.fillRange(0, manipulated.length, 0);
    },
  );
}

final class MemorySecurityConfigStorage implements SecurityConfigStorage {
  MemorySecurityConfigStorage(this.value);

  SecurityConfig value;

  @override
  Future<bool> hasSecurityConfig() async => true;

  @override
  Future<SecurityConfig> readSecurityConfig() async => value;

  @override
  Future<void> writeSecurityConfig(SecurityConfig config) async {
    value = config;
  }
}

final class MutableClock {
  MutableClock(this.value);

  DateTime value;

  DateTime call() => value;
}
