import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as path;
import 'package:veyra/core/crypto/crypto_service.dart';
import 'package:veyra/core/errors/app_exception.dart';
import 'package:veyra/core/errors/app_exception_mapper.dart';
import 'package:veyra/core/security/encrypted_value.dart';
import 'package:veyra/core/security/vault_session.dart';
import 'package:veyra/features/vault/application/vault_deletion_service.dart';
import 'package:veyra/features/vault/domain/entities/vault_item.dart';
import 'package:veyra/features/vault/domain/repositories/vault_folder_repository.dart';
import 'package:veyra/features/vault/domain/repositories/vault_repository.dart';
import 'package:veyra/features/vault/domain/services/vault_file_storage.dart';
import 'package:veyra/features/videos/domain/repositories/video_library_repository.dart';

final class VideoVaultService {
  VideoVaultService({
    required this.vaultRepository,
    required this.fileStorage,
    required this.vaultSession,
    required this.videoLibrary,
    VaultDeletionService? deletionService,
    CryptoService? cryptoService,
    this.maximumCachedThumbnails = 60,
  }) : _cryptoService = cryptoService ?? CryptoService(),
       _deletionService =
           deletionService ??
           VaultDeletionService(
             vaultRepository: vaultRepository,
             fileStorage: fileStorage,
           );

  final int maximumCachedThumbnails;
  final VaultRepository vaultRepository;
  final VaultFileStorage fileStorage;
  final VaultSession vaultSession;
  final VideoLibraryRepository videoLibrary;
  final CryptoService _cryptoService;
  final VaultDeletionService _deletionService;
  final LinkedHashMap<String, Uint8List> _thumbnailCache =
      LinkedHashMap<String, Uint8List>();

  Future<List<VaultItem>> loadPage({
    required int offset,
    required int limit,
    String? folderId,
  }) {
    final VaultRepository repository = vaultRepository;
    if (repository is VaultFolderRepository) {
      return (repository as VaultFolderRepository).getItemsPageByFolder(
        VaultItemType.video,
        folderId: folderId,
        limit: limit,
        offset: offset,
      );
    }
    if (repository is PaginatedVaultRepository) {
      return (repository as PaginatedVaultRepository).getItemsPageByType(
        VaultItemType.video,
        limit: limit,
        offset: offset,
      );
    }
    return _fallbackPage(offset: offset, limit: limit);
  }

  Future<Uint8List?> loadThumbnail(VaultItem item) async {
    final Uint8List? cached = _thumbnailCache.remove(item.id);
    if (cached != null) {
      _thumbnailCache[item.id] = cached;
      return cached;
    }
    final String? thumbnailPath = item.thumbnailPath;
    if (thumbnailPath == null) {
      return null;
    }
    try {
      final File file = await fileStorage.encryptedFile(
        type: VaultItemType.video,
        fileName: thumbnailPath,
      );
      if (!await file.exists()) {
        return null;
      }
      final Object? decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, Object?>) {
        return null;
      }
      final EncryptedValue encryptedValue = EncryptedValue.fromJson(decoded);
      final Uint8List bytes = await vaultSession.withMasterKey((secretKey) {
        return _cryptoService.decryptBytes(
          encryptedValue: encryptedValue,
          secretKey: secretKey,
        );
      });
      _thumbnailCache[item.id] = bytes;
      _trimCache();
      return bytes;
    } on Object {
      return null;
    }
  }

  Future<bool> delete(VaultItem item) async {
    try {
      final bool deleted = await _deletionService.delete(item);
      if (!deleted) {
        return false;
      }
      final Uint8List? cached = _thumbnailCache.remove(item.id);
      cached?.fillRange(0, cached.length, 0);
      return true;
    } on Object catch (error) {
      throw VideoVaultOperationException(cause: error);
    }
  }

  Future<void> exportAndRemove(VaultItem item) async {
    final File temporary = await _decryptToTemporary(item, purpose: 'export');
    try {
      final VideoLibraryRepository library = videoLibrary;
      if (library is! VideoLibraryExporter) {
        throw const VideoVaultOperationException();
      }
      await (library as VideoLibraryExporter).saveToLibrary(
        file: temporary,
        name: item.originalName,
        createdAt: item.createdAt,
      );
    } on Object catch (error) {
      throw AppExceptionMapper.map(
        error,
        fallback: (cause) => ExportException(cause: cause),
      );
    } finally {
      await fileStorage.deleteIfExists(temporary);
    }
    if (!await delete(item)) {
      throw const VideoVaultOperationException();
    }
  }

  Future<File> preparePlayback(VaultItem item) {
    return _decryptToTemporary(item, purpose: 'playback');
  }

  Future<void> releasePlayback(File file) => fileStorage.deleteIfExists(file);

  void clearMemoryCache() {
    for (final Uint8List bytes in _thumbnailCache.values) {
      bytes.fillRange(0, bytes.length, 0);
    }
    _thumbnailCache.clear();
  }

  Future<File> _decryptToTemporary(
    VaultItem item, {
    required String purpose,
  }) async {
    try {
      final File encrypted = await fileStorage.encryptedFile(
        type: VaultItemType.video,
        fileName: item.encryptedFileName,
      );
      if (!await encrypted.exists()) {
        throw const VaultSourceFileNotFoundException();
      }
      final String extension = _safeExtension(item.originalName);
      final String safeId = item.id.replaceAll(RegExp('[^a-zA-Z0-9_-]'), '_');
      final File temporary = await fileStorage.temporaryFile(
        '$safeId-$purpose.$extension',
      );
      await vaultSession.withMasterKey((secretKey) {
        return _cryptoService.decryptFile(
          inputFile: encrypted,
          outputFile: temporary,
          secretKey: secretKey,
        );
      });
      return temporary;
    } on AppException {
      rethrow;
    } on Object catch (error) {
      throw VideoVaultOperationException(cause: error);
    }
  }

  String _safeExtension(String name) {
    final String extension = path.extension(name).replaceFirst('.', '');
    return RegExp(r'^[a-zA-Z0-9]{1,8}$').hasMatch(extension)
        ? extension.toLowerCase()
        : 'mp4';
  }

  void _trimCache() {
    while (_thumbnailCache.length > maximumCachedThumbnails) {
      final String oldestKey = _thumbnailCache.keys.first;
      final Uint8List? removed = _thumbnailCache.remove(oldestKey);
      removed?.fillRange(0, removed.length, 0);
    }
  }

  Future<List<VaultItem>> _fallbackPage({
    required int offset,
    required int limit,
  }) async {
    final List<VaultItem> items = await vaultRepository.getItemsByType(
      VaultItemType.video,
    );
    if (offset >= items.length) {
      return <VaultItem>[];
    }
    final int end = (offset + limit).clamp(0, items.length);
    return items.sublist(offset, end);
  }
}
