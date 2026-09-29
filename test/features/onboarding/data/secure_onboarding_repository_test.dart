import 'package:flutter_test/flutter_test.dart';
import 'package:veyra/core/crypto/onboarding_crypto_service.dart';
import 'package:veyra/core/security/security_config.dart';
import 'package:veyra/core/storage/secure_storage_service.dart';
import 'package:veyra/features/onboarding/data/repositories/secure_onboarding_repository.dart';

void main() {
  test('marks onboarding complete only after saving a valid config', () async {
    final MemorySecurityConfigStorage storage = MemorySecurityConfigStorage();
    final SecureOnboardingRepository repository = SecureOnboardingRepository(
      storage: storage,
      cryptoService: OnboardingCryptoService(kdfIterations: 1000),
    );

    expect(await repository.isCompleted(), isFalse);

    await repository.complete(
      pin: '1234',
      normalizedRecoveryAnswer: 'mi perro',
      securityQuestionId: 'pet_name',
    );

    expect(await repository.isCompleted(), isTrue);
    expect(storage.value?.securityQuestionId, 'pet_name');
    expect(storage.value?.failedAttempts, 0);
  });
}

final class MemorySecurityConfigStorage implements SecurityConfigStorage {
  SecurityConfig? value;

  @override
  Future<bool> hasSecurityConfig() async => value != null;

  @override
  Future<SecurityConfig?> readSecurityConfig() async => value;

  @override
  Future<void> writeSecurityConfig(SecurityConfig config) async {
    value = config;
  }
}
