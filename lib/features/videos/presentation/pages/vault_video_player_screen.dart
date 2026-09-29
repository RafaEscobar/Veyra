import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemChrome, SystemUiMode;
import 'package:veyra/core/errors/app_error_message.dart';
import 'package:veyra/core/errors/app_exception.dart';
import 'package:veyra/core/security/screen_security_service.dart';
import 'package:veyra/features/vault/domain/entities/vault_item.dart';
import 'package:video_player/video_player.dart';

typedef VaultVideoPreparer = Future<File> Function(VaultItem item);
typedef VaultVideoReleaser = Future<void> Function(File file);
typedef VaultVideoDelete = Future<bool> Function(VaultItem item);

final class VaultVideoPlayerScreen extends StatefulWidget {
  const VaultVideoPlayerScreen({
    required this.item,
    required this.prepareVideo,
    required this.releaseVideo,
    required this.onDelete,
    this.screenSecurity = const MethodChannelScreenSecurityService(),
    super.key,
  });

  final VaultItem item;
  final VaultVideoPreparer prepareVideo;
  final VaultVideoReleaser releaseVideo;
  final VaultVideoDelete onDelete;
  final ScreenSecurityService screenSecurity;

  @override
  State<VaultVideoPlayerScreen> createState() => _VaultVideoPlayerScreenState();
}

final class _VaultVideoPlayerScreenState extends State<VaultVideoPlayerScreen>
    with WidgetsBindingObserver {
  File? _temporaryFile;
  VideoPlayerController? _controller;
  Object? _error;
  bool _cleaned = false;
  bool _deleting = false;
  bool _protectionActive = false;
  late final Future<void> _initialization;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_enableProtection());
    _initialization = _initialize();
  }

  Future<void> _initialize() async {
    try {
      final File file = await widget.prepareVideo(widget.item);
      _temporaryFile = file;
      if (!mounted) {
        return;
      }
      final VideoPlayerController controller = VideoPlayerController.file(file);
      _controller = controller;
      controller.addListener(_onControllerChanged);
      await controller.initialize();
      await controller.setLooping(false);
      if (mounted) {
        setState(() {});
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() => _error = error);
      }
    }
  }

  Future<void> _enableProtection() async {
    try {
      await widget.screenSecurity.setSecure(true);
    } on Object {
      // The channel is unavailable on unsupported test platforms.
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      final VideoPlayerController? controller = _controller;
      if (controller != null && controller.value.isPlaying) {
        unawaited(controller.pause());
      }
    }
  }

  void _onControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_cleanup());
    super.dispose();
  }

  Future<void> _cleanup() async {
    if (_cleaned) {
      return;
    }
    _cleaned = true;
    try {
      await _initialization;
    } on Object {
      // Resource cleanup continues after initialization errors.
    }
    final VideoPlayerController? controller = _controller;
    _controller = null;
    if (controller != null) {
      controller.removeListener(_onControllerChanged);
      try {
        await controller.pause();
      } on Object {
        // Disposal still releases the underlying player.
      }
      try {
        await controller.dispose();
      } on Object {
        // The plaintext file must still be removed after player errors.
      }
    }
    final File? temporaryFile = _temporaryFile;
    _temporaryFile = null;
    if (temporaryFile != null) {
      try {
        await widget.releaseVideo(temporaryFile);
      } on Object {
        // Protection and system UI restoration must still continue.
      }
    }
    if (_protectionActive) {
      await _setScreenSecure(false);
    }
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  Future<void> _setScreenSecure(bool secure) async {
    try {
      await widget.screenSecurity.setSecure(secure);
    } on Object {
      // The channel is unavailable on unsupported test platforms.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black54,
        foregroundColor: Colors.white,
        title: Text(widget.item.originalName),
        actions: <Widget>[
          if (_error is VaultFileCorruptedException)
            IconButton(
              key: const ValueKey<String>('delete-corrupted-video'),
              onPressed: _deleting ? null : _confirmDelete,
              tooltip: 'Eliminar elemento dañado',
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          SafeArea(top: false, child: Center(child: _buildContent())),
          if (_deleting)
            const ColoredBox(
              color: Colors.black45,
              child: Center(
                child: SizedBox.square(
                  dimension: 32,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContent() {
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
    final VideoPlayerController? controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const CircularProgressIndicator();
    }
    final VideoPlayerValue value = controller.value;
    final Duration duration = value.duration;
    final Duration position = value.position > duration
        ? duration
        : value.position;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: value.aspectRatio == 0 ? 16 / 9 : value.aspectRatio,
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  VideoPlayer(controller),
                  Center(
                    child: IconButton.filledTonal(
                      key: const ValueKey<String>('toggle-video-playback'),
                      onPressed: _togglePlayback,
                      iconSize: 48,
                      icon: Icon(
                        value.isPlaying ? Icons.pause : Icons.play_arrow,
                      ),
                    ),
                  ),
                  if (value.isBuffering)
                    const Center(child: CircularProgressIndicator()),
                ],
              ),
            ),
          ),
        ),
        ColoredBox(
          color: Colors.black87,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            child: Column(
              children: <Widget>[
                Slider(
                  key: const ValueKey<String>('video-seek-slider'),
                  value: position.inMilliseconds.toDouble().clamp(
                    0,
                    _maximumSliderValue(duration),
                  ),
                  max: _maximumSliderValue(duration),
                  onChanged: (milliseconds) {
                    unawaited(
                      controller.seekTo(
                        Duration(milliseconds: milliseconds.round()),
                      ),
                    );
                  },
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text(
                      _formatDuration(position),
                      style: const TextStyle(color: Colors.white),
                    ),
                    Text(
                      _formatDuration(duration),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _togglePlayback() async {
    final VideoPlayerController? controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }
    if (controller.value.isPlaying) {
      await controller.pause();
      return;
    }
    if (controller.value.isCompleted) {
      await controller.seekTo(Duration.zero);
    }
    await controller.play();
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
                key: const ValueKey<String>('confirm-delete-corrupted-video'),
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
        throw StateError('The corrupted video was not deleted.');
      }
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() => _deleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppErrorMessage.forError(error))),
        );
      }
    }
  }

  double _maximumSliderValue(Duration duration) {
    return duration.inMilliseconds <= 0
        ? 1
        : duration.inMilliseconds.toDouble();
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
