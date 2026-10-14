import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:veyra/features/vault/domain/entities/vault_folder.dart';
import 'package:veyra/features/vault/domain/entities/vault_item.dart';
import 'package:veyra/features/vault/presentation/widgets/vault_folder_dialogs.dart';
import 'package:veyra/features/vault/presentation/widgets/vault_folder_section.dart';

void main() {
  final VaultFolder folder = VaultFolder(
    id: 'wallpapers',
    name: 'Fondos de pantalla',
    type: VaultItemType.image,
    createdAt: DateTime(2026, 10, 14),
    itemCount: 3,
  );

  testWidgets('shows a folder and exposes open and delete actions', (
    tester,
  ) async {
    VaultFolder? opened;
    VaultFolder? deleted;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VaultFolderSection(
            folders: <VaultFolder>[folder],
            onOpen: (value) => opened = value,
            onDelete: (value) => deleted = value,
          ),
        ),
      ),
    );

    expect(find.text('Fondos de pantalla'), findsOneWidget);
    expect(find.text('3 elementos'), findsOneWidget);
    tester
        .widget<InkWell>(
          find.byKey(const ValueKey<String>('vault-folder-wallpapers')),
        )
        .onTap!();
    expect(opened, folder);

    await tester.tap(
      find.byKey(const ValueKey<String>('vault-folder-options-wallpapers')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eliminar carpeta'));
    expect(deleted, folder);
  });

  testWidgets('creates a trimmed folder name', (tester) async {
    String? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () async {
              result = await showCreateVaultFolderDialog(context);
            },
            child: const Text('Abrir'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey<String>('vault-folder-name')),
      '  Recibos  ',
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('confirm-create-vault-folder')),
    );
    await tester.pumpAndSettle();

    expect(result, 'Recibos');
  });

  testWidgets('offers the root when moving an item out of a folder', (
    tester,
  ) async {
    VaultFolderDestination? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () async {
              result = await showMoveToVaultFolderDialog(
                context,
                folders: <VaultFolder>[folder],
                currentFolderId: folder.id,
              );
            },
            child: const Text('Mover'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Mover'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('move-to-vault-root')));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result?.folderId, isNull);
  });
}
