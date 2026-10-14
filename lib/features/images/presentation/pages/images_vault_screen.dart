import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:veyra/core/errors/app_error_handler.dart';
import 'package:veyra/core/errors/app_error_message.dart';
import 'package:veyra/core/errors/debug_error_logs_screen.dart';
import 'package:veyra/features/images/domain/entities/gallery_image.dart';
import 'package:veyra/features/images/domain/entities/image_import_result.dart';
import 'package:veyra/features/images/domain/repositories/image_library_repository.dart';
import 'package:veyra/features/images/presentation/cubit/image_import_cubit.dart';
import 'package:veyra/features/images/presentation/cubit/image_import_state.dart';
import 'package:veyra/features/images/presentation/pages/image_asset_picker_screen.dart';
import 'package:veyra/features/images/presentation/pages/image_viewer_screen.dart';
import 'package:veyra/features/vault/domain/entities/vault_item.dart';
import 'package:veyra/features/vault/presentation/widgets/vault_content_state.dart';

enum _ImageAction { export, delete }

final class ImagesVaultScreen extends StatelessWidget {
  const ImagesVaultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ImageImportCubit, ImageImportState>(
      builder: (context, state) {
        final bool importing = state.status == ImageImportStatus.importing;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Imágenes'),
            actions: <Widget>[
              IconButton(
                key: const ValueKey<String>('toggle-image-names'),
                onPressed: context.read<ImageImportCubit>().toggleNames,
                tooltip: state.showNames
                    ? 'Ocultar nombres'
                    : 'Mostrar nombres',
                icon: Icon(
                  state.showNames
                      ? Icons.label_off_outlined
                      : Icons.label_outline,
                ),
              ),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: <Widget>[
                if (importing) ...<Widget>[
                  LinearProgressIndicator(value: state.progress),
                  const SizedBox(height: 8),
                  Text('Importando ${state.completed} de ${state.total}'),
                ],
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: _buildGrid(context, state),
                  ),
                ),
                if (state.items.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                    child: FilledButton.icon(
                      key: const ValueKey<String>('add-images'),
                      onPressed: importing
                          ? null
                          : () => _selectImages(context),
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      label: const Text('Agregar imágenes'),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildGrid(BuildContext context, ImageImportState state) {
    if (state.status == ImageImportStatus.loading && state.items.isEmpty) {
      return const VaultLoadingState(key: ValueKey<String>('images-loading'));
    }
    if (state.status == ImageImportStatus.failure && state.items.isEmpty) {
      return VaultErrorState(
        key: const ValueKey<String>('images-error'),
        onRetry: context.read<ImageImportCubit>().loadInitial,
      );
    }
    if (state.items.isEmpty) {
      return VaultEmptyState(
        key: const ValueKey<String>('images-vault-count'),
        icon: Icons.photo_library_outlined,
        title: 'No tienes imágenes ocultas',
        description:
            'Agrega imágenes para guardarlas de forma segura en tu bóveda.',
        actionLabel: 'Agregar imágenes',
        actionKey: const ValueKey<String>('add-images'),
        onAction: () => _selectImages(context),
      );
    }
    final int itemCount = state.items.length + (state.hasMore ? 1 : 0);
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.extentAfter < 500) {
          unawaited(context.read<ImageImportCubit>().loadMore());
        }
        return false;
      },
      child: GridView.builder(
        key: const ValueKey<String>('images-vault-grid'),
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: itemCount,
        itemBuilder: (context, index) {
          if (index == state.items.length) {
            return const Center(
              child: SizedBox.square(
                dimension: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          }
          return _VaultImageTile(
            item: state.items[index],
            showName: state.showNames,
            thumbnailLoader: context.read<ImageImportCubit>().loadThumbnail,
            onOpen: () => _openViewer(context, state.items[index]),
            onAction: (action) =>
                _handleAction(context, state.items[index], action),
          );
        },
      ),
    );
  }

  Future<void> _openViewer(BuildContext context, VaultItem item) async {
    final ImageImportCubit cubit = context.read<ImageImportCubit>();
    final String? result = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (context) => ImageViewerScreen(
          item: item,
          imageLoader: cubit.loadImage,
          onDelete: cubit.delete,
          onExport: cubit.exportAndRemove,
        ),
      ),
    );
    if (context.mounted && result != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result == 'delete'
                ? 'Imagen eliminada.'
                : 'Imagen guardada en la galería.',
          ),
        ),
      );
    }
  }

  Future<void> _handleAction(
    BuildContext context,
    VaultItem item,
    _ImageAction action,
  ) async {
    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              action == _ImageAction.delete
                  ? 'Eliminar permanentemente'
                  : 'Sacar de la bóveda',
            ),
            content: Text(
              action == _ImageAction.delete
                  ? 'Este archivo será eliminado de la bóveda. '
                        'Esta acción no se puede deshacer.'
                  : 'La imagen volverá a la galería y se eliminará de la bóveda.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(
                  action == _ImageAction.delete ? 'Eliminar' : 'Continuar',
                ),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !context.mounted) {
      return;
    }
    try {
      final ImageImportCubit cubit = context.read<ImageImportCubit>();
      if (action == _ImageAction.delete) {
        await cubit.delete(item);
      } else {
        await cubit.exportAndRemove(item);
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              action == _ImageAction.delete
                  ? 'Imagen eliminada.'
                  : 'Imagen guardada en la galería.',
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

  Future<void> _selectImages(BuildContext context) async {
    final ImageLibraryRepository imageLibrary = context
        .read<ImageLibraryRepository>();
    final List<GalleryImage>? selected = await Navigator.of(context)
        .push<List<GalleryImage>>(
          MaterialPageRoute<List<GalleryImage>>(
            builder: (context) =>
                ImageAssetPickerScreen(repository: imageLibrary),
          ),
        );
    if (!context.mounted || selected == null || selected.isEmpty) {
      return;
    }

    final ImageImportCubit cubit = context.read<ImageImportCubit>();
    final ImageImportResult result = await cubit.importImages(selected);
    if (!context.mounted) {
      return;
    }
    await _showImportResult(context, cubit, result);
  }

  Future<void> _showImportResult(
    BuildContext context,
    ImageImportCubit cubit,
    ImageImportResult result,
  ) async {
    if (result.imported.isEmpty) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('No se pudieron importar las imágenes'),
          content: Text(
            '${result.failed.length} elementos presentaron errores.',
          ),
          actions: <Widget>[
            if (kDebugMode)
              TextButton.icon(
                key: const ValueKey<String>('view-image-import-errors'),
                onPressed: () async {
                  Navigator.of(dialogContext).pop();
                  await Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (context) => const DebugErrorLogsScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.bug_report_outlined),
                label: const Text('Ver detalles'),
              ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Aceptar'),
            ),
          ],
        ),
      );
      return;
    }

    final bool? deleteOriginals = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Importación completada'),
        content: Text(
          '${result.imported.length} imágenes guardadas de forma segura.'
          '${result.failed.isEmpty ? '' : '\n${result.failed.length} no se pudieron importar.'}'
          '\n\n¿Deseas eliminar el archivo original del dispositivo?',
        ),
        actions: <Widget>[
          TextButton(
            key: const ValueKey<String>('keep-image-originals'),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Conservar originales'),
          ),
          FilledButton(
            key: const ValueKey<String>('delete-image-originals'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar originales'),
          ),
        ],
      ),
    );
    if (deleteOriginals != true || !context.mounted) {
      return;
    }

    final Set<String> deleted = await cubit.deleteOriginals(
      result.imported.map((imported) => imported.source.id),
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            deleted.length == result.imported.length
                ? 'Originales eliminados.'
                : 'Algunos originales no pudieron eliminarse.',
          ),
        ),
      );
    }
  }
}

final class _VaultImageTile extends StatefulWidget {
  const _VaultImageTile({
    required this.item,
    required this.showName,
    required this.thumbnailLoader,
    required this.onOpen,
    required this.onAction,
  });

  final VaultItem item;
  final bool showName;
  final Future<Uint8List?> Function(VaultItem item) thumbnailLoader;
  final VoidCallback onOpen;
  final ValueChanged<_ImageAction> onAction;

  @override
  State<_VaultImageTile> createState() => _VaultImageTileState();
}

final class _VaultImageTileState extends State<_VaultImageTile> {
  late Future<Uint8List?> _thumbnail = widget.thumbnailLoader(widget.item);

  @override
  void didUpdateWidget(covariant _VaultImageTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id != widget.item.id) {
      _thumbnail = widget.thumbnailLoader(widget.item);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: InkWell(
          key: ValueKey<String>('vault-image-${widget.item.id}'),
          onTap: widget.onOpen,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              FutureBuilder<Uint8List?>(
                future: _thumbnail,
                builder: (context, snapshot) {
                  final Uint8List? bytes = snapshot.data;
                  if (bytes != null) {
                    return Image.memory(
                      bytes,
                      fit: BoxFit.cover,
                      cacheWidth: 384,
                      cacheHeight: 384,
                    );
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  return const Icon(Icons.broken_image_outlined, size: 36);
                },
              ),
              Positioned(
                top: 0,
                right: 0,
                child: PopupMenuButton<_ImageAction>(
                  tooltip: 'Opciones',
                  onSelected: widget.onAction,
                  icon: const Icon(Icons.more_vert, color: Colors.white),
                  color: Theme.of(context).colorScheme.surface,
                  itemBuilder: (context) =>
                      const <PopupMenuEntry<_ImageAction>>[
                        PopupMenuItem<_ImageAction>(
                          value: _ImageAction.export,
                          child: Text('Sacar de la bóveda'),
                        ),
                        PopupMenuItem<_ImageAction>(
                          value: _ImageAction.delete,
                          child: Text('Eliminar'),
                        ),
                      ],
                ),
              ),
              if (widget.showName)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: ColoredBox(
                    color: Colors.black54,
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Text(
                        widget.item.originalName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
