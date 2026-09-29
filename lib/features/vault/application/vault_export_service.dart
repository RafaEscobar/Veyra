import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:veyra/core/crypto/crypto_service.dart';
import 'package:veyra/core/errors/app_exception.dart';
import 'package:veyra/core/errors/app_exception_mapper.dart';
import 'package:veyra/core/security/vault_session.dart';
import 'package:veyra/features/vault/application/vault_deletion_service.dart';
import 'package:veyra/features/vault/domain/entities/vault_item.dart';
import 'package:veyra/features/vault/domain/repositories/vault_repository.dart';
import 'package:veyra/features/vault/domain/services/external_file_destination.dart';
import 'package:veyra/features/vault/domain/services/vault_file_storage.dart';

final class VaultExportService {
  VaultExportService({
    required this.vaultRepository,
    required this.fileStorage,
    required this.vaultSession,
    required this.destination,
    VaultDeletionService? deletionService,
    CryptoService? cryptoService,
  }) : _cryptoService = cryptoService ?? CryptoService(),
       _deletionService =
           deletionService ??
           VaultDeletionService(
             vaultRepository: vaultRepository,
             fileStorage: fileStorage,
           );

  final VaultRepository vaultRepository;
  final VaultFileStorage fileStorage;
  final VaultSession vaultSession;
  final ExternalFileDestination destination;
  final CryptoService _cryptoService;
  final VaultDeletionService _deletionService;

  Future<ExternalFileWriteResult?> export(VaultItem item) async {
    try {
      return await _export(item);
    } on Object catch (error) {
      throw AppExceptionMapper.map(
        error,
        fallback: (cause) => ExportException(cause: cause),
      );
    }
  }

  Future<ExternalFileWriteResult?> _export(VaultItem item) async {
    final File encrypted = await fileStorage.encryptedFile(
      type: item.type,
      fileName: item.encryptedFileName,
    );
    if (!await encrypted.exists()) {
      throw const VaultSourceFileNotFoundException();
    }
    final String safeId = item.id.replaceAll(RegExp('[^a-zA-Z0-9_-]'), '_');
    final String extension = _safeExtension(item.originalName);
    final File temporary = await fileStorage.temporaryFile(
      '$safeId-export${extension.isEmpty ? '' : '.$extension'}',
    );
    try {
      await vaultSession.withMasterKey((secretKey) {
        return _cryptoService.decryptFile(
          inputFile: encrypted,
          outputFile: temporary,
          secretKey: secretKey,
        );
      });
      final ExternalFileWriteResult? result = await destination.saveFromPath(
        sourcePath: temporary.path,
        fileName: item.originalName,
        mimeType: item.mimeType,
      );
      if (result != null && result.bytesWritten != item.size) {
        throw const VaultExportVerificationException();
      }
      return result;
    } on Object catch (error) {
      throw AppExceptionMapper.map(
        error,
        fallback: (cause) => ExportException(cause: cause),
      );
    } finally {
      await fileStorage.deleteIfExists(temporary);
    }
  }

  Future<bool> removeFromVault(VaultItem item) async {
    return _deletionService.delete(item);
  }

  String _safeExtension(String name) {
    final String extension = path.extension(name).replaceFirst('.', '');
    return RegExp(r'^[a-zA-Z0-9]{1,8}$').hasMatch(extension)
        ? extension.toLowerCase()
        : '';
  }
}
