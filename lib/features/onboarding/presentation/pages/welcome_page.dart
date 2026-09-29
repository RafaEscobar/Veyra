import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:veyra/app/router/app_routes.dart';
import 'package:veyra/app/theme/theme_toggle_button.dart';
import 'package:veyra/core/constants/app_constants.dart';
import 'package:veyra/features/onboarding/presentation/cubit/onboarding_cubit.dart';

final class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Stack(
            children: <Widget>[
              Align(
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      Icons.lock_outline_rounded,
                      size: 48,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      AppConstants.appName,
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tu bóveda privada en este dispositivo',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 32),
                    FilledButton(
                      key: const ValueKey<String>('start-onboarding'),
                      onPressed: () async {
                        context.read<OnboardingCubit>().reset();
                        await context.pushNamed(AppRoutes.createPinName);
                      },
                      child: const Text('Comenzar'),
                    ),
                  ],
                ),
              ),
              Align(alignment: Alignment.topRight, child: ThemeToggleButton()),
            ],
          ),
        ),
      ),
    );
  }
}
