import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:veyra/app/router/app_routes.dart';
import 'package:veyra/features/onboarding/presentation/cubit/onboarding_cubit.dart';
import 'package:veyra/features/onboarding/presentation/cubit/onboarding_state.dart';
import 'package:veyra/features/onboarding/presentation/widgets/onboarding_page_layout.dart';

final class SecurityAnswerPage extends StatefulWidget {
  const SecurityAnswerPage({super.key});

  @override
  State<SecurityAnswerPage> createState() => _SecurityAnswerPageState();
}

final class _SecurityAnswerPageState extends State<SecurityAnswerPage> {
  final TextEditingController _answerController = TextEditingController();
  final TextEditingController _confirmationController = TextEditingController();

  @override
  void dispose() {
    _answerController.clear();
    _confirmationController.clear();
    _answerController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<OnboardingCubit, OnboardingState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, state) {
        if (state.status == OnboardingSubmissionStatus.success) {
          _answerController.clear();
          _confirmationController.clear();
          context.goNamed(AppRoutes.setupCompleteName);
        }
      },
      builder: (context, state) {
        final bool isSubmitting =
            state.status == OnboardingSubmissionStatus.submitting;
        return OnboardingPageLayout(
          title: 'Respuesta de seguridad',
          description:
              state.selectedQuestion?.prompt ??
              'Escribe y confirma tu respuesta.',
          footer: FilledButton(
            key: const ValueKey<String>('finish-onboarding'),
            onPressed: isSubmitting ? null : _submit,
            child: isSubmitting
                ? const SizedBox.square(
                    dimension: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Crear bóveda'),
          ),
          child: ListView(
            children: <Widget>[
              TextField(
                key: const ValueKey<String>('security-answer'),
                controller: _answerController,
                enabled: !isSubmitting,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Respuesta',
                  helperText: 'La respuesta no se guardará en texto plano.',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                key: const ValueKey<String>('security-answer-confirmation'),
                controller: _confirmationController,
                enabled: !isSubmitting,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                textInputAction: TextInputAction.done,
                onSubmitted: isSubmitting ? null : (_) => _submit(),
                decoration: const InputDecoration(
                  labelText: 'Confirma tu respuesta',
                ),
              ),
              if (state.validationError != null) ...<Widget>[
                const SizedBox(height: 16),
                Text(
                  _errorMessage(state.validationError!),
                  key: const ValueKey<String>('onboarding-error'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _submit() {
    return context.read<OnboardingCubit>().submitAnswers(
      answer: _answerController.text,
      confirmation: _confirmationController.text,
    );
  }

  String _errorMessage(OnboardingValidationError error) {
    return switch (error) {
      OnboardingValidationError.answerRequired =>
        'Escribe una respuesta antes de continuar.',
      OnboardingValidationError.answerMismatch =>
        'Las respuestas no coinciden.',
      OnboardingValidationError.setupFailed =>
        'No fue posible crear la bóveda. Vuelve a configurar tu NIP.',
      OnboardingValidationError.pinMismatch => 'Los NIP no coinciden.',
      OnboardingValidationError.questionRequired =>
        'Selecciona una pregunta de seguridad.',
    };
  }
}
