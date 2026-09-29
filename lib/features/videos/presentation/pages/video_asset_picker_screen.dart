import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:veyra/features/images/domain/repositories/image_library_repository.dart';
import 'package:veyra/features/videos/domain/entities/gallery_video.dart';
import 'package:veyra/features/videos/domain/repositories/video_library_repository.dart';

final class VideoAssetPickerScreen extends StatefulWidget {
  const VideoAssetPickerScreen({required this.repository, super.key});

  final VideoLibraryRepository repository;

  @override
  State<VideoAssetPickerScreen> createState() => _VideoAssetPickerScreenState();
}

final class _VideoAssetPickerScreenState extends State<VideoAssetPickerScreen> {
  static const int _pageSize = 60;

  final ScrollController _scrollController = ScrollController();
  final List<GalleryVideo> _videos = <GalleryVideo>[];
  final Set<String> _selectedIds = <String>{};
  ImageLibraryAccess? _access;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  bool _selectionSubmitted = false;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    unawaited(_initialize());
  }

  @override
  void dispose() {
    if (!_selectionSubmitted) {
      unawaited(widget.repository.clearCache());
    }
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    setState(() => _loading = true);
    final ImageLibraryAccess access = await widget.repository.requestAccess();
    if (!mounted) {
      return;
    }
    setState(() {
      _access = access;
      _loading = false;
    });
    if (access != ImageLibraryAccess.denied) {
      await _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) {
      return;
    }
    setState(() => _loadingMore = true);
    try {
      final List<GalleryVideo> videos = await widget.repository.loadRecent(
        page: _page,
        pageSize: _pageSize,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _videos.addAll(videos);
        _page++;
        _hasMore = videos.length == _pageSize;
      });
    } finally {
      if (mounted) {
        setState(() => _loadingMore = false);
      }
    }
  }

  void _onScroll() {
    if (_scrollController.position.extentAfter < 500) {
      unawaited(_loadMore());
    }
  }

  void _toggle(GalleryVideo video) {
    setState(() {
      if (!_selectedIds.add(video.id)) {
        _selectedIds.remove(video.id);
      }
    });
  }

  void _finishSelection() {
    _selectionSubmitted = true;
    Navigator.of(context).pop(
      _videos
          .where((video) => _selectedIds.contains(video.id))
          .toList(growable: false),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Seleccionar videos'),
        actions: <Widget>[
          TextButton(
            key: const ValueKey<String>('confirm-video-selection'),
            onPressed: _selectedIds.isEmpty ? null : _finishSelection,
            child: Text('Agregar (${_selectedIds.length})'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_access == ImageLibraryAccess.denied) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.video_library_outlined, size: 48),
              const SizedBox(height: 16),
              const Text(
                'Veyra necesita acceso a tus videos para seleccionarlos.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton(
                key: const ValueKey<String>('open-video-settings'),
                onPressed: widget.repository.openSettings,
                child: const Text('Abrir configuración'),
              ),
              TextButton(
                onPressed: _initialize,
                child: const Text('Volver a intentar'),
              ),
            ],
          ),
        ),
      );
    }
    if (_videos.isEmpty && !_loadingMore) {
      return const Center(child: Text('No hay videos disponibles'));
    }
    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: _videos.length + (_loadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _videos.length) {
          return const Center(child: CircularProgressIndicator());
        }
        final GalleryVideo video = _videos[index];
        final bool selected = _selectedIds.contains(video.id);
        return Semantics(
          label: video.name,
          selected: selected,
          button: true,
          child: InkWell(
            key: ValueKey<String>('select-video-${video.id}'),
            onTap: () => _toggle(video),
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                FutureBuilder<Uint8List?>(
                  future: widget.repository.loadThumbnail(video.id, size: 256),
                  builder: (context, snapshot) {
                    final Uint8List? bytes = snapshot.data;
                    return bytes == null
                        ? ColoredBox(
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHigh,
                            child: const Icon(Icons.movie_outlined),
                          )
                        : Image.memory(
                            bytes,
                            fit: BoxFit.cover,
                            cacheWidth: 256,
                            cacheHeight: 256,
                          );
                  },
                ),
                Positioned(
                  left: 6,
                  bottom: 6,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      child: Text(
                        _formatDuration(video.duration),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: Icon(
                    selected ? Icons.check_circle : Icons.circle_outlined,
                    color: selected
                        ? Theme.of(context).colorScheme.primary
                        : Colors.white,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatDuration(Duration duration) {
    final String minutes = duration.inMinutes.toString();
    final String seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
