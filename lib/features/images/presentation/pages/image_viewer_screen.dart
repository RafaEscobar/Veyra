import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemChrome, SystemUiMode;
import 'package:veyra/core/errors/app_error_handler.dart';
import 'package:veyra/core/errors/app_error_message.dart';
import 'package:veyra/core/security/screen_security_service.dart';
import 'package:veyra/features/vault/domain/entities/vault_item.dart';

typedef VaultImageLoader = Future<Uint8List> Function(VaultItem item);
typedef VaultImageDelete = Future<bool> Function(VaultItem item);
typedef VaultImageExport = Future<void> Function(VaultItem item);

final class ImageViewerScreen extends StatefulWidget {
  const ImageViewerScreen({
    required this.item,
    required this.imageLoader,
    required this.onDelete,
    required this.onExport,
    this.screenSecurity = const MethodChannelScreenSecurityService(),
    super.key,
  });

  final VaultItem item;
  final VaultImageLoader imageLoader;
  final VaultImageDelete onDelete;
  final VaultImageExport onExport;
  final ScreenSecurityService screenSecurity;

  @override
  State<ImageViewerScreen> createState() => _ImageViewerScreenState();
}

final class _ImageViewerScreenState extends State<ImageViewerScreen> {
  Uint8List? _imageBytes;
  MemoryImage? _imageProvider;
  Object? _error;
  bool _busy = false;
  bool _protectionActive = false;

  @override
  void initState() {
    super.initState();
    unawaited(_enableProtection());
    unawaited(_load());
  }

  Future<void> _enableProtection() async {
    try {
      await widget.screenSecurity.setSecure(true);
    } on Object {
      // The native protection is best-effort on unsupported test platforms.
    }
    if (!mounted) {
      await _setScreenSecure(false);
      return;
    }
    _protectionActive = true;
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    if (!mounted) {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  Future<void> _load() async {
    try {
      final Uint8List bytes = await widget.imageLoader(widget.item);
      if (!mounted) {
        bytes.fillRange(0, bytes.length, 0);
        return;
      }
      setState(() {
        _imageBytes = bytes;
        _imageProvider = MemoryImage(bytes);
      });
    } on Object catch (error, stackTrace) {
      AppErrorHandler.report(error, stackTrace);
      if (mounted) {
        setState(() => _error = error);
      }
    }
  }

  @override
  void dispose() {
    if (_protectionActive) {
      unawaited(_setScreenSecure(false));
    }
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    final Uint8List? bytes = _imageBytes;
    final MemoryImage? provider = _imageProvider;
    if (provider != null) {
      unawaited(provider.evict());
    }
    _imageProvider = null;
    bytes?.fillRange(0, bytes.length, 0);
    _imageBytes = null;
    super.dispose();
  }

  Future<void> _setScreenSecure(bool secure) async {
    try {
      await widget.screenSecurity.setSecure(secure);
    } on Object {
      // The native protection is best-effort on unsupported test platforms.
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black54,
          foregroundColor: Colors.white,
          title: Text(widget.item.originalName),
          actions: <Widget>[
            IconButton(
              key: const ValueKey<String>('export-vault-image'),
              onPressed: _busy ? null : () => _confirmAction(export: true),
              tooltip: 'Sacar de la bóveda',
              icon: const Icon(Icons.output_outlined),
            ),
            IconButton(
              key: const ValueKey<String>('delete-vault-image'),
              onPressed: _busy ? null : () => _confirmAction(export: false),
              tooltip: 'Eliminar',
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
        body: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Center(child: _buildContent()),
            if (_busy)
              const ColoredBox(
                color: Colors.black45,
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final Uint8List? bytes = _imageBytes;
    final MemoryImage? provider = _imageProvider;
    if (bytes != null && provider != null) {
      return InteractiveViewer(
        key: const ValueKey<String>('vault-image-zoom'),
        minScale: 1,
        maxScale: 5,
        boundaryMargin: const EdgeInsets.all(80),
        child: Image(
          image: provider,
          key: const ValueKey<String>('vault-image-preview'),
          fit: BoxFit.contain,
          gaplessPlayback: true,
        ),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          AppErrorMessage.forError(_error!),
          style: const TextStyle(color: Colors.white),
          textAlign: TextAlign.center,
        ),
      );
    }
    return const CircularProgressIndicator();
  }

  Future<void> _confirmAction({required bool export}) async {
    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              export ? 'Sacar de la bóveda' : 'Eliminar permanentemente',
            ),
            content: Text(
              export
                  ? 'La imagen volverá a la galería y se eliminará de la bóveda.'
                  : 'Este archivo será eliminado de la bóveda. '
                        'Esta acción no se puede deshacer.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                key: ValueKey<String>(
                  export ? 'confirm-export-image' : 'confirm-delete-image',
                ),
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(export ? 'Continuar' : 'Eliminar'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) {
      return;
    }
    setState(() => _busy = true);
    try {
      if (export) {
        await widget.onExport(widget.item);
      } else if (!await widget.onDelete(widget.item)) {
        throw StateError('The image was not deleted.');
      }
      if (mounted) {
        Navigator.of(context).pop(export ? 'export' : 'delete');
      }
    } on Object catch (error, stackTrace) {
      AppErrorHandler.report(error, stackTrace);
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppErrorMessage.forError(error))),
        );
      }
    }
  }
}
