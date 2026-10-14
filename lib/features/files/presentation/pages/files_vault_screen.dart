import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as path;
import 'package:veyra/core/errors/app_error_handler.dart';
import 'package:veyra/core/errors/app_error_message.dart';
import 'package:veyra/features/files/domain/entities/document_import_result.dart';
import 'package:veyra/features/files/presentation/cubit/document_import_cubit.dart';
import 'package:veyra/features/files/presentation/cubit/document_import_state.dart';
import 'package:veyra/features/files/presentation/pages/document_preview_screen.dart';
import 'package:veyra/features/files/presentation/widgets/vault_file_icon.dart';
import 'package:veyra/features/vault/domain/entities/vault_item.dart';
import 'package:veyra/features/vault/domain/services/external_file_destination.dart';
import 'package:veyra/features/vault/presentation/widgets/vault_content_state.dart';

enum _DocumentAction { preview, export, delete }

final class FilesVaultScreen extends StatelessWidget {
  const FilesVaultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DocumentImportCubit, DocumentImportState>(
      builder: (context, state) {
        final bool busy = <DocumentImportStatus>{
          DocumentImportStatus.picking,
          DocumentImportStatus.importing,
          DocumentImportStatus.exporting,
          DocumentImportStatus.deleting,
        }.contains(state.status);
        return Scaffold(
          appBar: AppBar(title: const Text('Archivos')),
          body: SafeArea(
            child: Column(
              children: <Widget>[
                if (state.status == DocumentImportStatus.importing) ...<Widget>[
                  LinearProgressIndicator(value: state.progress),
                  const SizedBox(height: 8),
                  Text('Importando ${state.completed} de ${state.total}'),
                ] else if (state.status == DocumentImportStatus.exporting ||
                    state.status == DocumentImportStatus.deleting)
                  const LinearProgressIndicator(),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: _buildList(context, state, busy),
                  ),
                ),
                if (state.items.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                    child: FilledButton.icon(
                      key: const ValueKey<String>('add-files'),
                      onPressed: busy ? null : () => _selectFiles(context),
                      icon: const Icon(Icons.note_add_outlined),
                      label: const Text('Agregar archivos'),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildList(
    BuildContext context,
    DocumentImportState state,
    bool busy,
  ) {
    if (state.status == DocumentImportStatus.loading && state.items.isEmpty) {
      return const VaultLoadingState(key: ValueKey<String>('files-loading'));
    }
    if (state.status == DocumentImportStatus.failure && state.items.isEmpty) {
      return VaultErrorState(
        key: const ValueKey<String>('files-error'),
        onRetry: context.read<DocumentImportCubit>().loadInitial,
      );
    }
    if (state.items.isEmpty) {
      return VaultEmptyState(
        key: const ValueKey<String>('files-vault-empty'),
        icon: Icons.folder_outlined,
        title: 'No tienes archivos ocultos',
        description:
            'Agrega archivos para guardarlos de forma segura en tu bóveda.',
        actionLabel: 'Agregar archivos',
        actionKey: const ValueKey<String>('add-files'),
        onAction: () => _selectFiles(context),
      );
    }
    final int itemCount = state.items.length + (state.hasMore ? 1 : 0);
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.extentAfter < 400) {
          unawaited(context.read<DocumentImportCubit>().loadMore());
        }
        return false;
      },
      child: ListView.separated(
        key: const ValueKey<String>('files-vault-list'),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: itemCount,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          if (index == state.items.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: SizedBox.square(
                  dimension: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }
          final VaultItem item = state.items[index];
          final DocumentImportCubit cubit = context.read<DocumentImportCubit>();
          return ListTile(
            key: ValueKey<String>('vault-file-${item.id}'),
            enabled: !busy,
            leading: VaultFileIcon(fileName: item.originalName),
            title: Text(item.originalName),
            subtitle: Text(_metadata(item)),
            isThreeLine: true,
            onTap: cubit.canPreview(item) && !busy
                ? () => _openPreview(context, item)
                : null,
            trailing: PopupMenuButton<_DocumentAction>(
              enabled: !busy,
              tooltip: 'Opciones',
              onSelected: (action) => _handleAction(context, item, action),
              itemBuilder: (context) => <PopupMenuEntry<_DocumentAction>>[
                if (cubit.canPreview(item))
                  const PopupMenuItem<_DocumentAction>(
                    value: _DocumentAction.preview,
                    child: Text('Vista previa'),
                  ),
                const PopupMenuItem<_DocumentAction>(
                  value: _DocumentAction.export,
                  child: Text('Sacar de la bóveda'),
                ),
                const PopupMenuItem<_DocumentAction>(
                  value: _DocumentAction.delete,
                  child: Text('Eliminar'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _handleAction(
    BuildContext context,
    VaultItem item,
    _DocumentAction action,
  ) async {
    switch (action) {
      case _DocumentAction.preview:
        await _openPreview(context, item);
      case _DocumentAction.export:
        await _export(context, item);
      case _DocumentAction.delete:
        await _delete(context, item);
    }
  }

  Future<void> _openPreview(BuildContext context, VaultItem item) async {
    final DocumentImportCubit cubit = context.read<DocumentImportCubit>();
    final bool? deleted = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (context) => DocumentPreviewScreen(
          item: item,
          textLoader: cubit.loadTextPreview,
          onDelete: cubit.delete,
        ),
      ),
    );
    if (context.mounted && deleted == true) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Archivo eliminado.')));
    }
  }

  Future<void> _export(BuildContext context, VaultItem item) async {
    final DocumentImportCubit cubit = context.read<DocumentImportCubit>();
    try {
      final ExternalFileWriteResult? result = await cubit.export(item);
      if (!context.mounted || result == null) {
        return;
      }
      final bool remove =
          await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Text('Archivo exportado'),
              content: const Text(
                'La escritura se verificó correctamente. '
                '¿Deseas quitar el original cifrado de la bóveda?',
              ),
              actions: <Widget>[
                TextButton(
                  key: const ValueKey<String>('keep-exported-vault-file'),
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Conservar en bóveda'),
                ),
                FilledButton(
                  key: const ValueKey<String>('remove-exported-vault-file'),
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Quitar de bóveda'),
                ),
              ],
            ),
          ) ??
          false;
      if (remove && context.mounted) {
        await cubit.delete(item);
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              remove
                  ? 'Archivo exportado y eliminado de la bóveda.'
                  : 'Archivo exportado correctamente.',
            ),
          ),
        );
      }
    } on Object catch (error, stackTrace) {
      AppErrorHandler.report(error, stackTrace);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppErrorMessage.forError(error))),
        );
      }
    }
  }

  Future<void> _delete(BuildContext context, VaultItem item) async {
    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Eliminar permanentemente'),
            content: const Text(
              'Este archivo será eliminado de la bóveda. '
              'Esta acción no se puede deshacer.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                key: const ValueKey<String>('confirm-delete-vault-file'),
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Eliminar'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !context.mounted) {
      return;
    }
    try {
      await context.read<DocumentImportCubit>().delete(item);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Archivo eliminado.')));
      }
    } on Object catch (error, stackTrace) {
      AppErrorHandler.report(error, stackTrace);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppErrorMessage.forError(error))),
        );
      }
    }
  }

  Future<void> _selectFiles(BuildContext context) async {
    final DocumentImportResult? result = await context
        .read<DocumentImportCubit>()
        .selectAndImport();
    if (!context.mounted || result == null) {
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          result.imported.isEmpty
              ? 'No se pudieron importar los archivos'
              : 'Importación completada',
        ),
        content: Text(
          '${result.imported.length} archivos guardados de forma segura.'
          '${result.failed.isEmpty ? '' : '\n${result.failed.length} no se pudieron importar.'}',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }

  String _metadata(VaultItem item) {
    final String extension = path
        .extension(item.originalName)
        .replaceFirst('.', '')
        .toUpperCase();
    final DateTime date = item.importedAt.toLocal();
    final String dateText =
        '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
    return '${extension.isEmpty ? 'ARCHIVO' : extension} • ${_formatSize(item.size)}\n'
        '${item.mimeType} • $dateText';
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
