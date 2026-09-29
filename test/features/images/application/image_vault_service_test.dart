import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:veyra/core/crypto/crypto_service.dart';
import 'package:veyra/core/errors/app_exception.dart';
import 'package:veyra/core/security/encrypted_value.dart';
import 'package:veyra/core/security/vault_session.dart';
import 'package:veyra/features/images/application/image_vault_service.dart';
import 'package:veyra/features/images/domain/entities/gallery_image.dart';
import 'package:veyra/features/images/domain/repositories/image_library_repository.dart';
import 'package:veyra/features/vault/data/storage/private_vault_file_storage.dart';
import 'package:veyra/features/vault/domain/entities/vault_item.dart';
import 'package:veyra/features/vault/domain/repositories/vault_repository.dart';

void main() {
  late Directory directory;
  late CryptoService cryptoService;
  late VaultSession vaultSession;
  late PrivateVaultFileStorage fileStorage;
  late FakeVaultRepository vaultRepository;
  late FakeImageLibrary imageLibrary;
  late ImageVaultService service;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('veyra-image-vault-');
    cryptoService = CryptoService(fileChunkSize: 32);
    vaultSession = VaultSession()
      ..open(Uint8List.fromList(List<int>.generate(32, (index) => index)));
    fileStorage = PrivateVaultFileStorage(
      directoryProvider: () async => directory,
    );
    vaultRepository = FakeVaultRepository();
    imageLibrary = FakeImageLibrary();
    service = ImageVaultService(
      vaultRepository: vaultRepository,
      fileStorage: fileStorage,
      vaultSession: vaultSession,
      imageLibrary: imageLibrary,
      cryptoService: cryptoService,
      maximumCachedThumbnails: 2,
    );
  });

  tearDown(() async {
    service.clearMemoryCache();
    vaultSession.lock();
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });

  test('loads pages through the paginated repository', () async {
    vaultRepository.items.addAll(<VaultItem>[
      _item('one'),
      _item('two'),
      _item('three'),
    ]);

    final List<VaultItem> page = await service.loadPage(offset: 1, limit: 1);

    expect(page.map((item) => item.id), <String>['two']);
    expect(vaultRepository.lastPageRequest, (1, 1));
  });

  test('decrypts only the requested thumbnail into memory', () async {
    final VaultItem item = _item('thumb', thumbnailPath: 'thumb.thumb');
    final Uint8List thumbnail = Uint8List.fromList(<int>[1, 2, 3, 4, 5]);
    final EncryptedValue encrypted = await vaultSession.withMasterKey(
      (secretKey) => cryptoService.encryptBytes(
        clearText: thumbnail,
        secretKey: secretKey,
      ),
    );
    final File thumbnailFile = await fileStorage.encryptedFile(
      type: VaultItemType.image,
      fileName: 'thumb.thumb',
    );
    await thumbnailFile.writeAsString(jsonEncode(encrypted.toJson()));

    final Uint8List? loaded = await service.loadThumbnail(item);

    expect(loaded, orderedEquals(thumbnail));
    expect(await thumbnailFile.readAsBytes(), isNot(orderedEquals(thumbnail)));
  });

  test(
    'loads one full image and removes its plaintext temporary file',
    () async {
      final VaultItem item = _item('preview');
      final Uint8List original = Uint8List.fromList(
        List<int>.generate(200, (index) => index % 251),
      );
      await _writeEncryptedImage(
        fileStorage: fileStorage,
        vaultSession: vaultSession,
        cryptoService: cryptoService,
        directory: directory,
        item: item,
        bytes: original,
      );

      final Uint8List loaded = await service.loadImage(item);

      expect(loaded, orderedEquals(original));
      final Directory temporaryDirectory = Directory(
        '${directory.path}/vault/tmp',
      );
      expect(await temporaryDirectory.list().toList(), isEmpty);
    },
  );

  test(
    'rejects corruption, leaves no plaintext, and allows deletion',
    () async {
      final VaultItem item = _item('corrupted');
      vaultRepository.items.add(item);
      final File encryptedImage = await _writeEncryptedImage(
        fileStorage: fileStorage,
        vaultSession: vaultSession,
        cryptoService: cryptoService,
        directory: directory,
        item: item,
        bytes: Uint8List.fromList(List<int>.generate(96, (index) => index)),
      );
      await _corruptAuthenticationTag(encryptedImage);

      await expectLater(
        service.loadImage(item),
        throwsA(isA<VaultFileCorruptedException>()),
      );
      expect(
        await Directory('${directory.path}/vault/tmp').list().toList(),
        isEmpty,
      );
      expect(vaultRepository.items, contains(item));

      expect(await service.delete(item), isTrue);
      expect(vaultRepository.items, isEmpty);
      expect(await encryptedImage.exists(), isFalse);
    },
  );

  test('deletes metadata, encrypted image, and encrypted thumbnail', () async {
    final VaultItem item = _item('delete', thumbnailPath: 'delete.thumb');
    vaultRepository.items.add(item);
    final File encryptedImage = await _writeEncryptedImage(
      fileStorage: fileStorage,
      vaultSession: vaultSession,
      cryptoService: cryptoService,
      directory: directory,
      item: item,
      bytes: Uint8List.fromList(<int>[1, 2, 3]),
    );
    final File thumbnail = await fileStorage.encryptedFile(
      type: VaultItemType.image,
      fileName: 'delete.thumb',
    );
    await thumbnail.writeAsString('encrypted');

    expect(await service.delete(item), isTrue);

    expect(vaultRepository.items, isEmpty);
    expect(await encryptedImage.exists(), isFalse);
    expect(await thumbnail.exists(), isFalse);
  });

  test(
    'exports to the gallery, removes the vault copy, and clears temp',
    () async {
      final VaultItem item = _item('export');
      final Uint8List original = Uint8List.fromList(<int>[9, 8, 7, 6]);
      vaultRepository.items.add(item);
      final File encryptedImage = await _writeEncryptedImage(
        fileStorage: fileStorage,
        vaultSession: vaultSession,
        cryptoService: cryptoService,
        directory: directory,
        item: item,
        bytes: original,
      );

      await service.exportAndRemove(item);

      expect(imageLibrary.savedName, item.originalName);
      expect(imageLibrary.savedBytes, orderedEquals(original));
      expect(vaultRepository.items, isEmpty);
      expect(await encryptedImage.exists(), isFalse);
      expect(
        await Directory('${directory.path}/vault/tmp').list().toList(),
        isEmpty,
      );
    },
  );
}

Future<void> _corruptAuthenticationTag(File file) async {
  final Uint8List bytes = await file.readAsBytes();
  bytes[bytes.length - 1] ^= 0xff;
  await file.writeAsBytes(bytes, flush: true);
}

Future<File> _writeEncryptedImage({
  required PrivateVaultFileStorage fileStorage,
  required VaultSession vaultSession,
  required CryptoService cryptoService,
  required Directory directory,
  required VaultItem item,
  required Uint8List bytes,
}) async {
  final File clear = File('${directory.path}/${item.id}.jpg');
  await clear.writeAsBytes(bytes);
  final File encrypted = await fileStorage.encryptedFile(
    type: VaultItemType.image,
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

VaultItem _item(String id, {String? thumbnailPath}) {
  return VaultItem(
    id: id,
    originalName: '$id.jpg',
    encryptedFileName: '$id.dat',
    type: VaultItemType.image,
    mimeType: 'image/jpeg',
    size: 100,
    createdAt: DateTime.utc(2025),
    importedAt: DateTime.utc(2026),
    thumbnailPath: thumbnailPath,
  );
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

final class FakeImageLibrary
    implements ImageLibraryRepository, ImageLibraryExporter {
  Uint8List? savedBytes;
  String? savedName;

  @override
  Future<void> saveToLibrary({
    required File file,
    required String name,
    required DateTime createdAt,
  }) async {
    savedBytes = await file.readAsBytes();
    savedName = name;
  }

  @override
  Future<void> clearCache() async {}

  @override
  Future<Set<String>> deleteOriginals(Iterable<String> ids) async => <String>{};

  @override
  Future<File?> loadOriginal(String id) async => null;

  @override
  Future<List<GalleryImage>> loadRecent({
    required int page,
    required int pageSize,
  }) async => <GalleryImage>[];

  @override
  Future<Uint8List?> loadThumbnail(String id, {required int size}) async =>
      null;

  @override
  Future<void> openSettings() async {}

  @override
  Future<ImageLibraryAccess> requestAccess() async => ImageLibraryAccess.full;
}
