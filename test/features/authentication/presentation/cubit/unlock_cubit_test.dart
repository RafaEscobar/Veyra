import 'package:flutter_test/flutter_test.dart';
import 'package:veyra/core/errors/app_exception.dart';
import 'package:veyra/core/performance/performance_monitor.dart';
import 'package:veyra/features/authentication/domain/entities/auth_lock_state.dart';
import 'package:veyra/features/authentication/domain/repositories/authentication_repository.dart';
import 'package:veyra/features/authentication/presentation/cubit/unlock_cubit.dart';
import 'package:veyra/features/authentication/presentation/cubit/unlock_state.dart';

void main() {
  test('clears the PIN and reports an incorrect attempt', () async {
    final FakeAuthenticationRepository repository =
        FakeAuthenticationRepository(wrongPin: true);
    final UnlockCubit cubit = UnlockCubit(repository);
    addTearDown(cubit.close);

    for (final int digit in <int>[9, 9, 9, 9]) {
      cubit.addDigit(digit);
    }
    await _flushAsyncWork();

    expect(cubit.state.pinLength, 0);
    expect(cubit.state.status, UnlockStatus.wrongPin);
    expect(cubit.state.failedAttempts, 1);
  });

  test('reports unlocked after a correct PIN', () async {
    final List<PerformanceOperation> measurements = <PerformanceOperation>[];
    final UnlockCubit cubit = UnlockCubit(
      FakeAuthenticationRepository(),
      performanceMonitor: PerformanceMonitor(
        onMeasurement: (operation, _) => measurements.add(operation),
      ),
    );
    addTearDown(cubit.close);

    for (final int digit in <int>[1, 2, 3, 4]) {
      cubit.addDigit(digit);
    }
    await _flushAsyncWork();

    expect(cubit.state.pinLength, 0);
    expect(cubit.state.status, UnlockStatus.unlocked);
    expect(measurements, <PerformanceOperation>[
      PerformanceOperation.vaultUnlock,
    ]);
  });

  test('restores a persisted lockout on initialization', () async {
    final DateTime now = DateTime.utc(2026, 9, 26, 12);
    final UnlockCubit cubit = UnlockCubit(
      FakeAuthenticationRepository(
        lockState: AuthLockState(
          failedAttempts: 5,
          lockUntil: now.add(const Duration(seconds: 30)),
        ),
      ),
      utcNow: () => now,
    );
    addTearDown(cubit.close);

    await cubit.initialize();

    expect(cubit.state.status, UnlockStatus.locked);
    expect(cubit.state.remainingLockSeconds, 30);
    expect(cubit.state.acceptsInput, isFalse);
  });
}

Future<void> _flushAsyncWork() async {
  await Future<void>.delayed(Duration.zero);
}

final class FakeAuthenticationRepository implements AuthenticationRepository {
  FakeAuthenticationRepository({
    this.wrongPin = false,
    this.lockState = const AuthLockState(failedAttempts: 0, lockUntil: null),
  });

  final bool wrongPin;
  final AuthLockState lockState;

  @override
  Future<AuthLockState> getLockState() async => lockState;

  @override
  Future<void> unlock(String pin) async {
    if (wrongPin) {
      throw const WrongPinException(failedAttempts: 1);
    }
  }
}
