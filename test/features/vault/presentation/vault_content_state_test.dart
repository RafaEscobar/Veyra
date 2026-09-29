import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:veyra/features/vault/presentation/widgets/vault_content_state.dart';

void main() {
  testWidgets('empty state explains how to add protected content', (
    tester,
  ) async {
    bool actionPressed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VaultEmptyState(
            icon: Icons.photo_library_outlined,
            title: 'No tienes imágenes ocultas',
            description: 'Agrega imágenes para guardarlas de forma segura.',
            actionLabel: 'Agregar imágenes',
            onAction: () => actionPressed = true,
          ),
        ),
      ),
    );

    expect(find.text('No tienes imágenes ocultas'), findsOneWidget);
    expect(
      find.text('Agrega imágenes para guardarlas de forma segura.'),
      findsOneWidget,
    );
    expect(find.text('Agregar imágenes'), findsOneWidget);
    await tester.tap(find.text('Agregar imágenes'));
    expect(actionPressed, isTrue);
  });

  testWidgets('error state offers a reachable retry action', (tester) async {
    bool retried = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: VaultErrorState(onRetry: () => retried = true)),
      ),
    );

    expect(find.text('No se pudo cargar el contenido.'), findsOneWidget);
    final Finder retry = find.byKey(
      const ValueKey<String>('retry-vault-content'),
    );
    expect(tester.getSize(retry).height, greaterThanOrEqualTo(48));
    await tester.tap(retry);

    expect(retried, isTrue);
  });
}
