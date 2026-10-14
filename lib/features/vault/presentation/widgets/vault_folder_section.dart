import 'package:flutter/material.dart';
import 'package:veyra/features/vault/domain/entities/vault_folder.dart';

final class VaultFolderSection extends StatelessWidget {
  const VaultFolderSection({
    required this.folders,
    required this.onOpen,
    required this.onDelete,
    super.key,
  });

  final List<VaultFolder> folders;
  final ValueChanged<VaultFolder> onOpen;
  final ValueChanged<VaultFolder> onDelete;

  @override
  Widget build(BuildContext context) {
    if (folders.isEmpty) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      height: 136,
      child: ListView.separated(
        key: const ValueKey<String>('vault-folders'),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        scrollDirection: Axis.horizontal,
        itemCount: folders.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final VaultFolder folder = folders[index];
          return SizedBox(
            width: 180,
            child: Card(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                key: ValueKey<String>('vault-folder-${folder.id}'),
                onTap: () => onOpen(folder),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 4, 8),
                  child: Row(
                    children: <Widget>[
                      const Icon(Icons.folder_outlined, size: 30),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              folder.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${folder.itemCount} ${folder.itemCount == 1 ? 'elemento' : 'elementos'}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      PopupMenuButton<String>(
                        key: ValueKey<String>(
                          'vault-folder-options-${folder.id}',
                        ),
                        tooltip: 'Opciones de carpeta',
                        onSelected: (_) => onDelete(folder),
                        itemBuilder: (context) =>
                            const <PopupMenuEntry<String>>[
                              PopupMenuItem<String>(
                                value: 'delete',
                                child: Text('Eliminar carpeta'),
                              ),
                            ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
