import 'package:flutter_test/flutter_test.dart';
import 'package:veyra/features/onboarding/domain/entities/security_question.dart';
import 'package:veyra/features/onboarding/domain/repositories/onboarding_repository.dart';
import 'package:veyra/features/onboarding/presentation/cubit/onboarding_cubit.dart';
import 'package:veyra/features/onboarding/presentation/cubit/onboarding_state.dart';

void main() {
  test('limits the PIN to four digits', () {
    final OnboardingCubit cubit = OnboardingCubit(FakeRepository());
    addTearDown(cubit.close);

    for (final int digit in <int>[1, 2, 3, 4, 5]) {
      cubit.addPinDigit(digit);
    }

    expect(cubit.state.pinLength, 4);
    expect(cubit.state.isPinComplete, isTrue);
  });

  test('rejects different PIN confirmations', () {
    final OnboardingCubit cubit = OnboardingCubit(FakeRepository());
    addTearDown(cubit.close);

    for (final int digit in <int>[1, 2, 3, 4]) {
      cubit.addPinDigit(digit);
    }
    for (final int digit in <int>[1, 2, 3, 5]) {
      cubit.addConfirmationDigit(digit);
    }

    expect(cubit.confirmPin(), isFalse);
    expect(cubit.state.confirmPinLength, 0);
    expect(cubit.state.validationError, OnboardingValidationError.pinMismatch);
  });

  test(
    'normalizes answers and clears temporary PIN state on success',
    () async {
      final FakeRepository repository = FakeRepository();
      final OnboardingCubit cubit = OnboardingCubit(repository);
      addTearDown(cubit.close);
      for (final int digit in <int>[1, 2, 3, 4]) {
        cubit.addPinDigit(digit);
        cubit.addConfirmationDigit(digit);
      }
      expect(cubit.confirmPin(), isTrue);
      cubit.selectQuestion(SecurityQuestion.petName);

      await cubit.submitAnswers(
        answer: '  Mi   Perro ',
        confirmation: 'mi perro',
      );

      expect(repository.normalizedAnswer, 'mi perro');
      expect(repository.pin, '1234');
      expect(cubit.state.pinLength, 0);
      expect(cubit.state.confirmPinLength, 0);
      expect(cubit.state.status, OnboardingSubmissionStatus.success);
    },
  );
}

final class FakeRepository implements OnboardingRepository {
  String? pin;
  String? normalizedAnswer;

  @override
  Future<void> complete({
    required String pin,
    required String normalizedRecoveryAnswer,
    required String securityQuestionId,
  }) async {
    this.pin = pin;
    normalizedAnswer = normalizedRecoveryAnswer;
  }

  @override
  Future<bool> isCompleted() async => false;
}
