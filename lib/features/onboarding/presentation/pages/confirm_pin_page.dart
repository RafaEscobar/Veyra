import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:veyra/app/router/app_routes.dart';
import 'package:veyra/core/widgets/numeric_keypad.dart';
import 'package:veyra/core/widgets/pin_indicator.dart';
import 'package:veyra/features/onboarding/presentation/cubit/onboarding_cubit.dart';
import 'package:veyra/features/onboarding/presentation/cubit/onboarding_state.dart';
import 'package:veyra/features/onboarding/presentation/widgets/onboarding_page_layout.dart';

final class ConfirmPinPage extends StatelessWidget {
  const ConfirmPinPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OnboardingCubit, OnboardingState>(
      builder: (context, state) {
        final OnboardingCubit cubit = context.read<OnboardingCubit>();
        final bool hasMismatch =
            state.validationError == OnboardingValidationError.pinMismatch;

        return OnboardingPageLayout(
          title: 'Confirma tu NIP',
          description: 'Introduce nuevamente los mismos 4 dígitos.',
          footer: FilledButton(
            key: const ValueKey<String>('continue-confirm-pin'),
            onPressed: state.isConfirmationComplete
                ? () async {
                    if (cubit.confirmPin()) {
                      await context.pushNamed(AppRoutes.securityQuestionName);
                    }
                  }
                : null,
            child: const Text('Continuar'),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              PinIndicator(filledCount: state.confirmPinLength),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                child: hasMismatch
                    ? Padding(
                        key: const ValueKey<String>('pin-mismatch'),
                        padding: const EdgeInsets.only(top: 16),
                        child: Text(
                          'Los NIP no coinciden. Inténtalo de nuevo.',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : const SizedBox(height: 16),
              ),
              const SizedBox(height: 16),
              NumericKeypad(
                onDigitPressed: cubit.addConfirmationDigit,
                onDeletePressed: cubit.deleteConfirmationDigit,
              ),
            ],
          ),
        );
      },
    );
  }
}
