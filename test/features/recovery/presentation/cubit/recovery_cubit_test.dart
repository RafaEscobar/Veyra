import 'package:flutter_test/flutter_test.dart';
import 'package:veyra/core/errors/app_exception.dart';
import 'package:veyra/features/recovery/domain/entities/recovery_info.dart';
import 'package:veyra/features/recovery/domain/repositories/recovery_repository.dart';
import 'package:veyra/features/recovery/presentation/cubit/recovery_cubit.dart';
import 'package:veyra/features/recovery/presentation/cubit/recovery_state.dart';

void main() {
  test('normalizes a valid answer and advances to new PIN', () async {
    final FakeRecoveryRepository repository = FakeRecoveryRepository();
    final RecoveryCubit cubit = RecoveryCubit(repository);
    addTearDown(cubit.close);
    await cubit.initialize();

    await cubit.verifyAnswer('  Mi   Perro ');

    expect(repository.answer, 'mi perro');
    expect(cubit.state.step, RecoveryStep.newPin);
    expect(cubit.state.status, RecoveryStatus.ready);
  });

  test('rejects different new PIN confirmations', () async {
    final FakeRecoveryRepository repository = FakeRecoveryRepository();
    final RecoveryCubit cubit = RecoveryCubit(repository);
    addTearDown(cubit.close);
    await cubit.initialize();
    await cubit.verifyAnswer('mi perro');
    for (final int digit in <int>[5, 6, 7, 8]) {
      cubit.addNewPinDigit(digit);
    }
    cubit.continueToConfirmation();
    for (final int digit in <int>[5, 6, 7, 9]) {
      cubit.addConfirmationDigit(digit);
    }

    await cubit.saveNewPin();

    expect(cubit.state.validationError, RecoveryValidationError.pinMismatch);
    expect(cubit.state.confirmPinLength, 0);
    expect(repository.newPin, isNull);
  });

  test('restores a persisted recovery lockout', () async {
    final DateTime now = DateTime.utc(2026, 9, 26, 12);
    final RecoveryCubit cubit = RecoveryCubit(
      FakeRecoveryRepository(
        info: RecoveryInfo(
          questionPrompt: 'Pregunta',
          failedAttempts: 5,
          lockUntil: now.add(const Duration(seconds: 30)),
        ),
      ),
      utcNow: () => now,
    );
    addTearDown(cubit.close);

    await cubit.initialize();

    expect(cubit.state.status, RecoveryStatus.locked);
    expect(cubit.state.remainingLockSeconds, 30);
    expect(cubit.state.questionPrompt, 'Pregunta');
  });
}

final class FakeRecoveryRepository implements RecoveryRepository {
  FakeRecoveryRepository({
    this.info = const RecoveryInfo(
      questionPrompt: 'Pregunta',
      failedAttempts: 0,
      lockUntil: null,
    ),
    this.wrongAnswer = false,
  });

  final RecoveryInfo info;
  final bool wrongAnswer;
  String? answer;
  String? newPin;

  @override
  void cancel() {}

  @override
  Future<RecoveryInfo> getInfo() async => info;

  @override
  Future<void> replacePin(String newPin) async {
    this.newPin = newPin;
  }

  @override
  Future<void> verifyAnswer(String normalizedAnswer) async {
    if (wrongAnswer) {
      throw const WrongRecoveryAnswerException(failedAttempts: 1);
    }
    answer = normalizedAnswer;
  }
}
