import 'package:flutter/material.dart';
import 'package:veyra/features/vault/domain/entities/vault_folder.dart';

final class VaultFolderDestination {
  const VaultFolderDestination(this.folderId);

  final String? folderId;
}

Future<String?> showCreateVaultFolderDialog(BuildContext context) async {
  return showDialog<String>(
    context: context,
    builder: (context) => const _CreateVaultFolderDialog(),
  );
}

final class _CreateVaultFolderDialog extends StatefulWidget {
  const _CreateVaultFolderDialog();

  @override
  State<_CreateVaultFolderDialog> createState() =>
      _CreateVaultFolderDialogState();
}

final class _CreateVaultFolderDialogState
    extends State<_CreateVaultFolderDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nueva carpeta'),
      content: TextField(
        key: const ValueKey<String>('vault-folder-name'),
        controller: _controller,
        autofocus: true,
        maxLength: 60,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          labelText: 'Nombre',
          hintText: 'Ej. Fondos de pantalla',
        ),
        onSubmitted: (value) {
          if (value.trim().isNotEmpty) {
            Navigator.of(context).pop(value.trim());
          }
        },
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const ValueKey<String>('confirm-create-vault-folder'),
          onPressed: () {
            final String value = _controller.text.trim();
            if (value.isNotEmpty) {
              Navigator.of(context).pop(value);
            }
          },
          child: const Text('Crear'),
        ),
      ],
    );
  }
}

Future<VaultFolderDestination?> showMoveToVaultFolderDialog(
  BuildContext context, {
  required List<VaultFolder> folders,
  required String? currentFolderId,
}) {
  return showDialog<VaultFolderDestination>(
    context: context,
    builder: (context) => SimpleDialog(
      title: const Text('Mover a'),
      children: <Widget>[
        if (currentFolderId != null)
          SimpleDialogOption(
            key: const ValueKey<String>('move-to-vault-root'),
            onPressed: () =>
                Navigator.of(context).pop(const VaultFolderDestination(null)),
            child: const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.home_outlined),
              title: Text('Sin carpeta'),
            ),
          ),
        for (final VaultFolder folder in folders)
          if (folder.id != currentFolderId)
            SimpleDialogOption(
              key: ValueKey<String>('move-to-vault-folder-${folder.id}'),
              onPressed: () =>
                  Navigator.of(context).pop(VaultFolderDestination(folder.id)),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.folder_outlined),
                title: Text(folder.name),
              ),
            ),
      ],
    ),
  );
}

Future<bool> confirmDeleteVaultFolder(
  BuildContext context,
  VaultFolder folder,
) async {
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Eliminar carpeta'),
          content: Text(
            'Se eliminará “${folder.name}”. Sus elementos volverán a la vista principal.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              key: const ValueKey<String>('confirm-delete-vault-folder'),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Eliminar carpeta'),
            ),
          ],
        ),
      ) ??
      false;
}
