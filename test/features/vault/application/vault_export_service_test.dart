import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:veyra/core/crypto/crypto_service.dart';
import 'package:veyra/core/errors/app_exception.dart';
import 'package:veyra/core/security/vault_session.dart';
import 'package:veyra/features/vault/application/vault_export_service.dart';
import 'package:veyra/features/vault/data/storage/private_vault_file_storage.dart';
import 'package:veyra/features/vault/domain/entities/vault_item.dart';
import 'package:veyra/features/vault/domain/repositories/vault_repository.dart';
import 'package:veyra/features/vault/domain/services/external_file_destination.dart';

void main() {
  late Directory directory;
  late CryptoService cryptoService;
  late VaultSession vaultSession;
  late PrivateVaultFileStorage storage;
  late FakeVaultRepository repository;
  late FakeExternalFileDestination destination;
  late VaultExportService service;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('veyra-export-');
    cryptoService = CryptoService(fileChunkSize: 32);
    vaultSession = VaultSession()
      ..open(Uint8List.fromList(List<int>.generate(32, (index) => index)));
    storage = PrivateVaultFileStorage(directoryProvider: () async => directory);
    repository = FakeVaultRepository();
    destination = FakeExternalFileDestination(directory);
    service = VaultExportService(
      vaultRepository: repository,
      fileStorage: storage,
      vaultSession: vaultSession,
      destination: destination,
      cryptoService: cryptoService,
    );
  });

  tearDown(() async {
    vaultSession.lock();
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });

  test(
    'exports, verifies bytes, cleans temp, and keeps vault original',
    () async {
      final Uint8List clear = Uint8List.fromList(<int>[1, 2, 3, 4, 5]);
      final VaultItem item = _item(size: clear.length);
      repository.items.add(item);
      final File encrypted = await _writeEncryptedFile(
        directory: directory,
        storage: storage,
        vaultSession: vaultSession,
        cryptoService: cryptoService,
        item: item,
        bytes: clear,
      );

      final ExternalFileWriteResult? result = await service.export(item);

      expect(result?.bytesWritten, clear.length);
      expect(await destination.savedFile!.readAsBytes(), orderedEquals(clear));
      expect(await encrypted.exists(), isTrue);
      expect(repository.items, <VaultItem>[item]);
      expect(
        await Directory('${directory.path}/vault/tmp').list().toList(),
        isEmpty,
      );
    },
  );

  test(
    'canceling destination keeps encrypted original and cleans temp',
    () async {
      final Uint8List clear = Uint8List.fromList(<int>[9, 8, 7]);
      final VaultItem item = _item(size: clear.length);
      repository.items.add(item);
      destination.cancel = true;
      final File encrypted = await _writeEncryptedFile(
        directory: directory,
        storage: storage,
        vaultSession: vaultSession,
        cryptoService: cryptoService,
        item: item,
        bytes: clear,
      );

      expect(await service.export(item), isNull);

      expect(await encrypted.exists(), isTrue);
      expect(repository.items, <VaultItem>[item]);
      expect(
        await Directory('${directory.path}/vault/tmp').list().toList(),
        isEmpty,
      );
    },
  );

  test('rejects mismatched writes without deleting vault original', () async {
    final Uint8List clear = Uint8List.fromList(<int>[3, 3, 3, 3]);
    final VaultItem item = _item(size: clear.length);
    repository.items.add(item);
    destination.reportedBytes = clear.length - 1;
    final File encrypted = await _writeEncryptedFile(
      directory: directory,
      storage: storage,
      vaultSession: vaultSession,
      cryptoService: cryptoService,
      item: item,
      bytes: clear,
    );

    await expectLater(
      service.export(item),
      throwsA(isA<VaultExportVerificationException>()),
    );

    expect(await encrypted.exists(), isTrue);
    expect(repository.items, <VaultItem>[item]);
    expect(
      await Directory('${directory.path}/vault/tmp').list().toList(),
      isEmpty,
    );
  });

  test('removes encrypted original only after an explicit call', () async {
    final Uint8List clear = Uint8List.fromList(<int>[6, 7, 8]);
    final VaultItem item = _item(size: clear.length);
    repository.items.add(item);
    final File encrypted = await _writeEncryptedFile(
      directory: directory,
      storage: storage,
      vaultSession: vaultSession,
      cryptoService: cryptoService,
      item: item,
      bytes: clear,
    );

    await service.export(item);
    expect(await encrypted.exists(), isTrue);

    expect(await service.removeFromVault(item), isTrue);
    expect(await encrypted.exists(), isFalse);
    expect(repository.items, isEmpty);
  });
}

Future<File> _writeEncryptedFile({
  required Directory directory,
  required PrivateVaultFileStorage storage,
  required VaultSession vaultSession,
  required CryptoService cryptoService,
  required VaultItem item,
  required Uint8List bytes,
}) async {
  final File clear = File('${directory.path}/clear.txt');
  await clear.writeAsBytes(bytes);
  final File encrypted = await storage.encryptedFile(
    type: item.type,
    fileName: item.encryptedFileName,
  );
  await vaultSession.withMasterKey((secretKey) {
    return cryptoService.encryptFile(
      inputFile: clear,
      outputFile: encrypted,
      secretKey: secretKey,
    );
  });
  await clear.delete();
  return encrypted;
}

VaultItem _item({required int size}) => VaultItem(
  id: 'file-id',
  originalName: 'notes.txt',
  encryptedFileName: 'file-id.dat',
  type: VaultItemType.file,
  mimeType: 'text/plain',
  size: size,
  createdAt: DateTime.utc(2025),
  importedAt: DateTime.utc(2026),
);

final class FakeExternalFileDestination implements ExternalFileDestination {
  FakeExternalFileDestination(this.directory);

  final Directory directory;
  bool cancel = false;
  int? reportedBytes;
  File? savedFile;

  @override
  Future<ExternalFileWriteResult?> saveFromPath({
    required String sourcePath,
    required String fileName,
    required String mimeType,
  }) async {
    if (cancel) {
      return null;
    }
    final File source = File(sourcePath);
    final File destination = File('${directory.path}/exported-$fileName');
    await source.copy(destination.path);
    savedFile = destination;
    return ExternalFileWriteResult(
      uri: destination.uri,
      bytesWritten: reportedBytes ?? await destination.length(),
    );
  }
}

final class FakeVaultRepository implements VaultRepository {
  final List<VaultItem> items = <VaultItem>[];

  @override
  Future<int> countByType(VaultItemType type) async => items.length;

  @override
  Future<bool> deleteById(String id) async {
    final int before = items.length;
    items.removeWhere((item) => item.id == id);
    return before != items.length;
  }

  @override
  Future<VaultItem?> getById(String id) async => null;

  @override
  Future<List<VaultItem>> getItemsByType(VaultItemType type) async => items;

  @override
  Future<void> insert(VaultItem item) async => items.add(item);

  @override
  Future<bool> update(VaultItem item) async => false;
}
