import 'package:flutter/material.dart';

final class VaultCategoryScreen extends StatelessWidget {
  const VaultCategoryScreen({required this.title, super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Text(
          'Aún no hay elementos',
          key: ValueKey<String>('empty-${title.toLowerCase()}'),
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}
