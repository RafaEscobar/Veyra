import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:veyra/app/router/app_routes.dart';

final class SetupCompletePage extends StatelessWidget {
  const SetupCompletePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  Icons.verified_user_outlined,
                  size: 64,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  'Tu bóveda está lista',
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'La configuración de seguridad se guardó en este dispositivo.',
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                FilledButton(
                  onPressed: () => context.goNamed(AppRoutes.unlockName),
                  child: const Text('Abrir mi bóveda'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
