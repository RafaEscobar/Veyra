import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:veyra/core/crypto/onboarding_crypto_service.dart';
import 'package:veyra/core/errors/app_exception.dart';
import 'package:veyra/core/security/security_config.dart';

void main() {
  final OnboardingCryptoService service = OnboardingCryptoService(
    kdfIterations: 1000,
  );

  test(
    'creates two independent authenticated wrappers for one master key',
    () async {
      final SecurityConfig config = await service.createSecurityConfig(
        pin: '1234',
        normalizedRecoveryAnswer: 'mi perro',
        securityQuestionId: 'pet_name',
      );

      final List<int> pinMasterKey = await service.unwrapWithPin(
        config,
        '1234',
      );
      final List<int> recoveryMasterKey = await service
          .unwrapWithRecoveryAnswer(config, 'mi perro');

      expect(pinMasterKey, orderedEquals(recoveryMasterKey));
      expect(pinMasterKey, hasLength(32));
      expect(config.pinSalt, isNot(config.recoverySalt));
      expect(
        config.encryptedMasterKeyWithPin.nonce,
        isNot(config.encryptedMasterKeyWithRecovery.nonce),
      );
      expect(config.kdfAlgorithm, 'PBKDF2-HMAC-SHA256');
      expect(config.cipherAlgorithm, 'AES-256-GCM');
    },
  );

  test('rejects an incorrect PIN through authentication', () async {
    final SecurityConfig config = await service.createSecurityConfig(
      pin: '1234',
      normalizedRecoveryAnswer: 'mi perro',
      securityQuestionId: 'pet_name',
    );

    await expectLater(
      service.unwrapWithPin(config, '9999'),
      throwsA(isA<VaultFileCorruptedException>()),
    );
  });

  test('serialized configuration contains no PIN or recovery answer', () async {
    final SecurityConfig config = await service.createSecurityConfig(
      pin: '4826',
      normalizedRecoveryAnswer: 'respuesta privada',
      securityQuestionId: 'first_school',
    );
    final String encoded = config.toJsonString();
    final SecurityConfig decoded = SecurityConfig.fromJsonString(encoded);

    expect(encoded, isNot(contains('4826')));
    expect(encoded, isNot(contains('respuesta privada')));
    expect(decoded.securityQuestionId, 'first_school');
    expect(base64Decode(decoded.pinSalt), hasLength(16));
    expect(base64Decode(decoded.recoverySalt), hasLength(16));
  });
}
