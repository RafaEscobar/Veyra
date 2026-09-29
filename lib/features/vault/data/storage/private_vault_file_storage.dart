import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:veyra/features/vault/domain/entities/vault_item.dart';
import 'package:veyra/features/vault/domain/services/temporary_file_manager.dart';
import 'package:veyra/features/vault/domain/services/vault_file_storage.dart';

typedef PrivateDirectoryProvider = Future<Directory> Function();

final class PrivateVaultFileStorage implements VaultFileStorage {
  const PrivateVaultFileStorage({
    PrivateDirectoryProvider? directoryProvider,
    this.temporaryFileManager,
  }) : _directoryProvider = directoryProvider ?? getApplicationSupportDirectory;

  final PrivateDirectoryProvider _directoryProvider;
  final TemporaryFileManager? temporaryFileManager;

  @override
  Future<File> encryptedFile({
    required VaultItemType type,
    required String fileName,
  }) async {
    if (path.basename(fileName) != fileName) {
      throw const FormatException('Invalid encrypted file name.');
    }
    final Directory root = await _directoryProvider();
    final Directory directory = Directory(
      path.join(root.path, 'vault', '${type.storageValue}s'),
    );
    await directory.create(recursive: true);
    return File(path.join(directory.path, fileName));
  }

  @override
  Future<File> temporaryFile(String fileName) async {
    if (path.basename(fileName) != fileName) {
      throw const FormatException('Invalid temporary file name.');
    }
    final TemporaryFileManager? manager = temporaryFileManager;
    if (manager != null) {
      return manager.create(fileName);
    }
    final Directory root = await _directoryProvider();
    final Directory directory = Directory(path.join(root.path, 'vault', 'tmp'));
    await directory.create(recursive: true);
    return File(path.join(directory.path, fileName));
  }

  @override
  Future<void> deleteIfExists(File file) async {
    final TemporaryFileManager? manager = temporaryFileManager;
    if (manager != null && manager.isRegistered(file)) {
      await manager.release(file);
      return;
    }
    if (await file.exists()) {
      await file.delete();
    }
  }
}
