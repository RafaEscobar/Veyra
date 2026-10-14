import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:veyra/app/router/app_routes.dart';
import 'package:veyra/app/theme/theme_toggle_button.dart';
import 'package:veyra/core/errors/debug_error_logs_button.dart';
import 'package:veyra/core/widgets/numeric_keypad.dart';
import 'package:veyra/core/widgets/pin_indicator.dart';
import 'package:veyra/features/authentication/presentation/cubit/unlock_cubit.dart';
import 'package:veyra/features/authentication/presentation/cubit/unlock_state.dart';

final class UnlockPage extends StatefulWidget {
  const UnlockPage({this.showRecoverySuccess = false, super.key});

  final bool showRecoverySuccess;

  @override
  State<UnlockPage> createState() => _UnlockPageState();
}

final class _UnlockPageState extends State<UnlockPage> {
  @override
  void initState() {
    super.initState();
    unawaited(context.read<UnlockCubit>().initialize());
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<UnlockCubit, UnlockState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, state) {
        if (state.status == UnlockStatus.unlocked) {
          context.goNamed(AppRoutes.vaultHomeName);
        }
      },
      builder: (context, state) {
        final UnlockCubit cubit = context.read<UnlockCubit>();
        return Scaffold(
          body: SafeArea(
            child: Stack(
              children: <Widget>[
                SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 32,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: MediaQuery.sizeOf(context).height - 64,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Icon(
                          Icons.lock_outline_rounded,
                          size: 56,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Mi bóveda',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Introduce tu NIP',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        if (widget.showRecoverySuccess) ...<Widget>[
                          const SizedBox(height: 16),
                          Semantics(
                            liveRegion: true,
                            child: Text(
                              'NIP actualizado correctamente.',
                              key: const ValueKey<String>('recovery-success'),
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        PinIndicator(filledCount: state.pinLength),
                        SizedBox(
                          height: 56,
                          child: Center(child: _StatusMessage(state: state)),
                        ),
                        NumericKeypad(
                          enabled: state.acceptsInput,
                          onDigitPressed: cubit.addDigit,
                          onDeletePressed: cubit.deleteDigit,
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          key: const ValueKey<String>('forgot-pin'),
                          onPressed: () async {
                            await context.pushNamed(AppRoutes.recoveryName);
                          },
                          child: const Text('¿Olvidaste tu NIP?'),
                        ),
                      ],
                    ),
                  ),
                ),
                const Positioned(
                  top: 8,
                  right: 8,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      DebugErrorLogsButton(),
                      ThemeToggleButton(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

final class _StatusMessage extends StatelessWidget {
  const _StatusMessage({required this.state});

  final UnlockState state;

  @override
  Widget build(BuildContext context) {
    final Color errorColor = Theme.of(context).colorScheme.error;
    return switch (state.status) {
      UnlockStatus.submitting => const SizedBox.square(
        dimension: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      UnlockStatus.wrongPin => Text(
        'NIP incorrecto. Inténtalo de nuevo.',
        key: const ValueKey<String>('wrong-pin-message'),
        style: TextStyle(color: errorColor),
        textAlign: TextAlign.center,
      ),
      UnlockStatus.locked => Text(
        'Demasiados intentos. Espera ${_formatTime(state.remainingLockSeconds)}.',
        key: const ValueKey<String>('lockout-message'),
        style: TextStyle(color: errorColor),
        textAlign: TextAlign.center,
      ),
      UnlockStatus.failure => Text(
        'No fue posible abrir la bóveda.',
        style: TextStyle(color: errorColor),
        textAlign: TextAlign.center,
      ),
      UnlockStatus.idle || UnlockStatus.unlocked => const SizedBox.shrink(),
    };
  }

  String _formatTime(int totalSeconds) {
    final int minutes = totalSeconds ~/ 60;
    final int seconds = totalSeconds % 60;
    if (minutes == 0) {
      return '$seconds s';
    }
    return '$minutes:${seconds.toString().padLeft(2, '0')} min';
  }
}
