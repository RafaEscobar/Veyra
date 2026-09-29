import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:veyra/core/crypto/crypto_service.dart';
import 'package:veyra/core/errors/app_exception.dart';
import 'package:veyra/core/security/encrypted_value.dart';
import 'package:veyra/core/security/vault_session.dart';
import 'package:veyra/features/images/domain/repositories/image_library_repository.dart';
import 'package:veyra/features/vault/data/storage/private_vault_file_storage.dart';
import 'package:veyra/features/vault/domain/entities/vault_item.dart';
import 'package:veyra/features/vault/domain/repositories/vault_repository.dart';
import 'package:veyra/features/videos/application/video_vault_service.dart';
import 'package:veyra/features/videos/domain/entities/gallery_video.dart';
import 'package:veyra/features/videos/domain/repositories/video_library_repository.dart';

void main() {
  late Directory directory;
  late CryptoService cryptoService;
  late VaultSession vaultSession;
  late PrivateVaultFileStorage fileStorage;
  late FakeVaultRepository vaultRepository;
  late FakeVideoLibrary videoLibrary;
  late VideoVaultService service;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('veyra-video-vault-');
    cryptoService = CryptoService(fileChunkSize: 32);
    vaultSession = VaultSession()
      ..open(Uint8List.fromList(List<int>.generate(32, (index) => index)));
    fileStorage = PrivateVaultFileStorage(
      directoryProvider: () async => directory,
    );
    vaultRepository = FakeVaultRepository();
    videoLibrary = FakeVideoLibrary();
    service = VideoVaultService(
      vaultRepository: vaultRepository,
      fileStorage: fileStorage,
      vaultSession: vaultSession,
      videoLibrary: videoLibrary,
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

  test('loads paginated videos and decrypts requested thumbnail', () async {
    final VaultItem first = _item('first');
    final VaultItem second = _item('second', thumbnailPath: 'second.thumb');
    vaultRepository.items.addAll(<VaultItem>[first, second]);
    final Uint8List thumbnail = Uint8List.fromList(<int>[5, 4, 3, 2, 1]);
    final EncryptedValue encrypted = await vaultSession.withMasterKey(
      (secretKey) => cryptoService.encryptBytes(
        clearText: thumbnail,
        secretKey: secretKey,
      ),
    );
    final File thumbnailFile = await fileStorage.encryptedFile(
      type: VaultItemType.video,
      fileName: 'second.thumb',
    );
    await thumbnailFile.writeAsString(jsonEncode(encrypted.toJson()));

    final List<VaultItem> page = await service.loadPage(offset: 1, limit: 1);
    final Uint8List? loadedThumbnail = await service.loadThumbnail(second);

    expect(page, <VaultItem>[second]);
    expect(vaultRepository.lastPageRequest, (1, 1));
    expect(loadedThumbnail, orderedEquals(thumbnail));
  });

  test('deletes metadata, encrypted video, and thumbnail', () async {
    final VaultItem item = _item('delete', thumbnailPath: 'delete.thumb');
    vaultRepository.items.add(item);
    final File encryptedVideo = await _writeEncryptedVideo(
      fileStorage: fileStorage,
      vaultSession: vaultSession,
      cryptoService: cryptoService,
      directory: directory,
      item: item,
      bytes: Uint8List.fromList(<int>[1, 2, 3]),
    );
    final File thumbnail = await fileStorage.encryptedFile(
      type: VaultItemType.video,
      fileName: 'delete.thumb',
    );
    await thumbnail.writeAsString('encrypted');

    expect(await service.delete(item), isTrue);

    expect(vaultRepository.items, isEmpty);
    expect(await encryptedVideo.exists(), isFalse);
    expect(await thumbnail.exists(), isFalse);
  });

  test('exports to gallery and removes plaintext and vault copies', () async {
    final VaultItem item = _item('export');
    final Uint8List original = Uint8List.fromList(<int>[9, 8, 7, 6]);
    vaultRepository.items.add(item);
    final File encryptedVideo = await _writeEncryptedVideo(
      fileStorage: fileStorage,
      vaultSession: vaultSession,
      cryptoService: cryptoService,
      directory: directory,
      item: item,
      bytes: original,
    );

    await service.exportAndRemove(item);

    expect(videoLibrary.savedName, item.originalName);
    expect(videoLibrary.savedBytes, orderedEquals(original));
    expect(vaultRepository.items, isEmpty);
    expect(await encryptedVideo.exists(), isFalse);
    expect(
      await Directory('${directory.path}/vault/tmp').list().toList(),
      isEmpty,
    );
  });

  test(
    'rejects corruption, leaves no plaintext, and allows deletion',
    () async {
      final VaultItem item = _item('corrupted');
      vaultRepository.items.add(item);
      final File encryptedVideo = await _writeEncryptedVideo(
        fileStorage: fileStorage,
        vaultSession: vaultSession,
        cryptoService: cryptoService,
        directory: directory,
        item: item,
        bytes: Uint8List.fromList(List<int>.generate(96, (index) => index)),
      );
      await _corruptAuthenticationTag(encryptedVideo);

      await expectLater(
        service.preparePlayback(item),
        throwsA(isA<VaultFileCorruptedException>()),
      );
      expect(
        await Directory('${directory.path}/vault/tmp').list().toList(),
        isEmpty,
      );
      expect(vaultRepository.items, contains(item));

      expect(await service.delete(item), isTrue);
      expect(vaultRepository.items, isEmpty);
      expect(await encryptedVideo.exists(), isFalse);
    },
  );

  test('prepares a private playback file and removes it on release', () async {
    final VaultItem item = _item('playback');
    final Uint8List original = Uint8List.fromList(<int>[4, 3, 2, 1]);
    await _writeEncryptedVideo(
      fileStorage: fileStorage,
      vaultSession: vaultSession,
      cryptoService: cryptoService,
      directory: directory,
      item: item,
      bytes: original,
    );

    final File playbackFile = await service.preparePlayback(item);

    expect(playbackFile.path, contains('/vault/tmp/'));
    expect(await playbackFile.readAsBytes(), orderedEquals(original));

    await service.releasePlayback(playbackFile);
    expect(await playbackFile.exists(), isFalse);
  });
}

Future<void> _corruptAuthenticationTag(File file) async {
  final Uint8List bytes = await file.readAsBytes();
  bytes[bytes.length - 1] ^= 0xff;
  await file.writeAsBytes(bytes, flush: true);
}

Future<File> _writeEncryptedVideo({
  required PrivateVaultFileStorage fileStorage,
  required VaultSession vaultSession,
  required CryptoService cryptoService,
  required Directory directory,
  required VaultItem item,
  required Uint8List bytes,
}) async {
  final File clear = File('${directory.path}/${item.id}.mp4');
  await clear.writeAsBytes(bytes);
  final File encrypted = await fileStorage.encryptedFile(
    type: VaultItemType.video,
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
    originalName: '$id.mp4',
    encryptedFileName: '$id.dat',
    type: VaultItemType.video,
    mimeType: 'video/mp4',
    size: 100,
    createdAt: DateTime.utc(2025),
    importedAt: DateTime.utc(2026),
    thumbnailPath: thumbnailPath,
    duration: const Duration(minutes: 1, seconds: 5),
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

final class FakeVideoLibrary
    implements VideoLibraryRepository, VideoLibraryExporter {
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
  Future<File?> loadOriginal(String id) async => null;

  @override
  Future<List<GalleryVideo>> loadRecent({
    required int page,
    required int pageSize,
  }) async => <GalleryVideo>[];

  @override
  Future<Uint8List?> loadThumbnail(String id, {required int size}) async =>
      null;

  @override
  Future<void> openSettings() async {}

  @override
  Future<ImageLibraryAccess> requestAccess() async => ImageLibraryAccess.full;
}
