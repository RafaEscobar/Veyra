import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:veyra/features/vault/application/vault_deletion_service.dart';
import 'package:veyra/features/vault/data/storage/private_vault_file_storage.dart';
import 'package:veyra/features/vault/domain/entities/vault_item.dart';
import 'package:veyra/features/vault/domain/repositories/vault_repository.dart';
import 'package:veyra/features/vault/domain/services/vault_file_storage.dart';

void main() {
  late Directory directory;
  late PrivateVaultFileStorage storage;
  late DeletionRepository repository;
  late VaultItem item;
  late File encrypted;
  late File thumbnail;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('veyra-delete-');
    storage = PrivateVaultFileStorage(directoryProvider: () async => directory);
    repository = DeletionRepository();
    item = VaultItem(
      id: 'private-item',
      originalName: 'private.jpg',
      encryptedFileName: 'private.dat',
      type: VaultItemType.image,
      mimeType: 'image/jpeg',
      size: 4,
      createdAt: DateTime.utc(2025),
      importedAt: DateTime.utc(2026),
      thumbnailPath: 'private.thumb',
    );
    repository.items.add(item);
    encrypted = await storage.encryptedFile(
      type: item.type,
      fileName: item.encryptedFileName,
    );
    thumbnail = await storage.encryptedFile(
      type: item.type,
      fileName: item.thumbnailPath!,
    );
    await encrypted.writeAsBytes(<int>[1, 2, 3, 4]);
    await thumbnail.writeAsBytes(<int>[5, 6]);
  });

  tearDown(() async {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });

  test('removes encrypted data, thumbnail, and metadata together', () async {
    final VaultDeletionService service = VaultDeletionService(
      vaultRepository: repository,
      fileStorage: storage,
      tokenGenerator: () => 'successful-delete',
    );

    expect(await service.delete(item), isTrue);

    expect(repository.items, isEmpty);
    expect(await encrypted.exists(), isFalse);
    expect(await thumbnail.exists(), isFalse);
    expect(await _temporaryFiles(directory), isEmpty);
  });

  test('restores encrypted files when metadata cannot be removed', () async {
    repository.deleteResult = false;
    final VaultDeletionService service = VaultDeletionService(
      vaultRepository: repository,
      fileStorage: storage,
      tokenGenerator: () => 'rejected-delete',
    );

    expect(await service.delete(item), isFalse);

    expect(repository.items, <VaultItem>[item]);
    expect(await encrypted.readAsBytes(), <int>[1, 2, 3, 4]);
    expect(await thumbnail.readAsBytes(), <int>[5, 6]);
    expect(await _temporaryFiles(directory), isEmpty);
  });

  test('restores encrypted files when metadata deletion throws', () async {
    repository.deleteError = StateError('database unavailable');
    final VaultDeletionService service = VaultDeletionService(
      vaultRepository: repository,
      fileStorage: storage,
      tokenGenerator: () => 'failed-delete',
    );

    await expectLater(service.delete(item), throwsStateError);

    expect(repository.items, <VaultItem>[item]);
    expect(await encrypted.exists(), isTrue);
    expect(await thumbnail.exists(), isTrue);
    expect(await _temporaryFiles(directory), isEmpty);
  });

  test('never leaves metadata pointing to a missing encrypted file', () async {
    final VaultDeletionService service = VaultDeletionService(
      vaultRepository: repository,
      fileStorage: CleanupFailingStorage(storage),
      tokenGenerator: () => 'cleanup-failure',
    );

    expect(await service.delete(item), isTrue);

    expect(repository.items, isEmpty);
    expect(await encrypted.exists(), isFalse);
    expect(await thumbnail.exists(), isFalse);
    final List<FileSystemEntity> quarantined = await Directory(
      '${directory.path}/vault/images',
    ).list().where((entity) => entity.path.endsWith('.deleting')).toList();
    expect(quarantined, hasLength(2));
  });
}

Future<List<FileSystemEntity>> _temporaryFiles(Directory root) async {
  final Directory temporary = Directory('${root.path}/vault/tmp');
  return temporary.existsSync() ? temporary.list().toList() : <File>[];
}

final class CleanupFailingStorage implements VaultFileStorage {
  const CleanupFailingStorage(this.delegate);

  final VaultFileStorage delegate;

  @override
  Future<void> deleteIfExists(File file) {
    throw const FileSystemException('No space available for cleanup');
  }

  @override
  Future<File> encryptedFile({
    required VaultItemType type,
    required String fileName,
  }) => delegate.encryptedFile(type: type, fileName: fileName);

  @override
  Future<File> temporaryFile(String fileName) =>
      delegate.temporaryFile(fileName);
}

final class DeletionRepository implements VaultRepository {
  final List<VaultItem> items = <VaultItem>[];
  bool deleteResult = true;
  Object? deleteError;

  @override
  Future<bool> deleteById(String id) async {
    if (deleteError case final Object error) {
      throw error;
    }
    if (!deleteResult) {
      return false;
    }
    final int before = items.length;
    items.removeWhere((candidate) => candidate.id == id);
    return items.length != before;
  }

  @override
  Future<int> countByType(VaultItemType type) async => items.length;

  @override
  Future<VaultItem?> getById(String id) async =>
      items.where((candidate) => candidate.id == id).firstOrNull;

  @override
  Future<List<VaultItem>> getItemsByType(VaultItemType type) async => items;

  @override
  Future<void> insert(VaultItem item) async => items.add(item);

  @override
  Future<bool> update(VaultItem item) async => false;
}
