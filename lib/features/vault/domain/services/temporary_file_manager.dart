import 'dart:io';

abstract interface class VaultTemporaryCleaner {
  Future<void> clear();
}

abstract interface class TemporaryFileManager implements VaultTemporaryCleaner {
  Future<File> create(String fileName);

  Future<void> release(File file);

  bool isRegistered(File file);
}
