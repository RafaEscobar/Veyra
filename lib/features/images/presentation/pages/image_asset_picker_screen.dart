import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:veyra/features/images/domain/entities/gallery_image.dart';
import 'package:veyra/features/images/domain/repositories/image_library_repository.dart';

final class ImageAssetPickerScreen extends StatefulWidget {
  const ImageAssetPickerScreen({required this.repository, super.key});

  final ImageLibraryRepository repository;

  @override
  State<ImageAssetPickerScreen> createState() => _ImageAssetPickerScreenState();
}

final class _ImageAssetPickerScreenState extends State<ImageAssetPickerScreen> {
  static const int _pageSize = 60;

  final ScrollController _scrollController = ScrollController();
  final List<GalleryImage> _images = <GalleryImage>[];
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
      final List<GalleryImage> images = await widget.repository.loadRecent(
        page: _page,
        pageSize: _pageSize,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _images.addAll(images);
        _page++;
        _hasMore = images.length == _pageSize;
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

  void _toggle(GalleryImage image) {
    setState(() {
      if (!_selectedIds.add(image.id)) {
        _selectedIds.remove(image.id);
      }
    });
  }

  void _finishSelection() {
    final List<GalleryImage> selected = _images
        .where((image) => _selectedIds.contains(image.id))
        .toList(growable: false);
    _selectionSubmitted = true;
    Navigator.of(context).pop(selected);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Seleccionar imágenes'),
        actions: <Widget>[
          TextButton(
            key: const ValueKey<String>('confirm-image-selection'),
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
              const Icon(Icons.photo_library_outlined, size: 48),
              const SizedBox(height: 16),
              const Text(
                'Veyra necesita acceso a tus imágenes para seleccionarlas.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton(
                key: const ValueKey<String>('open-photo-settings'),
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
    if (_images.isEmpty && !_loadingMore) {
      return const Center(child: Text('No hay imágenes disponibles'));
    }

    return Column(
      children: <Widget>[
        if (_access == ImageLibraryAccess.limited)
          MaterialBanner(
            content: const Text('Mostrando las imágenes permitidas.'),
            actions: const <Widget>[SizedBox.shrink()],
          ),
        Expanded(
          child: GridView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(2),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 2,
              mainAxisSpacing: 2,
            ),
            itemCount: _images.length + (_loadingMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == _images.length) {
                return const Center(child: CircularProgressIndicator());
              }
              final GalleryImage image = _images[index];
              return _ImageTile(
                image: image,
                repository: widget.repository,
                selected: _selectedIds.contains(image.id),
                onTap: () => _toggle(image),
              );
            },
          ),
        ),
      ],
    );
  }
}

final class _ImageTile extends StatelessWidget {
  const _ImageTile({
    required this.image,
    required this.repository,
    required this.selected,
    required this.onTap,
  });

  final GalleryImage image;
  final ImageLibraryRepository repository;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: image.name,
      selected: selected,
      button: true,
      child: InkWell(
        key: ValueKey<String>('select-image-${image.id}'),
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            FutureBuilder<Uint8List?>(
              future: repository.loadThumbnail(image.id, size: 256),
              builder: (context, snapshot) {
                final Uint8List? bytes = snapshot.data;
                if (bytes == null) {
                  return ColoredBox(
                    color: Theme.of(context).colorScheme.surfaceContainerHigh,
                    child: const Icon(Icons.image_outlined),
                  );
                }
                return Image.memory(
                  bytes,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  cacheWidth: 256,
                  cacheHeight: 256,
                );
              },
            ),
            if (selected)
              ColoredBox(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.35),
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
  }
}
