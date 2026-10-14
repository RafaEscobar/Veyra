import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:veyra/core/errors/app_error_handler.dart';
import 'package:veyra/core/errors/app_error_message.dart';
import 'package:veyra/features/vault/domain/entities/vault_item.dart';
import 'package:veyra/features/vault/presentation/widgets/vault_content_state.dart';
import 'package:veyra/features/videos/domain/entities/gallery_video.dart';
import 'package:veyra/features/videos/domain/entities/video_import_result.dart';
import 'package:veyra/features/videos/domain/repositories/video_library_repository.dart';
import 'package:veyra/features/videos/presentation/cubit/video_import_cubit.dart';
import 'package:veyra/features/videos/presentation/cubit/video_import_state.dart';
import 'package:veyra/features/videos/presentation/pages/vault_video_player_screen.dart';
import 'package:veyra/features/videos/presentation/pages/video_asset_picker_screen.dart';

enum _VideoAction { export, delete }

final class VideosVaultScreen extends StatelessWidget {
  const VideosVaultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VideoImportCubit, VideoImportState>(
      builder: (context, state) {
        final bool busy =
            state.status == VideoImportStatus.importing ||
            state.status == VideoImportStatus.checkingSize;
        return Scaffold(
          appBar: AppBar(title: const Text('Videos')),
          body: SafeArea(
            child: Column(
              children: <Widget>[
                if (state.status == VideoImportStatus.checkingSize)
                  const LinearProgressIndicator(),
                if (state.status == VideoImportStatus.importing) ...<Widget>[
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
                      key: const ValueKey<String>('add-videos'),
                      onPressed: busy ? null : () => _selectVideos(context),
                      icon: const Icon(Icons.video_library_outlined),
                      label: const Text('Agregar videos'),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildGrid(BuildContext context, VideoImportState state) {
    if (state.status == VideoImportStatus.loading && state.items.isEmpty) {
      return const VaultLoadingState(key: ValueKey<String>('videos-loading'));
    }
    if (state.status == VideoImportStatus.failure && state.items.isEmpty) {
      return VaultErrorState(
        key: const ValueKey<String>('videos-error'),
        onRetry: context.read<VideoImportCubit>().loadInitial,
      );
    }
    if (state.items.isEmpty) {
      return VaultEmptyState(
        key: const ValueKey<String>('videos-vault-count'),
        icon: Icons.video_library_outlined,
        title: 'No tienes videos ocultos',
        description:
            'Agrega videos para guardarlos de forma segura en tu bóveda.',
        actionLabel: 'Agregar videos',
        actionKey: const ValueKey<String>('add-videos'),
        onAction: () => _selectVideos(context),
      );
    }
    final int itemCount = state.items.length + (state.hasMore ? 1 : 0);
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.extentAfter < 500) {
          unawaited(context.read<VideoImportCubit>().loadMore());
        }
        return false;
      },
      child: GridView.builder(
        key: const ValueKey<String>('videos-vault-grid'),
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.15,
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
          final VaultItem item = state.items[index];
          return _VaultVideoTile(
            item: item,
            thumbnailLoader: context.read<VideoImportCubit>().loadThumbnail,
            onOpen: () => _openPlayer(context, item),
            onAction: (action) => _handleAction(context, item, action),
          );
        },
      ),
    );
  }

  Future<void> _openPlayer(BuildContext context, VaultItem item) async {
    final VideoImportCubit cubit = context.read<VideoImportCubit>();
    final bool? deleted = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (context) => VaultVideoPlayerScreen(
          item: item,
          prepareVideo: cubit.preparePlayback,
          releaseVideo: cubit.releasePlayback,
          onDelete: cubit.delete,
        ),
      ),
    );
    if (context.mounted && deleted == true) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Video eliminado.')));
    }
  }

  Future<void> _handleAction(
    BuildContext context,
    VaultItem item,
    _VideoAction action,
  ) async {
    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              action == _VideoAction.delete
                  ? 'Eliminar permanentemente'
                  : 'Sacar de la bóveda',
            ),
            content: Text(
              action == _VideoAction.delete
                  ? 'Este archivo será eliminado de la bóveda. '
                        'Esta acción no se puede deshacer.'
                  : 'El video volverá a la galería y se eliminará de la bóveda.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(
                  action == _VideoAction.delete ? 'Eliminar' : 'Continuar',
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
      final VideoImportCubit cubit = context.read<VideoImportCubit>();
      if (action == _VideoAction.delete) {
        await cubit.delete(item);
      } else {
        await cubit.exportAndRemove(item);
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              action == _VideoAction.delete
                  ? 'Video eliminado.'
                  : 'Video guardado en la galería.',
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

  Future<void> _selectVideos(BuildContext context) async {
    final List<GalleryVideo>? selected = await Navigator.of(context)
        .push<List<GalleryVideo>>(
          MaterialPageRoute<List<GalleryVideo>>(
            builder: (context) => VideoAssetPickerScreen(
              repository: context.read<VideoLibraryRepository>(),
            ),
          ),
        );
    if (!context.mounted || selected == null || selected.isEmpty) {
      return;
    }

    final VideoImportCubit cubit = context.read<VideoImportCubit>();
    final List<GalleryVideo> largeVideos = await cubit.checkLargeVideos(
      selected,
    );
    if (!context.mounted) {
      return;
    }
    if (largeVideos.isNotEmpty) {
      final bool proceed =
          await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Videos grandes'),
              content: Text(
                '${largeVideos.length} videos ocupan 100 MB o más. '
                'La importación puede tardar varios minutos.',
              ),
              actions: <Widget>[
                TextButton(
                  key: const ValueKey<String>('cancel-large-videos'),
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  key: const ValueKey<String>('continue-large-videos'),
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Continuar'),
                ),
              ],
            ),
          ) ??
          false;
      if (!proceed) {
        await cubit.cancelPreparedImport();
        return;
      }
    }

    final VideoImportResult result = await cubit.importVideos(selected);
    if (!context.mounted) {
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          result.imported.isEmpty
              ? 'No se pudieron importar los videos'
              : 'Importación completada',
        ),
        content: Text(
          '${result.imported.length} videos guardados de forma segura.'
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
}

final class _VaultVideoTile extends StatefulWidget {
  const _VaultVideoTile({
    required this.item,
    required this.thumbnailLoader,
    required this.onOpen,
    required this.onAction,
  });

  final VaultItem item;
  final Future<Uint8List?> Function(VaultItem item) thumbnailLoader;
  final VoidCallback onOpen;
  final ValueChanged<_VideoAction> onAction;

  @override
  State<_VaultVideoTile> createState() => _VaultVideoTileState();
}

final class _VaultVideoTileState extends State<_VaultVideoTile> {
  late Future<Uint8List?> _thumbnail = widget.thumbnailLoader(widget.item);

  @override
  void didUpdateWidget(covariant _VaultVideoTile oldWidget) {
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
          key: ValueKey<String>('vault-video-${widget.item.id}'),
          onTap: widget.onOpen,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    FutureBuilder<Uint8List?>(
                      future: _thumbnail,
                      builder: (context, snapshot) {
                        if (snapshot.data case final Uint8List bytes) {
                          return Image.memory(
                            bytes,
                            fit: BoxFit.cover,
                            cacheWidth: 384,
                            cacheHeight: 384,
                          );
                        }
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        return const Icon(Icons.movie_outlined, size: 42);
                      },
                    ),
                    const Center(
                      child: Icon(
                        Icons.play_circle_fill,
                        color: Colors.white,
                        size: 42,
                      ),
                    ),
                    if (widget.item.duration case final Duration duration)
                      Positioned(
                        right: 6,
                        bottom: 6,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 2,
                            ),
                            child: Text(
                              _formatDuration(duration),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 10),
                      child: Text(
                        widget.item.originalName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  PopupMenuButton<_VideoAction>(
                    tooltip: 'Opciones',
                    onSelected: widget.onAction,
                    itemBuilder: (context) =>
                        const <PopupMenuEntry<_VideoAction>>[
                          PopupMenuItem<_VideoAction>(
                            value: _VideoAction.export,
                            child: Text('Sacar de la bóveda'),
                          ),
                          PopupMenuItem<_VideoAction>(
                            value: _VideoAction.delete,
                            child: Text('Eliminar'),
                          ),
                        ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final int hours = duration.inHours;
    final int minutes = duration.inMinutes.remainder(60);
    final int seconds = duration.inSeconds.remainder(60);
    final String minuteText = hours > 0
        ? minutes.toString().padLeft(2, '0')
        : minutes.toString();
    final String secondText = seconds.toString().padLeft(2, '0');
    return hours > 0
        ? '$hours:$minuteText:$secondText'
        : '$minuteText:$secondText';
  }
}
