import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:veyra/core/crypto/onboarding_crypto_service.dart';
import 'package:veyra/core/security/security_config.dart';
import 'package:veyra/core/storage/flutter_secure_storage_service.dart';

void main() {
  const FlutterSecureStorage rawStorage = FlutterSecureStorage();
  const FlutterSecureStorageService service = FlutterSecureStorageService(
    rawStorage,
  );

  setUp(() {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
  });

  test('persists and restores the selected theme', () async {
    expect(await service.readThemeMode(), isNull);

    await service.writeThemeMode(ThemeMode.dark);

    expect(await service.readThemeMode(), ThemeMode.dark);
    expect(
      await const FlutterSecureStorageService().readThemeMode(),
      ThemeMode.dark,
    );
  });

  test('persists the complete security state as one atomic record', () async {
    final OnboardingCryptoService cryptoService = OnboardingCryptoService(
      kdfIterations: 1000,
    );
    final SecurityConfig config = await cryptoService.createSecurityConfig(
      pin: '4826',
      normalizedRecoveryAnswer: 'respuesta privada',
      securityQuestionId: 'first_school',
    );

    expect(await service.hasSecurityConfig(), isFalse);
    await service.writeSecurityConfig(config);
    final SecurityConfig? restored = await service.readSecurityConfig();

    expect(await service.hasSecurityConfig(), isTrue);
    expect(restored?.securityQuestionId, 'first_school');
    expect(restored?.failedAttempts, 0);
    expect(restored?.recoveryFailedAttempts, 0);
    expect(restored?.encryptedMasterKeyWithPin.mac, isNotEmpty);
    expect(restored?.encryptedMasterKeyWithRecovery.mac, isNotEmpty);
  });

  test('stores no PIN, answer, or clear master key', () async {
    final OnboardingCryptoService cryptoService = OnboardingCryptoService(
      kdfIterations: 1000,
    );
    final SecurityConfig config = await cryptoService.createSecurityConfig(
      pin: '4826',
      normalizedRecoveryAnswer: 'respuesta privada',
      securityQuestionId: 'first_school',
    );
    final Uint8List masterKey = await cryptoService.unwrapWithPin(
      config,
      '4826',
    );
    final String encodedMasterKey = base64Encode(masterKey);

    await service.writeSecurityConfig(config);
    final Map<String, String> storedValues = await rawStorage.readAll();
    final String serializedStorage = storedValues.values.join('\n');

    expect(serializedStorage, isNot(contains('4826')));
    expect(serializedStorage, isNot(contains('respuesta privada')));
    expect(serializedStorage, isNot(contains(encodedMasterKey)));

    masterKey.fillRange(0, masterKey.length, 0);
  });
}
