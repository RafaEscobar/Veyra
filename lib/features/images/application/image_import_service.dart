import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:mime/mime.dart';
import 'package:uuid/uuid.dart';
import 'package:veyra/core/crypto/crypto_service.dart';
import 'package:veyra/core/errors/app_exception.dart';
import 'package:veyra/core/errors/app_exception_mapper.dart';
import 'package:veyra/core/performance/performance_monitor.dart';
import 'package:veyra/core/security/encrypted_value.dart';
import 'package:veyra/core/security/vault_session.dart';
import 'package:veyra/features/images/domain/entities/gallery_image.dart';
import 'package:veyra/features/images/domain/entities/image_import_result.dart';
import 'package:veyra/features/images/domain/repositories/image_library_repository.dart';
import 'package:veyra/features/vault/domain/entities/vault_item.dart';
import 'package:veyra/features/vault/domain/repositories/vault_repository.dart';
import 'package:veyra/features/vault/domain/services/vault_file_storage.dart';

typedef ImageImportProgress = void Function(int completed, int total);
typedef ImageIdGenerator = String Function();
typedef ImageThumbnailIdGenerator = String Function();
typedef ImageImportUtcNow = DateTime Function();

final class ImageImportService {
  ImageImportService({
    required this.imageLibrary,
    required this.vaultRepository,
    required this.fileStorage,
    required this.vaultSession,
    CryptoService? cryptoService,
    ImageIdGenerator? idGenerator,
    ImageThumbnailIdGenerator? thumbnailIdGenerator,
    ImageImportUtcNow? utcNow,
    this.performanceMonitor = const PerformanceMonitor(),
    this.maximumImageBytes = 50 * 1024 * 1024,
  }) : _cryptoService = cryptoService ?? CryptoService(),
       _idGenerator = idGenerator ?? const Uuid().v4,
       _thumbnailIdGenerator = thumbnailIdGenerator ?? const Uuid().v4,
       _utcNow = utcNow ?? _systemUtcNow;

  final int maximumImageBytes;
  final ImageLibraryRepository imageLibrary;
  final VaultRepository vaultRepository;
  final VaultFileStorage fileStorage;
  final VaultSession vaultSession;
  final CryptoService _cryptoService;
  final ImageIdGenerator _idGenerator;
  final ImageThumbnailIdGenerator _thumbnailIdGenerator;
  final PerformanceMonitor performanceMonitor;
  final ImageImportUtcNow _utcNow;

  Future<ImageImportResult> importImages(
    List<GalleryImage> images, {
    ImageImportProgress? onProgress,
  }) {
    return performanceMonitor.measure(
      PerformanceOperation.imageImport,
      () => _importImages(images, onProgress: onProgress),
    );
  }

  Future<ImageImportResult> _importImages(
    List<GalleryImage> images, {
    ImageImportProgress? onProgress,
  }) async {
    final List<ImportedImage> imported = <ImportedImage>[];
    final List<FailedImageImport> failed = <FailedImageImport>[];

    try {
      for (int index = 0; index < images.length; index++) {
        final GalleryImage image = images[index];
        try {
          imported.add(await _importOne(image));
        } on AppException catch (error) {
          failed.add(FailedImageImport(source: image, error: error));
        } on Object catch (error) {
          failed.add(
            FailedImageImport(
              source: image,
              error: AppExceptionMapper.map(
                error,
                fallback: (cause) => ImageImportException(cause: cause),
              ),
            ),
          );
        }
        onProgress?.call(index + 1, images.length);
      }
    } finally {
      await imageLibrary.clearCache();
    }

    return ImageImportResult(
      imported: List<ImportedImage>.unmodifiable(imported),
      failed: List<FailedImageImport>.unmodifiable(failed),
    );
  }

  Future<Set<String>> deleteOriginals(Iterable<String> sourceIds) {
    return imageLibrary.deleteOriginals(sourceIds);
  }

  Future<ImportedImage> _importOne(GalleryImage image) async {
    final File? sourceFile = await imageLibrary.loadOriginal(image.id);
    if (sourceFile == null || !await sourceFile.exists()) {
      throw const VaultSourceFileNotFoundException();
    }
    final int size = await sourceFile.length();
    if (size <= 0) {
      throw const InvalidImageTypeException();
    }
    if (size > maximumImageBytes) {
      throw ImageTooLargeException(maximumBytes: maximumImageBytes);
    }

    final Uint8List header = await _readHeader(sourceFile);
    final String? detectedMimeType = lookupMimeType(
      sourceFile.path,
      headerBytes: header,
    );
    final String? mimeType = detectedMimeType ?? image.mimeType;
    if (mimeType == null || !mimeType.startsWith('image/')) {
      throw const InvalidImageTypeException();
    }

    final String id = _idGenerator();
    final String encryptedFileName = '$id.dat';
    final String thumbnailFileName = '${_thumbnailIdGenerator()}.thumb';
    final File encryptedFile = await fileStorage.encryptedFile(
      type: VaultItemType.image,
      fileName: encryptedFileName,
    );
    File? thumbnailFile;
    bool metadataSaved = false;
    try {
      final Uint8List? thumbnail = await _loadThumbnail(image.id);
      if (thumbnail != null && thumbnail.isNotEmpty) {
        thumbnailFile = await fileStorage.encryptedFile(
          type: VaultItemType.image,
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
        originalName: image.name,
        encryptedFileName: encryptedFileName,
        type: VaultItemType.image,
        mimeType: mimeType,
        size: size,
        createdAt: image.createdAt.toUtc(),
        importedAt: _utcNow(),
        thumbnailPath: thumbnailFile == null ? null : thumbnailFileName,
      );
      await vaultRepository.insert(item);
      metadataSaved = true;
      return ImportedImage(source: image, item: item);
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
      return await imageLibrary.loadThumbnail(id, size: 384);
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
