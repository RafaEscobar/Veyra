import 'package:flutter_test/flutter_test.dart';
import 'package:veyra/core/crypto/onboarding_crypto_service.dart';
import 'package:veyra/core/errors/app_exception.dart';
import 'package:veyra/core/security/lockout_policy.dart';
import 'package:veyra/core/security/security_config.dart';
import 'package:veyra/core/security/vault_session.dart';
import 'package:veyra/core/storage/secure_storage_service.dart';
import 'package:veyra/features/authentication/data/repositories/secure_authentication_repository.dart';
import 'package:veyra/features/authentication/domain/entities/auth_lock_state.dart';

void main() {
  late OnboardingCryptoService cryptoService;
  late MemorySecurityConfigStorage storage;
  late MutableClock clock;
  late VaultSession session;
  late SecureAuthenticationRepository repository;

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
    session = VaultSession();
    repository = SecureAuthenticationRepository(
      storage: storage,
      cryptoService: cryptoService,
      vaultSession: session,
      utcNow: clock.call,
    );
  });

  tearDown(() => session.lock());

  test('correct PIN opens an in-memory session and resets failures', () async {
    storage.value = storage.value.copyWith(failedAttempts: 3);

    await repository.unlock('1234');

    expect(session.isUnlocked, isTrue);
    expect(storage.value.failedAttempts, 0);
    expect(storage.value.lockUntil, isNull);
  });

  test('fifth failed attempt starts and persists a 30 second lock', () async {
    for (int attempt = 1; attempt < 5; attempt++) {
      await expectLater(
        repository.unlock('9999'),
        throwsA(isA<WrongPinException>()),
      );
    }

    await expectLater(
      repository.unlock('9999'),
      throwsA(isA<VaultLockedException>()),
    );

    expect(storage.value.failedAttempts, 5);
    expect(
      storage.value.lockUntil,
      clock.value.add(const Duration(seconds: 30)),
    );
  });

  test('lockout remains active in a new repository instance', () async {
    storage.value = storage.value.copyWith(
      failedAttempts: 5,
      lockUntil: clock.value.add(const Duration(seconds: 30)),
    );
    final SecureAuthenticationRepository restartedRepository =
        SecureAuthenticationRepository(
          storage: storage,
          cryptoService: cryptoService,
          vaultSession: VaultSession(),
          utcNow: clock.call,
        );

    final AuthLockState state = await restartedRepository.getLockState();

    expect(state.failedAttempts, 5);
    expect(state.lockUntil, clock.value.add(const Duration(seconds: 30)));
    await expectLater(
      restartedRepository.unlock('1234'),
      throwsA(isA<VaultLockedException>()),
    );
  });

  test('expired lock allows another authentication attempt', () async {
    storage.value = storage.value.copyWith(
      failedAttempts: 5,
      lockUntil: clock.value.add(const Duration(seconds: 30)),
    );
    clock.value = clock.value.add(const Duration(seconds: 31));

    final AuthLockState state = await repository.getLockState();

    expect(state.lockUntil, isNull);
    await repository.unlock('1234');
    expect(session.isUnlocked, isTrue);
  });

  test('lockout policy increases at each required tier', () {
    expect(LockoutPolicy.durationAfterFailure(4), isNull);
    expect(LockoutPolicy.durationAfterFailure(5), const Duration(seconds: 30));
    expect(LockoutPolicy.durationAfterFailure(9), isNull);
    expect(LockoutPolicy.durationAfterFailure(10), const Duration(minutes: 2));
    expect(LockoutPolicy.durationAfterFailure(15), const Duration(minutes: 10));
    expect(LockoutPolicy.durationAfterFailure(20), const Duration(minutes: 10));
  });
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
