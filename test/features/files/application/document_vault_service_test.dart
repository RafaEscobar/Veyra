import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:veyra/core/crypto/crypto_service.dart';
import 'package:veyra/core/errors/app_exception.dart';
import 'package:veyra/core/security/vault_session.dart';
import 'package:veyra/features/files/application/document_vault_service.dart';
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
  late DocumentVaultService service;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('veyra-document-vault-');
    cryptoService = CryptoService(fileChunkSize: 32);
    vaultSession = VaultSession()
      ..open(Uint8List.fromList(List<int>.generate(32, (index) => index)));
    storage = PrivateVaultFileStorage(directoryProvider: () async => directory);
    repository = FakeVaultRepository();
    service = DocumentVaultService(
      vaultRepository: repository,
      fileStorage: storage,
      vaultSession: vaultSession,
      exportService: VaultExportService(
        vaultRepository: repository,
        fileStorage: storage,
        vaultSession: vaultSession,
        destination: const CancelingDestination(),
        cryptoService: cryptoService,
      ),
      cryptoService: cryptoService,
      maximumTextPreviewBytes: 100,
    );
  });

  tearDown(() async {
    vaultSession.lock();
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });

  test('loads paginated file metadata', () async {
    repository.items.addAll(<VaultItem>[
      _item('first.txt', size: 1),
      _item('second.pdf', size: 2),
    ]);

    final List<VaultItem> page = await service.loadPage(offset: 1, limit: 1);

    expect(page.map((item) => item.originalName), <String>['second.pdf']);
    expect(repository.lastPageRequest, (1, 1));
  });

  test('decrypts text preview and removes its plaintext temporary', () async {
    const String content = 'Contenido privado\nSegunda línea';
    final Uint8List bytes = Uint8List.fromList(utf8.encode(content));
    final VaultItem item = _item('notes.txt', size: bytes.length);
    await _writeEncrypted(
      directory: directory,
      storage: storage,
      vaultSession: vaultSession,
      cryptoService: cryptoService,
      item: item,
      bytes: bytes,
    );

    expect(await service.loadTextPreview(item), content);
    expect(
      await Directory('${directory.path}/vault/tmp').list().toList(),
      isEmpty,
    );
  });

  test('limits preview to supported and reasonably sized text files', () async {
    expect(service.canPreview(_item('notes.txt', size: 10)), isTrue);
    expect(service.canPreview(_item('report.pdf', size: 10)), isFalse);
    await expectLater(
      service.loadTextPreview(_item('large.txt', size: 101)),
      throwsA(isA<UnsupportedDocumentPreviewException>()),
    );
    await expectLater(
      service.loadTextPreview(_item('report.pdf', size: 10)),
      throwsA(isA<UnsupportedDocumentPreviewException>()),
    );
  });

  test(
    'rejects corruption, leaves no plaintext, and allows deletion',
    () async {
      final VaultItem item = _item('corrupted.txt', size: 32);
      repository.items.add(item);
      await _writeEncrypted(
        directory: directory,
        storage: storage,
        vaultSession: vaultSession,
        cryptoService: cryptoService,
        item: item,
        bytes: Uint8List.fromList(List<int>.generate(32, (index) => index)),
      );
      final File encrypted = await storage.encryptedFile(
        type: VaultItemType.file,
        fileName: item.encryptedFileName,
      );
      await _corruptAuthenticationTag(encrypted);

      await expectLater(
        service.loadTextPreview(item),
        throwsA(isA<VaultFileCorruptedException>()),
      );
      expect(
        await Directory('${directory.path}/vault/tmp').list().toList(),
        isEmpty,
      );
      expect(repository.items, contains(item));

      expect(await service.delete(item), isTrue);
      expect(repository.items, isEmpty);
      expect(await encrypted.exists(), isFalse);
    },
  );
}

Future<void> _corruptAuthenticationTag(File file) async {
  final Uint8List bytes = await file.readAsBytes();
  bytes[bytes.length - 1] ^= 0xff;
  await file.writeAsBytes(bytes, flush: true);
}

Future<void> _writeEncrypted({
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
    type: VaultItemType.file,
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
}

VaultItem _item(String name, {required int size}) => VaultItem(
  id: name,
  originalName: name,
  encryptedFileName: '${name.hashCode}.dat',
  type: VaultItemType.file,
  mimeType: name.endsWith('.txt') ? 'text/plain' : 'application/pdf',
  size: size,
  createdAt: DateTime.utc(2025),
  importedAt: DateTime.utc(2026),
);

final class CancelingDestination implements ExternalFileDestination {
  const CancelingDestination();

  @override
  Future<ExternalFileWriteResult?> saveFromPath({
    required String sourcePath,
    required String fileName,
    required String mimeType,
  }) async => null;
}

final class FakeVaultRepository
    implements VaultRepository, PaginatedVaultRepository {
  final List<VaultItem> items = <VaultItem>[];
  (int, int)? lastPageRequest;

  @override
  Future<int> countByType(VaultItemType type) async => items.length;

  @override
  Future<bool> deleteById(String id) async {
    final int before = items.length;
    items.removeWhere((item) => item.id == id);
    return items.length != before;
  }

  @override
  Future<VaultItem?> getById(String id) async => null;

  @override
  Future<List<VaultItem>> getItemsByType(VaultItemType type) async => items;

  @override
  Future<List<VaultItem>> getItemsPageByType(
    VaultItemType type, {
    required int limit,
    required int offset,
  }) async {
    lastPageRequest = (offset, limit);
    return items.skip(offset).take(limit).toList(growable: false);
  }

  @override
  Future<void> insert(VaultItem item) async => items.add(item);

  @override
  Future<bool> update(VaultItem item) async => false;
}
