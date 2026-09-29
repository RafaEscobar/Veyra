import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:veyra/app/router/app_routes.dart';
import 'package:veyra/core/widgets/numeric_keypad.dart';
import 'package:veyra/core/widgets/pin_indicator.dart';
import 'package:veyra/features/authentication/presentation/cubit/unlock_cubit.dart';
import 'package:veyra/features/recovery/presentation/cubit/recovery_cubit.dart';
import 'package:veyra/features/recovery/presentation/cubit/recovery_state.dart';

final class RecoveryPage extends StatefulWidget {
  const RecoveryPage({super.key});

  @override
  State<RecoveryPage> createState() => _RecoveryPageState();
}

final class _RecoveryPageState extends State<RecoveryPage> {
  final TextEditingController _answerController = TextEditingController();

  @override
  void initState() {
    super.initState();
    unawaited(context.read<RecoveryCubit>().initialize());
  }

  @override
  void dispose() {
    _answerController.clear();
    _answerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<RecoveryCubit, RecoveryState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, state) {
        if (state.status == RecoveryStatus.completed) {
          unawaited(context.read<UnlockCubit>().initialize());
          context.goNamed(
            AppRoutes.unlockName,
            queryParameters: const <String, String>{'recovered': '1'},
          );
        }
      },
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(title: const Text('Recuperar acceso')),
          body: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: switch (state.status) {
                RecoveryStatus.loading => const Center(
                  child: CircularProgressIndicator(),
                ),
                RecoveryStatus.failure => const _RecoveryFailure(),
                _ => _RecoveryContent(
                  state: state,
                  answerController: _answerController,
                ),
              },
            ),
          ),
        );
      },
    );
  }
}

final class _RecoveryContent extends StatelessWidget {
  const _RecoveryContent({required this.state, required this.answerController});

  final RecoveryState state;
  final TextEditingController answerController;

  @override
  Widget build(BuildContext context) {
    return switch (state.step) {
      RecoveryStep.answer => _AnswerStep(
        state: state,
        controller: answerController,
      ),
      RecoveryStep.newPin => _NewPinStep(state: state),
      RecoveryStep.confirmPin => _ConfirmPinStep(state: state),
    };
  }
}

final class _AnswerStep extends StatelessWidget {
  const _AnswerStep({required this.state, required this.controller});

  final RecoveryState state;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final bool isSubmitting = state.status == RecoveryStatus.submitting;
    final bool isLocked = state.status == RecoveryStatus.locked;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'Pregunta de seguridad',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 20),
        Text(
          state.questionPrompt,
          key: const ValueKey<String>('recovery-question'),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 24),
        TextField(
          key: const ValueKey<String>('recovery-answer'),
          controller: controller,
          enabled: state.acceptsAnswer,
          obscureText: true,
          autocorrect: false,
          enableSuggestions: false,
          textInputAction: TextInputAction.done,
          onSubmitted: state.acceptsAnswer
              ? (_) async {
                  await _verify(context);
                }
              : null,
          decoration: const InputDecoration(labelText: 'Respuesta'),
        ),
        const SizedBox(height: 16),
        if (state.validationError == RecoveryValidationError.answerRequired)
          const _ErrorText('Escribe una respuesta antes de continuar.'),
        if (state.status == RecoveryStatus.wrongAnswer)
          const _ErrorText('La respuesta no es correcta.'),
        if (isLocked)
          _ErrorText(
            'Demasiados intentos. Espera ${_formatTime(state.remainingLockSeconds)}.',
            key: const ValueKey<String>('recovery-lockout-message'),
          ),
        const Spacer(),
        FilledButton(
          key: const ValueKey<String>('verify-recovery-answer'),
          onPressed: state.acceptsAnswer
              ? () async {
                  await _verify(context);
                }
              : null,
          child: isSubmitting
              ? const SizedBox.square(
                  dimension: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Verificar respuesta'),
        ),
      ],
    );
  }

  Future<void> _verify(BuildContext context) async {
    final String answer = controller.text;
    controller.clear();
    await context.read<RecoveryCubit>().verifyAnswer(answer);
  }
}

final class _NewPinStep extends StatelessWidget {
  const _NewPinStep({required this.state});

  final RecoveryState state;

  @override
  Widget build(BuildContext context) {
    final RecoveryCubit cubit = context.read<RecoveryCubit>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'Crea un NIP nuevo',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        const Text('Usarás estos 4 dígitos para abrir tu bóveda.'),
        const Spacer(),
        PinIndicator(filledCount: state.pinLength),
        const SizedBox(height: 28),
        Center(
          child: NumericKeypad(
            onDigitPressed: cubit.addNewPinDigit,
            onDeletePressed: cubit.deleteNewPinDigit,
          ),
        ),
        const Spacer(),
        FilledButton(
          key: const ValueKey<String>('continue-recovery-pin'),
          onPressed: state.isPinComplete ? cubit.continueToConfirmation : null,
          child: const Text('Continuar'),
        ),
      ],
    );
  }
}

final class _ConfirmPinStep extends StatelessWidget {
  const _ConfirmPinStep({required this.state});

  final RecoveryState state;

  @override
  Widget build(BuildContext context) {
    final RecoveryCubit cubit = context.read<RecoveryCubit>();
    final bool isSubmitting = state.status == RecoveryStatus.submitting;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'Confirma tu NIP nuevo',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        const Text('Introduce nuevamente los mismos 4 dígitos.'),
        const Spacer(),
        PinIndicator(filledCount: state.confirmPinLength),
        if (state.validationError == RecoveryValidationError.pinMismatch)
          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: _ErrorText('Los NIP no coinciden.'),
          ),
        const SizedBox(height: 12),
        Center(
          child: NumericKeypad(
            enabled: !isSubmitting,
            onDigitPressed: cubit.addConfirmationDigit,
            onDeletePressed: cubit.deleteConfirmationDigit,
          ),
        ),
        const Spacer(),
        FilledButton(
          key: const ValueKey<String>('save-recovery-pin'),
          onPressed: state.isConfirmationComplete && !isSubmitting
              ? () async {
                  await cubit.saveNewPin();
                }
              : null,
          child: isSubmitting
              ? const SizedBox.square(
                  dimension: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Guardar NIP'),
        ),
      ],
    );
  }
}

final class _ErrorText extends StatelessWidget {
  const _ErrorText(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      style: TextStyle(color: Theme.of(context).colorScheme.error),
      textAlign: TextAlign.center,
    );
  }
}

final class _RecoveryFailure extends StatelessWidget {
  const _RecoveryFailure();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'No fue posible iniciar la recuperación.',
        textAlign: TextAlign.center,
      ),
    );
  }
}

String _formatTime(int totalSeconds) {
  final int minutes = totalSeconds ~/ 60;
  final int seconds = totalSeconds % 60;
  if (minutes == 0) {
    return '$seconds s';
  }
  return '$minutes:${seconds.toString().padLeft(2, '0')} min';
}
