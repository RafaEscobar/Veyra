import 'dart:async';

import 'package:flutter/material.dart';
import 'package:veyra/core/errors/app_error_handler.dart';
import 'package:veyra/core/errors/app_error_message.dart';
import 'package:veyra/core/errors/app_exception.dart';
import 'package:veyra/core/security/screen_security_service.dart';
import 'package:veyra/features/vault/domain/entities/vault_item.dart';

typedef DocumentTextLoader = Future<String> Function(VaultItem item);
typedef DocumentDelete = Future<bool> Function(VaultItem item);

final class DocumentPreviewScreen extends StatefulWidget {
  const DocumentPreviewScreen({
    required this.item,
    required this.textLoader,
    required this.onDelete,
    this.screenSecurity = const MethodChannelScreenSecurityService(),
    super.key,
  });

  final VaultItem item;
  final DocumentTextLoader textLoader;
  final DocumentDelete onDelete;
  final ScreenSecurityService screenSecurity;

  @override
  State<DocumentPreviewScreen> createState() => _DocumentPreviewScreenState();
}

final class _DocumentPreviewScreenState extends State<DocumentPreviewScreen> {
  late final Future<String> _text = widget.textLoader(widget.item);
  bool _protectionActive = false;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    unawaited(_enableProtection());
  }

  @override
  void dispose() {
    if (_protectionActive) {
      unawaited(_setSecure(false));
    }
    super.dispose();
  }

  Future<void> _enableProtection() async {
    await _setSecure(true);
    if (!mounted) {
      await _setSecure(false);
      return;
    }
    _protectionActive = true;
  }

  Future<void> _setSecure(bool secure) async {
    try {
      await widget.screenSecurity.setSecure(secure);
    } on Object {
      // The channel is unavailable on unsupported test platforms.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.item.originalName)),
      body: FutureBuilder<String>(
        future: _text,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _DocumentPreviewError(
              error: snapshot.error!,
              deleting: _deleting,
              onDelete: _confirmDelete,
            );
          }
          final String? text = snapshot.data;
          if (text == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: SelectableText(
              text,
              key: const ValueKey<String>('document-text-preview'),
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete() async {
    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Eliminar elemento dañado'),
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
                key: const ValueKey<String>('confirm-delete-corrupted-file'),
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Eliminar'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) {
      return;
    }
    setState(() => _deleting = true);
    try {
      if (!await widget.onDelete(widget.item)) {
        throw StateError('The corrupted document was not deleted.');
      }
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on Object catch (error, stackTrace) {
      AppErrorHandler.report(error, stackTrace);
      if (mounted) {
        setState(() => _deleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppErrorMessage.forError(error))),
        );
      }
    }
  }
}

final class _DocumentPreviewError extends StatelessWidget {
  const _DocumentPreviewError({
    required this.error,
    required this.deleting,
    required this.onDelete,
  });

  final Object error;
  final bool deleting;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(AppErrorMessage.forError(error), textAlign: TextAlign.center),
            if (error is VaultFileCorruptedException) ...<Widget>[
              const SizedBox(height: 20),
              FilledButton.icon(
                key: const ValueKey<String>('delete-corrupted-file'),
                onPressed: deleting ? null : onDelete,
                icon: deleting
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.delete_outline),
                label: Text(deleting ? 'Eliminando…' : 'Eliminar elemento'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
