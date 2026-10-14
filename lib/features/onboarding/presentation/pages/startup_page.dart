import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:veyra/app/router/app_routes.dart';
import 'package:veyra/core/errors/app_error_handler.dart';
import 'package:veyra/core/errors/debug_error_logs_button.dart';
import 'package:veyra/features/onboarding/domain/repositories/onboarding_repository.dart';

final class StartupPage extends StatefulWidget {
  const StartupPage({required this.repository, super.key});

  final OnboardingRepository repository;

  @override
  State<StartupPage> createState() => _StartupPageState();
}

final class _StartupPageState extends State<StartupPage> {
  Object? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_resolveInitialRoute());
  }

  Future<void> _resolveInitialRoute() async {
    try {
      final bool isCompleted = await widget.repository.isCompleted();
      if (!mounted) {
        return;
      }
      context.goNamed(
        isCompleted ? AppRoutes.unlockName : AppRoutes.welcomeName,
      );
    } on Object catch (error, stackTrace) {
      AppErrorHandler.report(error, stackTrace);
      if (mounted) {
        setState(() => _error = error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: _error == null
              ? const CircularProgressIndicator()
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Text('No fue posible iniciar Veyra.'),
                    const SizedBox(height: 8),
                    const DebugErrorLogsButton(),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () {
                        setState(() => _error = null);
                        unawaited(_resolveInitialRoute());
                      },
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
