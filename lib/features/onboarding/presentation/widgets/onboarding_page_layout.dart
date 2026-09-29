import 'package:flutter/material.dart';

final class OnboardingPageLayout extends StatelessWidget {
  const OnboardingPageLayout({
    required this.title,
    required this.description,
    required this.child,
    required this.footer,
    super.key,
  });

  final String title;
  final String description;
  final Widget child;
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(title, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text(
                description,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              Expanded(child: child),
              const SizedBox(height: 16),
              footer,
            ],
          ),
        ),
      ),
    );
  }
}
