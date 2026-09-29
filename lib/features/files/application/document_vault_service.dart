import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:veyra/core/crypto/crypto_service.dart';
import 'package:veyra/core/errors/app_exception.dart';
import 'package:veyra/core/security/vault_session.dart';
import 'package:veyra/features/vault/application/vault_export_service.dart';
import 'package:veyra/features/vault/domain/entities/vault_item.dart';
import 'package:veyra/features/vault/domain/repositories/vault_repository.dart';
import 'package:veyra/features/vault/domain/services/external_file_destination.dart';
import 'package:veyra/features/vault/domain/services/vault_file_storage.dart';

final class DocumentVaultService {
  DocumentVaultService({
    required this.vaultRepository,
    required this.fileStorage,
    required this.vaultSession,
    required this.exportService,
    CryptoService? cryptoService,
    this.maximumTextPreviewBytes = 1024 * 1024,
  }) : _cryptoService = cryptoService ?? CryptoService();

  final int maximumTextPreviewBytes;
  final VaultRepository vaultRepository;
  final VaultFileStorage fileStorage;
  final VaultSession vaultSession;
  final VaultExportService exportService;
  final CryptoService _cryptoService;

  bool canPreview(VaultItem item) => _extension(item.originalName) == 'txt';

  Future<List<VaultItem>> loadPage({required int offset, required int limit}) {
    final VaultRepository repository = vaultRepository;
    if (repository is PaginatedVaultRepository) {
      return (repository as PaginatedVaultRepository).getItemsPageByType(
        VaultItemType.file,
        limit: limit,
        offset: offset,
      );
    }
    return _fallbackPage(offset: offset, limit: limit);
  }

  Future<String> loadTextPreview(VaultItem item) async {
    if (!canPreview(item) || item.size > maximumTextPreviewBytes) {
      throw const UnsupportedDocumentPreviewException();
    }
    final File encrypted = await fileStorage.encryptedFile(
      type: VaultItemType.file,
      fileName: item.encryptedFileName,
    );
    if (!await encrypted.exists()) {
      throw const VaultSourceFileNotFoundException();
    }
    final String safeId = item.id.replaceAll(RegExp('[^a-zA-Z0-9_-]'), '_');
    final File temporary = await fileStorage.temporaryFile(
      '$safeId-preview.txt',
    );
    try {
      await vaultSession.withMasterKey((secretKey) {
        return _cryptoService.decryptFile(
          inputFile: encrypted,
          outputFile: temporary,
          secretKey: secretKey,
        );
      });
      final List<int> bytes = await temporary.readAsBytes();
      return utf8.decode(bytes, allowMalformed: true);
    } finally {
      await fileStorage.deleteIfExists(temporary);
    }
  }

  Future<ExternalFileWriteResult?> export(VaultItem item) {
    return exportService.export(item);
  }

  Future<bool> delete(VaultItem item) {
    return exportService.removeFromVault(item);
  }

  String _extension(String name) {
    return path.extension(name).replaceFirst('.', '').toLowerCase();
  }

  Future<List<VaultItem>> _fallbackPage({
    required int offset,
    required int limit,
  }) async {
    final List<VaultItem> items = await vaultRepository.getItemsByType(
      VaultItemType.file,
    );
    if (offset >= items.length) {
      return <VaultItem>[];
    }
    final int end = (offset + limit).clamp(0, items.length);
    return items.sublist(offset, end);
  }
}
