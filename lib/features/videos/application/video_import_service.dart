import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:mime/mime.dart';
import 'package:uuid/uuid.dart';
import 'package:veyra/core/crypto/crypto_service.dart';
import 'package:veyra/core/errors/app_error_handler.dart';
import 'package:veyra/core/errors/app_exception.dart';
import 'package:veyra/core/errors/app_exception_mapper.dart';
import 'package:veyra/core/performance/performance_monitor.dart';
import 'package:veyra/core/security/encrypted_value.dart';
import 'package:veyra/core/security/vault_session.dart';
import 'package:veyra/features/vault/domain/entities/vault_item.dart';
import 'package:veyra/features/vault/domain/repositories/vault_repository.dart';
import 'package:veyra/features/vault/domain/services/vault_file_storage.dart';
import 'package:veyra/features/videos/domain/entities/gallery_video.dart';
import 'package:veyra/features/videos/domain/entities/video_import_result.dart';
import 'package:veyra/features/videos/domain/repositories/video_library_repository.dart';

typedef VideoImportProgress = void Function(int completed, int total);
typedef VideoIdGenerator = String Function();
typedef VideoThumbnailIdGenerator = String Function();
typedef VideoImportUtcNow = DateTime Function();

final class VideoImportService {
  VideoImportService({
    required this.videoLibrary,
    required this.vaultRepository,
    required this.fileStorage,
    required this.vaultSession,
    CryptoService? cryptoService,
    VideoIdGenerator? idGenerator,
    VideoThumbnailIdGenerator? thumbnailIdGenerator,
    VideoImportUtcNow? utcNow,
    this.performanceMonitor = const PerformanceMonitor(),
    this.warningVideoBytes = 100 * 1024 * 1024,
    this.maximumVideoBytes = 500 * 1024 * 1024,
  }) : _cryptoService = cryptoService ?? CryptoService(),
       _idGenerator = idGenerator ?? const Uuid().v4,
       _thumbnailIdGenerator = thumbnailIdGenerator ?? const Uuid().v4,
       _utcNow = utcNow ?? _systemUtcNow;

  final int warningVideoBytes;
  final int maximumVideoBytes;
  final VideoLibraryRepository videoLibrary;
  final VaultRepository vaultRepository;
  final VaultFileStorage fileStorage;
  final VaultSession vaultSession;
  final CryptoService _cryptoService;
  final VideoIdGenerator _idGenerator;
  final VideoThumbnailIdGenerator _thumbnailIdGenerator;
  final PerformanceMonitor performanceMonitor;
  final VideoImportUtcNow _utcNow;

  Future<List<GalleryVideo>> videosRequiringWarning(
    List<GalleryVideo> videos,
  ) async {
    final List<GalleryVideo> largeVideos = <GalleryVideo>[];
    for (final GalleryVideo video in videos) {
      final File? file = await videoLibrary.loadOriginal(video.id);
      if (file != null && await file.exists()) {
        final int size = await file.length();
        if (size >= warningVideoBytes) {
          largeVideos.add(video);
        }
      }
    }
    return List<GalleryVideo>.unmodifiable(largeVideos);
  }

  Future<void> discardPreparedFiles() => videoLibrary.clearCache();

  Future<VideoImportResult> importVideos(
    List<GalleryVideo> videos, {
    VideoImportProgress? onProgress,
  }) {
    return performanceMonitor.measure(
      PerformanceOperation.videoImport,
      () => _importVideos(videos, onProgress: onProgress),
    );
  }

  Future<VideoImportResult> _importVideos(
    List<GalleryVideo> videos, {
    VideoImportProgress? onProgress,
  }) async {
    final List<ImportedVideo> imported = <ImportedVideo>[];
    final List<FailedVideoImport> failed = <FailedVideoImport>[];
    try {
      for (int index = 0; index < videos.length; index++) {
        final GalleryVideo video = videos[index];
        try {
          imported.add(await _importOne(video));
        } on AppException catch (error, stackTrace) {
          AppErrorHandler.report(error, stackTrace, operation: 'video_import');
          failed.add(FailedVideoImport(source: video, error: error));
        } on Object catch (error, stackTrace) {
          final AppException mapped = AppExceptionMapper.map(
            error,
            fallback: (cause) => VideoImportException(cause: cause),
          );
          AppErrorHandler.report(mapped, stackTrace, operation: 'video_import');
          failed.add(FailedVideoImport(source: video, error: mapped));
        }
        onProgress?.call(index + 1, videos.length);
      }
    } finally {
      await videoLibrary.clearCache();
    }
    return VideoImportResult(
      imported: List<ImportedVideo>.unmodifiable(imported),
      failed: List<FailedVideoImport>.unmodifiable(failed),
    );
  }

  Future<ImportedVideo> _importOne(GalleryVideo video) async {
    final File? sourceFile = await videoLibrary.loadOriginal(video.id);
    if (sourceFile == null || !await sourceFile.exists()) {
      throw const VaultSourceFileNotFoundException();
    }
    final int size = await sourceFile.length();
    if (size <= 0) {
      throw const InvalidVideoTypeException();
    }
    if (size > maximumVideoBytes) {
      throw VideoTooLargeException(maximumBytes: maximumVideoBytes);
    }

    final Uint8List header = await _readHeader(sourceFile);
    final String? detectedMimeType = lookupMimeType(
      sourceFile.path,
      headerBytes: header,
    );
    final String? mimeType = detectedMimeType ?? video.mimeType;
    if (mimeType == null || !mimeType.startsWith('video/')) {
      throw const InvalidVideoTypeException();
    }

    final String id = _idGenerator();
    final String encryptedFileName = '$id.dat';
    final String thumbnailFileName = '${_thumbnailIdGenerator()}.thumb';
    final File encryptedFile = await fileStorage.encryptedFile(
      type: VaultItemType.video,
      fileName: encryptedFileName,
    );
    File? thumbnailFile;
    bool metadataSaved = false;
    try {
      final Uint8List? thumbnail = await _loadThumbnail(video.id);
      if (thumbnail != null && thumbnail.isNotEmpty) {
        thumbnailFile = await fileStorage.encryptedFile(
          type: VaultItemType.video,
          fileName: thumbnailFileName,
        );
        try {
          final EncryptedValue encryptedThumbnail = await vaultSession
              .withMasterKey((secretKey) {
                return _cryptoService.encryptBytes(
                  clearText: thumbnail,
                  secretKey: secretKey,
                );
              });
          await thumbnailFile.writeAsString(
            jsonEncode(encryptedThumbnail.toJson()),
            flush: true,
          );
        } finally {
          thumbnail.fillRange(0, thumbnail.length, 0);
        }
      }
      await vaultSession.withMasterKey((secretKey) {
        return _cryptoService.encryptFile(
          inputFile: sourceFile,
          outputFile: encryptedFile,
          secretKey: secretKey,
        );
      });
      final VaultItem item = VaultItem(
        id: id,
        originalName: video.name,
        encryptedFileName: encryptedFileName,
        type: VaultItemType.video,
        mimeType: mimeType,
        size: size,
        createdAt: video.createdAt.toUtc(),
        importedAt: _utcNow(),
        thumbnailPath: thumbnailFile == null ? null : thumbnailFileName,
        duration: video.duration,
      );
      await vaultRepository.insert(item);
      metadataSaved = true;
      return ImportedVideo(source: video, item: item);
    } finally {
      if (!metadataSaved) {
        await fileStorage.deleteIfExists(encryptedFile);
        if (thumbnailFile != null) {
          await fileStorage.deleteIfExists(thumbnailFile);
        }
      }
    }
  }

  Future<Uint8List?> _loadThumbnail(String id) async {
    try {
      final Uint8List? source = await videoLibrary.loadThumbnail(id, size: 384);
      return source == null ? null : Uint8List.fromList(source);
    } on Object {
      return null;
    }
  }

  Future<Uint8List> _readHeader(File file) async {
    final RandomAccessFile reader = await file.open();
    try {
      return await reader.read(32);
    } finally {
      await reader.close();
    }
  }
}

DateTime _systemUtcNow() => DateTime.now().toUtc();
