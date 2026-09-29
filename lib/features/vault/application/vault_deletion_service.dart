import 'dart:io';

import 'package:uuid/uuid.dart';
import 'package:veyra/features/vault/domain/entities/vault_item.dart';
import 'package:veyra/features/vault/domain/repositories/vault_repository.dart';
import 'package:veyra/features/vault/domain/services/vault_file_storage.dart';

typedef VaultDeletionTokenGenerator = String Function();

final class VaultDeletionService {
  VaultDeletionService({
    required this.vaultRepository,
    required this.fileStorage,
    VaultDeletionTokenGenerator? tokenGenerator,
  }) : _tokenGenerator = tokenGenerator ?? const Uuid().v4;

  final VaultRepository vaultRepository;
  final VaultFileStorage fileStorage;
  final VaultDeletionTokenGenerator _tokenGenerator;

  Future<bool> delete(VaultItem item) async {
    final List<File> originals = <File>[
      await fileStorage.encryptedFile(
        type: item.type,
        fileName: item.encryptedFileName,
      ),
      if (item.thumbnailPath case final String thumbnailPath)
        await fileStorage.encryptedFile(
          type: item.type,
          fileName: thumbnailPath,
        ),
    ];
    final List<({File original, File staged})> stagedFiles =
        <({File original, File staged})>[];
    final String token = _tokenGenerator().replaceAll(
      RegExp('[^a-zA-Z0-9_-]'),
      '_',
    );

    try {
      for (int index = 0; index < originals.length; index++) {
        final File original = originals[index];
        if (!await original.exists()) {
          continue;
        }
        final File staged = File('${original.path}.$token-$index.deleting');
        await original.rename(staged.path);
        stagedFiles.add((original: original, staged: staged));
      }
    } on Object {
      await _restore(stagedFiles);
      rethrow;
    }

    try {
      final bool metadataDeleted = await vaultRepository.deleteById(item.id);
      if (!metadataDeleted) {
        await _restore(stagedFiles);
        return false;
      }
    } on Object {
      await _restore(stagedFiles);
      rethrow;
    }

    // At this point the item is no longer visible. A failed cleanup can leave
    // only an unindexed encrypted quarantine file in private vault storage.
    for (final ({File original, File staged}) entry in stagedFiles) {
      try {
        await fileStorage.deleteIfExists(entry.staged);
      } on Object {
        // The quarantine file remains encrypted and no metadata points to it.
      }
    }
    return true;
  }

  Future<void> _restore(
    List<({File original, File staged})> stagedFiles,
  ) async {
    Object? firstError;
    StackTrace? firstStackTrace;
    for (final ({File original, File staged}) entry in stagedFiles.reversed) {
      try {
        if (await entry.staged.exists()) {
          await entry.staged.rename(entry.original.path);
        }
      } on Object catch (error, stackTrace) {
        firstError ??= error;
        firstStackTrace ??= stackTrace;
      }
    }
    if (firstError != null) {
      Error.throwWithStackTrace(firstError, firstStackTrace!);
    }
  }
}
