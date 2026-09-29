import 'dart:io';

import 'package:veyra/features/vault/domain/entities/vault_item.dart';

abstract interface class VaultFileStorage {
  Future<File> encryptedFile({
    required VaultItemType type,
    required String fileName,
  });

  Future<File> temporaryFile(String fileName);

  Future<void> deleteIfExists(File file);
}
