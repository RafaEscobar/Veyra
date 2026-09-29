import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:veyra/app/router/app_routes.dart';
import 'package:veyra/core/widgets/numeric_keypad.dart';
import 'package:veyra/core/widgets/pin_indicator.dart';
import 'package:veyra/features/onboarding/presentation/cubit/onboarding_cubit.dart';
import 'package:veyra/features/onboarding/presentation/cubit/onboarding_state.dart';
import 'package:veyra/features/onboarding/presentation/widgets/onboarding_page_layout.dart';

final class CreatePinPage extends StatelessWidget {
  const CreatePinPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OnboardingCubit, OnboardingState>(
      builder: (context, state) {
        final OnboardingCubit cubit = context.read<OnboardingCubit>();
        return OnboardingPageLayout(
          title: 'Crea tu NIP',
          description: 'Usarás estos 4 dígitos para abrir tu bóveda.',
          footer: FilledButton(
            key: const ValueKey<String>('continue-create-pin'),
            onPressed: state.isPinComplete
                ? () async {
                    await context.pushNamed(AppRoutes.confirmPinName);
                  }
                : null,
            child: const Text('Continuar'),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              PinIndicator(filledCount: state.pinLength),
              const SizedBox(height: 32),
              NumericKeypad(
                onDigitPressed: cubit.addPinDigit,
                onDeletePressed: cubit.deletePinDigit,
              ),
            ],
          ),
        );
      },
    );
  }
}
