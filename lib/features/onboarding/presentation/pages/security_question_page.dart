import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:veyra/app/router/app_routes.dart';
import 'package:veyra/features/onboarding/domain/entities/security_question.dart';
import 'package:veyra/features/onboarding/presentation/cubit/onboarding_cubit.dart';
import 'package:veyra/features/onboarding/presentation/cubit/onboarding_state.dart';
import 'package:veyra/features/onboarding/presentation/widgets/onboarding_page_layout.dart';

final class SecurityQuestionPage extends StatelessWidget {
  const SecurityQuestionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OnboardingCubit, OnboardingState>(
      builder: (context, state) {
        return OnboardingPageLayout(
          title: 'Pregunta de seguridad',
          description: 'Elige una pregunta que solo tú puedas responder.',
          footer: FilledButton(
            key: const ValueKey<String>('continue-security-question'),
            onPressed: state.selectedQuestion == null
                ? null
                : () async {
                    await context.pushNamed(AppRoutes.securityAnswerName);
                  },
            child: const Text('Continuar'),
          ),
          child: ListView.separated(
            itemCount: SecurityQuestion.values.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final SecurityQuestion question = SecurityQuestion.values[index];
              final bool isSelected = state.selectedQuestion == question;
              return Card(
                child: ListTile(
                  key: ValueKey<String>('question-${question.id}'),
                  minTileHeight: 64,
                  title: Text(question.prompt),
                  trailing: isSelected
                      ? const Icon(Icons.check_circle_rounded)
                      : const Icon(Icons.circle_outlined),
                  selected: isSelected,
                  onTap: () =>
                      context.read<OnboardingCubit>().selectQuestion(question),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
