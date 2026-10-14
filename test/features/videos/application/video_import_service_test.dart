import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:veyra/core/crypto/crypto_service.dart';
import 'package:veyra/core/errors/app_exception.dart';
import 'package:veyra/core/security/vault_session.dart';
import 'package:veyra/features/images/domain/repositories/image_library_repository.dart';
import 'package:veyra/features/vault/data/storage/private_vault_file_storage.dart';
import 'package:veyra/features/vault/domain/entities/vault_item.dart';
import 'package:veyra/features/vault/domain/repositories/vault_repository.dart';
import 'package:veyra/features/videos/application/video_import_service.dart';
import 'package:veyra/features/videos/domain/entities/gallery_video.dart';
import 'package:veyra/features/videos/domain/entities/video_import_result.dart';
import 'package:veyra/features/videos/domain/repositories/video_library_repository.dart';

void main() {
  late Directory directory;
  late FakeVideoLibraryRepository videoLibrary;
  late FakeVaultRepository vaultRepository;
  late VaultSession vaultSession;
  late PrivateVaultFileStorage fileStorage;
  late CryptoService cryptoService;
  late int nextId;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('veyra-video-import-');
    videoLibrary = FakeVideoLibraryRepository();
    vaultRepository = FakeVaultRepository();
    vaultSession = VaultSession()
      ..open(Uint8List.fromList(List<int>.generate(32, (index) => index)));
    fileStorage = PrivateVaultFileStorage(
      directoryProvider: () async => directory,
    );
    cryptoService = CryptoService(fileChunkSize: 64);
    nextId = 0;
  });

  tearDown(() async {
    vaultSession.lock();
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });

  test('encrypts a video by chunks and stores metadata', () async {
    final Uint8List videoBytes = _mp4Bytes(1024);
    final File source = File('${directory.path}/source.mp4');
    await source.writeAsBytes(videoBytes);
    videoLibrary.files['video-1'] = source;
    final Uint8List thumbnailBytes = Uint8List.fromList(<int>[1, 2, 3, 4]);
    videoLibrary.thumbnails['video-1'] = thumbnailBytes.asUnmodifiableView();
    final VideoImportService service = _service(
      videoLibrary: videoLibrary,
      vaultRepository: vaultRepository,
      fileStorage: fileStorage,
      vaultSession: vaultSession,
      cryptoService: cryptoService,
      idGenerator: () => 'video-id-${nextId++}',
    );
    final List<(int, int)> progress = <(int, int)>[];

    final VideoImportResult result = await service.importVideos(<GalleryVideo>[
      _galleryVideo('video-1', 'recuerdo.mp4'),
    ], onProgress: (completed, total) => progress.add((completed, total)));

    expect(result.failed, isEmpty);
    expect(result.imported, hasLength(1));
    expect(progress, <(int, int)>[(1, 1)]);
    expect(videoLibrary.cacheCleared, isTrue);
    final VaultItem item = vaultRepository.items.single;
    expect(item.type, VaultItemType.video);
    expect(item.mimeType, 'video/mp4');
    expect(item.size, videoBytes.length);
    expect(item.duration, const Duration(seconds: 42));
    expect(
      item.thumbnailPath,
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\.thumb$',
        ),
      ),
    );
    expect(item.thumbnailPath, isNot('video-id-0.thumb'));
    expect(thumbnailBytes, <int>[1, 2, 3, 4]);

    final File encrypted = File(
      '${directory.path}/vault/videos/video-id-0.dat',
    );
    final File decrypted = File('${directory.path}/decrypted.mp4');
    final File encryptedThumbnail = File(
      '${directory.path}/vault/videos/${item.thumbnailPath}',
    );
    expect(await encryptedThumbnail.exists(), isTrue);
    expect(await encrypted.readAsBytes(), isNot(orderedEquals(videoBytes)));
    await vaultSession.withMasterKey((secretKey) {
      return cryptoService.decryptFile(
        inputFile: encrypted,
        outputFile: decrypted,
        secretKey: secretKey,
      );
    });
    expect(await decrypted.readAsBytes(), orderedEquals(videoBytes));
  });

  test('identifies videos at or above the warning threshold', () async {
    final File small = File('${directory.path}/small.mp4');
    final File large = File('${directory.path}/large.mp4');
    await small.writeAsBytes(_mp4Bytes(99));
    await large.writeAsBytes(_mp4Bytes(100));
    videoLibrary.files
      ..['small'] = small
      ..['large'] = large;
    final VideoImportService service = _service(
      videoLibrary: videoLibrary,
      vaultRepository: vaultRepository,
      fileStorage: fileStorage,
      vaultSession: vaultSession,
      cryptoService: cryptoService,
      idGenerator: () => 'unused',
      warningVideoBytes: 100,
    );

    final List<GalleryVideo> largeVideos = await service.videosRequiringWarning(
      <GalleryVideo>[
        _galleryVideo('small', 'small.mp4'),
        _galleryVideo('large', 'large.mp4'),
      ],
    );

    expect(largeVideos.map((video) => video.id), <String>['large']);
    expect(videoLibrary.cacheCleared, isFalse);
    await service.discardPreparedFiles();
    expect(videoLibrary.cacheCleared, isTrue);
  });

  test('imports MP4 and MOV videos', () async {
    final File mp4 = File('${directory.path}/format.mp4');
    final File mov = File('${directory.path}/format.mov');
    await mp4.writeAsBytes(_mp4Bytes(128));
    await mov.writeAsBytes(_movBytes(128));
    videoLibrary.files
      ..['mp4'] = mp4
      ..['mov'] = mov;
    final VideoImportService service = _service(
      videoLibrary: videoLibrary,
      vaultRepository: vaultRepository,
      fileStorage: fileStorage,
      vaultSession: vaultSession,
      cryptoService: CryptoService(fileChunkSize: 1024),
      idGenerator: () => 'format-video-${nextId++}',
    );

    final VideoImportResult result = await service.importVideos(<GalleryVideo>[
      _galleryVideo('mp4', 'format.mp4'),
      _galleryVideo('mov', 'format.mov'),
    ]);

    expect(result.failed, isEmpty);
    expect(result.imported, hasLength(2));
    expect(
      result.imported.map((entry) => entry.item.mimeType).toSet(),
      containsAll(<String>{'video/mp4', 'video/quicktime'}),
    );
  });

  test('imports videos of 20 MB and 100 MB', () async {
    const List<int> sizes = <int>[20 * 1024 * 1024, 100 * 1024 * 1024];
    for (int index = 0; index < sizes.length; index++) {
      videoLibrary.files['size-$index'] = await _createSparseFile(
        '${directory.path}/size-$index.mp4',
        sizes[index],
        _mp4Bytes(32),
      );
    }
    final VideoImportService service = _service(
      videoLibrary: videoLibrary,
      vaultRepository: vaultRepository,
      fileStorage: fileStorage,
      vaultSession: vaultSession,
      cryptoService: CryptoService(fileChunkSize: 4 * 1024 * 1024),
      idGenerator: () => 'sized-video-${nextId++}',
    );

    final VideoImportResult result = await service.importVideos(<GalleryVideo>[
      _galleryVideo('size-0', 'twenty-megabytes.mp4'),
      _galleryVideo('size-1', 'one-hundred-megabytes.mp4'),
    ]);

    expect(result.failed, isEmpty);
    expect(
      result.imported.map((entry) => entry.item.size),
      orderedEquals(sizes),
    );
  });

  test('keeps successful videos when other imports fail validation', () async {
    final File valid = File('${directory.path}/valid.mp4');
    final File invalid = File('${directory.path}/invalid.txt');
    final File tooLarge = File('${directory.path}/large.mp4');
    await valid.writeAsBytes(_mp4Bytes(80));
    await invalid.writeAsString('not a video');
    await tooLarge.writeAsBytes(_mp4Bytes(101));
    videoLibrary.files
      ..['valid'] = valid
      ..['invalid'] = invalid
      ..['large'] = tooLarge;
    final VideoImportService service = _service(
      videoLibrary: videoLibrary,
      vaultRepository: vaultRepository,
      fileStorage: fileStorage,
      vaultSession: vaultSession,
      cryptoService: cryptoService,
      idGenerator: () => 'batch-${nextId++}',
      maximumVideoBytes: 100,
    );

    final VideoImportResult result = await service.importVideos(<GalleryVideo>[
      _galleryVideo('valid', 'valid.mp4'),
      _galleryVideo('missing', 'missing.mp4'),
      _galleryVideo('invalid', 'invalid.txt'),
      _galleryVideo('large', 'large.mp4'),
    ]);

    expect(result.imported, hasLength(1));
    expect(result.failed, hasLength(3));
    expect(result.failed[0].error, isA<VaultSourceFileNotFoundException>());
    expect(result.failed[1].error, isA<InvalidVideoTypeException>());
    expect(result.failed[2].error, isA<VideoTooLargeException>());
  });

  test('removes encrypted video when metadata insertion fails', () async {
    final File source = File('${directory.path}/source.mp4');
    await source.writeAsBytes(_mp4Bytes(128));
    videoLibrary.files['video'] = source;
    vaultRepository.failInserts = true;
    final VideoImportService service = _service(
      videoLibrary: videoLibrary,
      vaultRepository: vaultRepository,
      fileStorage: fileStorage,
      vaultSession: vaultSession,
      cryptoService: cryptoService,
      idGenerator: () => 'rollback-video',
    );

    final VideoImportResult result = await service.importVideos(<GalleryVideo>[
      _galleryVideo('video', 'video.mp4'),
    ]);

    expect(result.imported, isEmpty);
    expect(result.failed.single.error, isA<VideoImportException>());
    expect(
      await File('${directory.path}/vault/videos/rollback-video.dat').exists(),
      isFalse,
    );
  });
}

VideoImportService _service({
  required FakeVideoLibraryRepository videoLibrary,
  required FakeVaultRepository vaultRepository,
  required PrivateVaultFileStorage fileStorage,
  required VaultSession vaultSession,
  required CryptoService cryptoService,
  required VideoIdGenerator idGenerator,
  int warningVideoBytes = 100 * 1024 * 1024,
  int maximumVideoBytes = 500 * 1024 * 1024,
}) {
  return VideoImportService(
    videoLibrary: videoLibrary,
    vaultRepository: vaultRepository,
    fileStorage: fileStorage,
    vaultSession: vaultSession,
    cryptoService: cryptoService,
    idGenerator: idGenerator,
    utcNow: () => DateTime.utc(2026, 9, 29),
    warningVideoBytes: warningVideoBytes,
    maximumVideoBytes: maximumVideoBytes,
  );
}

GalleryVideo _galleryVideo(String id, String name) {
  return GalleryVideo(
    id: id,
    name: name,
    createdAt: DateTime.utc(2025, 6),
    duration: const Duration(seconds: 42),
    mimeType: 'video/mp4',
  );
}

Uint8List _mp4Bytes(int length) {
  final Uint8List bytes = Uint8List(length);
  bytes.setRange(0, 12, <int>[
    0x00,
    0x00,
    0x00,
    0x18,
    0x66,
    0x74,
    0x79,
    0x70,
    0x69,
    0x73,
    0x6f,
    0x6d,
  ]);
  for (int index = 12; index < length; index++) {
    bytes[index] = index % 251;
  }
  return bytes;
}

Uint8List _movBytes(int length) {
  final Uint8List bytes = _mp4Bytes(length);
  bytes.setRange(8, 12, <int>[0x71, 0x74, 0x20, 0x20]);
  return bytes;
}

Future<File> _createSparseFile(
  String filePath,
  int length,
  List<int> header,
) async {
  final File file = File(filePath);
  final RandomAccessFile writer = await file.open(mode: FileMode.write);
  try {
    await writer.writeFrom(header);
    await writer.truncate(length);
  } finally {
    await writer.close();
  }
  return file;
}

final class FakeVideoLibraryRepository implements VideoLibraryRepository {
  final Map<String, File> files = <String, File>{};
  final Map<String, Uint8List> thumbnails = <String, Uint8List>{};
  bool cacheCleared = false;

  @override
  Future<void> clearCache() async {
    cacheCleared = true;
  }

  @override
  Future<File?> loadOriginal(String id) async => files[id];

  @override
  Future<List<GalleryVideo>> loadRecent({
    required int page,
    required int pageSize,
  }) async {
    return <GalleryVideo>[];
  }

  @override
  Future<Uint8List?> loadThumbnail(String id, {required int size}) async {
    return thumbnails[id];
  }

  @override
  Future<void> openSettings() async {}

  @override
  Future<ImageLibraryAccess> requestAccess() async {
    return ImageLibraryAccess.full;
  }
}

final class FakeVaultRepository implements VaultRepository {
  final List<VaultItem> items = <VaultItem>[];
  bool failInserts = false;

  @override
  Future<int> countByType(VaultItemType type) async {
    return items.where((item) => item.type == type).length;
  }

  @override
  Future<bool> deleteById(String id) async => false;

  @override
  Future<VaultItem?> getById(String id) async => null;

  @override
  Future<List<VaultItem>> getItemsByType(VaultItemType type) async {
    return items.where((item) => item.type == type).toList(growable: false);
  }

  @override
  Future<void> insert(VaultItem item) async {
    if (failInserts) {
      throw StateError('database unavailable');
    }
    items.add(item);
  }

  @override
  Future<bool> update(VaultItem item) async => false;
}
