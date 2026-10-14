import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:veyra/core/crypto/crypto_service.dart';
import 'package:veyra/core/errors/app_exception.dart';
import 'package:veyra/core/errors/debug_error_log.dart';
import 'package:veyra/core/security/vault_session.dart';
import 'package:veyra/features/images/application/image_import_service.dart';
import 'package:veyra/features/images/domain/entities/gallery_image.dart';
import 'package:veyra/features/images/domain/entities/image_import_result.dart';
import 'package:veyra/features/images/domain/repositories/image_library_repository.dart';
import 'package:veyra/features/vault/data/storage/private_vault_file_storage.dart';
import 'package:veyra/features/vault/domain/entities/vault_item.dart';
import 'package:veyra/features/vault/domain/repositories/vault_repository.dart';

void main() {
  late Directory directory;
  late FakeImageLibraryRepository imageLibrary;
  late FakeVaultRepository vaultRepository;
  late VaultSession vaultSession;
  late PrivateVaultFileStorage fileStorage;
  late CryptoService cryptoService;
  late int nextId;

  setUp(() async {
    DebugErrorLog.instance.clear();
    directory = await Directory.systemTemp.createTemp('veyra-image-import-');
    imageLibrary = FakeImageLibraryRepository();
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
    DebugErrorLog.instance.clear();
    vaultSession.lock();
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });

  test('encrypts an image and stores its metadata', () async {
    final Uint8List imageBytes = _jpegBytes(512);
    final File source = File('${directory.path}/source.jpg');
    await source.writeAsBytes(imageBytes);
    imageLibrary.files['image-1'] = source;
    final Uint8List thumbnailBytes = Uint8List.fromList(<int>[
      0xff,
      0xd8,
      0xff,
      0xd9,
    ]);
    imageLibrary.thumbnails['image-1'] = thumbnailBytes.asUnmodifiableView();
    final ImageImportService service = _service(
      imageLibrary: imageLibrary,
      vaultRepository: vaultRepository,
      fileStorage: fileStorage,
      vaultSession: vaultSession,
      cryptoService: cryptoService,
      idGenerator: () => 'image-id-${nextId++}',
    );

    final List<(int, int)> progress = <(int, int)>[];
    final ImageImportResult result = await service.importImages(<GalleryImage>[
      _galleryImage('image-1', 'vacaciones.jpg'),
    ], onProgress: (completed, total) => progress.add((completed, total)));

    expect(result.failed, isEmpty);
    expect(result.imported, hasLength(1));
    expect(progress, <(int, int)>[(1, 1)]);
    expect(imageLibrary.cacheCleared, isTrue);
    final VaultItem item = vaultRepository.items.single;
    expect(item.id, 'image-id-0');
    expect(item.originalName, 'vacaciones.jpg');
    expect(item.encryptedFileName, 'image-id-0.dat');
    expect(item.mimeType, 'image/jpeg');
    expect(item.size, imageBytes.length);
    expect(
      item.thumbnailPath,
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\.thumb$',
        ),
      ),
    );
    expect(item.thumbnailPath, isNot('image-id-0.thumb'));
    expect(thumbnailBytes, <int>[0xff, 0xd8, 0xff, 0xd9]);

    final File encryptedFile = File(
      '${directory.path}/vault/images/image-id-0.dat',
    );
    expect(await encryptedFile.exists(), isTrue);
    expect(await encryptedFile.readAsBytes(), isNot(orderedEquals(imageBytes)));
    final File encryptedThumbnail = File(
      '${directory.path}/vault/images/${item.thumbnailPath}',
    );
    expect(await encryptedThumbnail.exists(), isTrue);
    expect(await encryptedThumbnail.readAsBytes(), isNot(contains(0xd8)));

    final File decryptedFile = File('${directory.path}/decrypted.jpg');
    await vaultSession.withMasterKey((secretKey) {
      return cryptoService.decryptFile(
        inputFile: encryptedFile,
        outputFile: decryptedFile,
        secretKey: secretKey,
      );
    });
    expect(await decryptedFile.readAsBytes(), orderedEquals(imageBytes));
  });

  test('keeps successful imports when other selected images fail', () async {
    final File valid = File('${directory.path}/valid.jpg');
    final File invalid = File('${directory.path}/invalid.txt');
    final File tooLarge = File('${directory.path}/large.jpg');
    await valid.writeAsBytes(_jpegBytes(80));
    await invalid.writeAsString('not an image');
    await tooLarge.writeAsBytes(_jpegBytes(101));
    imageLibrary.files
      ..['valid'] = valid
      ..['invalid'] = invalid
      ..['large'] = tooLarge;
    final ImageImportService service = _service(
      imageLibrary: imageLibrary,
      vaultRepository: vaultRepository,
      fileStorage: fileStorage,
      vaultSession: vaultSession,
      cryptoService: cryptoService,
      idGenerator: () => 'batch-${nextId++}',
      maximumImageBytes: 100,
    );

    final ImageImportResult result = await service.importImages(<GalleryImage>[
      _galleryImage('valid', 'valid.jpg'),
      _galleryImage('missing', 'missing.jpg'),
      _galleryImage('invalid', 'invalid.txt'),
      _galleryImage('large', 'large.jpg'),
    ]);

    expect(result.imported, hasLength(1));
    expect(result.failed, hasLength(3));
    expect(
      result.failed.map((failure) => failure.error),
      containsAll(<Matcher>[
        isA<VaultSourceFileNotFoundException>(),
        isA<InvalidImageTypeException>(),
        isA<ImageTooLargeException>(),
      ]),
    );
    expect(vaultRepository.items, hasLength(1));
    expect(DebugErrorLog.instance.entries, hasLength(3));
    expect(
      DebugErrorLog.instance.entries.map((entry) => entry.code).toSet(),
      <String>{'vault_file_not_found', 'invalid_image_type', 'image_too_large'},
    );
    expect(
      DebugErrorLog.instance.entries,
      everyElement(
        isA<DebugErrorEntry>().having(
          (entry) => entry.operation,
          'operation',
          'image_import',
        ),
      ),
    );
  });

  test('imports multiple selected images in one batch', () async {
    final File first = File('${directory.path}/first.jpg');
    final File second = File('${directory.path}/second.jpg');
    await first.writeAsBytes(_jpegBytes(80));
    await second.writeAsBytes(_jpegBytes(96));
    imageLibrary.files
      ..['first'] = first
      ..['second'] = second;
    final ImageImportService service = _service(
      imageLibrary: imageLibrary,
      vaultRepository: vaultRepository,
      fileStorage: fileStorage,
      vaultSession: vaultSession,
      cryptoService: cryptoService,
      idGenerator: () => 'multiple-${nextId++}',
    );

    final ImageImportResult result = await service.importImages(<GalleryImage>[
      _galleryImage('first', 'first.jpg'),
      _galleryImage('second', 'second.jpg'),
    ]);

    expect(result.failed, isEmpty);
    expect(result.imported, hasLength(2));
    expect(vaultRepository.items, hasLength(2));
    expect(
      await File('${directory.path}/vault/images/multiple-0.dat').exists(),
      isTrue,
    );
    expect(
      await File('${directory.path}/vault/images/multiple-1.dat').exists(),
      isTrue,
    );
  });

  test('imports JPEG, PNG, and WEBP images', () async {
    final Map<String, List<int>> headers = <String, List<int>>{
      'jpeg': <int>[0xff, 0xd8, 0xff, 0xe0],
      'png': <int>[0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a],
      'webp': <int>[
        0x52,
        0x49,
        0x46,
        0x46,
        0x18,
        0x00,
        0x00,
        0x00,
        0x57,
        0x45,
        0x42,
        0x50,
      ],
    };
    for (final MapEntry<String, List<int>> entry in headers.entries) {
      final String extension = entry.key == 'jpeg' ? 'jpg' : entry.key;
      final File file = File('${directory.path}/format.$extension');
      await file.writeAsBytes(<int>[
        ...entry.value,
        ...List<int>.filled(64, 0),
      ]);
      imageLibrary.files[entry.key] = file;
    }
    final ImageImportService service = _service(
      imageLibrary: imageLibrary,
      vaultRepository: vaultRepository,
      fileStorage: fileStorage,
      vaultSession: vaultSession,
      cryptoService: CryptoService(fileChunkSize: 1024),
      idGenerator: () => 'format-${nextId++}',
    );

    final ImageImportResult result = await service.importImages(
      headers.keys
          .map(
            (format) => _galleryImage(
              format,
              'image.${format == 'jpeg' ? 'jpg' : format}',
            ),
          )
          .toList(),
    );

    expect(result.failed, isEmpty);
    expect(
      result.imported.map((entry) => entry.item.mimeType).toSet(),
      <String>{'image/jpeg', 'image/png', 'image/webp'},
    );
  });

  test('imports images of 1 MB and 10 MB', () async {
    const List<int> sizes = <int>[1 * 1024 * 1024, 10 * 1024 * 1024];
    for (int index = 0; index < sizes.length; index++) {
      imageLibrary.files['size-$index'] = await _createSparseFile(
        '${directory.path}/size-$index.jpg',
        sizes[index],
        <int>[0xff, 0xd8, 0xff, 0xe0],
      );
    }
    final ImageImportService service = _service(
      imageLibrary: imageLibrary,
      vaultRepository: vaultRepository,
      fileStorage: fileStorage,
      vaultSession: vaultSession,
      cryptoService: CryptoService(fileChunkSize: 4 * 1024 * 1024),
      idGenerator: () => 'sized-image-${nextId++}',
    );

    final ImageImportResult result = await service.importImages(<GalleryImage>[
      _galleryImage('size-0', 'one-megabyte.jpg'),
      _galleryImage('size-1', 'ten-megabytes.jpg'),
    ]);

    expect(result.failed, isEmpty);
    expect(
      result.imported.map((entry) => entry.item.size),
      orderedEquals(sizes),
    );
  });

  test(
    'brief background interruption does not corrupt an active import',
    () async {
      final File source = File('${directory.path}/background.jpg');
      await source.writeAsBytes(_jpegBytes(128));
      final Completer<File?> pendingSource = Completer<File?>();
      imageLibrary.loadOriginalOverride = (id) => pendingSource.future;
      final ImageImportService service = _service(
        imageLibrary: imageLibrary,
        vaultRepository: vaultRepository,
        fileStorage: fileStorage,
        vaultSession: vaultSession,
        cryptoService: cryptoService,
        idGenerator: () => 'background-import',
      );

      final Future<ImageImportResult> import = service.importImages(
        <GalleryImage>[_galleryImage('background', 'background.jpg')],
      );
      await Future<void>.delayed(Duration.zero);
      pendingSource.complete(source);
      final ImageImportResult result = await import;

      expect(result.failed, isEmpty);
      expect(vaultRepository.items.single.id, 'background-import');
    },
  );

  test(
    'screen lock during import fails closed and leaves no metadata',
    () async {
      final File source = File('${directory.path}/locked.jpg');
      await source.writeAsBytes(_jpegBytes(128));
      final Completer<File?> pendingSource = Completer<File?>();
      imageLibrary.loadOriginalOverride = (id) => pendingSource.future;
      final ImageImportService service = _service(
        imageLibrary: imageLibrary,
        vaultRepository: vaultRepository,
        fileStorage: fileStorage,
        vaultSession: vaultSession,
        cryptoService: cryptoService,
        idGenerator: () => 'locked-import',
      );

      final Future<ImageImportResult> import = service.importImages(
        <GalleryImage>[_galleryImage('locked', 'locked.jpg')],
      );
      await Future<void>.delayed(Duration.zero);
      vaultSession.lock();
      pendingSource.complete(source);
      final ImageImportResult result = await import;

      expect(result.imported, isEmpty);
      expect(result.failed.single.error, isA<ImageImportException>());
      expect(vaultRepository.items, isEmpty);
      expect(
        await File('${directory.path}/vault/images/locked-import.dat').exists(),
        isFalse,
      );
    },
  );

  test('removes the encrypted file when metadata insertion fails', () async {
    final File source = File('${directory.path}/source.jpg');
    await source.writeAsBytes(_jpegBytes(128));
    imageLibrary.files['image'] = source;
    vaultRepository.failInserts = true;
    final ImageImportService service = _service(
      imageLibrary: imageLibrary,
      vaultRepository: vaultRepository,
      fileStorage: fileStorage,
      vaultSession: vaultSession,
      cryptoService: cryptoService,
      idGenerator: () => 'rollback-id',
    );

    final ImageImportResult result = await service.importImages(<GalleryImage>[
      _galleryImage('image', 'image.jpg'),
    ]);

    expect(result.imported, isEmpty);
    expect(result.failed.single.error, isA<ImageImportException>());
    expect(
      await File('${directory.path}/vault/images/rollback-id.dat').exists(),
      isFalse,
    );
  });

  test('deletes originals only after an explicit request', () async {
    final ImageImportService service = _service(
      imageLibrary: imageLibrary,
      vaultRepository: vaultRepository,
      fileStorage: fileStorage,
      vaultSession: vaultSession,
      cryptoService: cryptoService,
      idGenerator: () => 'unused',
    );

    expect(imageLibrary.deletedIds, isEmpty);
    final Set<String> deleted = await service.deleteOriginals(<String>[
      'first',
      'second',
    ]);

    expect(deleted, <String>{'first', 'second'});
    expect(imageLibrary.deletedIds, <String>{'first', 'second'});
  });
}

ImageImportService _service({
  required FakeImageLibraryRepository imageLibrary,
  required FakeVaultRepository vaultRepository,
  required PrivateVaultFileStorage fileStorage,
  required VaultSession vaultSession,
  required CryptoService cryptoService,
  required ImageIdGenerator idGenerator,
  int maximumImageBytes = 50 * 1024 * 1024,
}) {
  return ImageImportService(
    imageLibrary: imageLibrary,
    vaultRepository: vaultRepository,
    fileStorage: fileStorage,
    vaultSession: vaultSession,
    cryptoService: cryptoService,
    idGenerator: idGenerator,
    utcNow: () => DateTime.utc(2026, 9, 26),
    maximumImageBytes: maximumImageBytes,
  );
}

GalleryImage _galleryImage(String id, String name) {
  return GalleryImage(
    id: id,
    name: name,
    createdAt: DateTime.utc(2025, 6, 1),
    mimeType: 'image/jpeg',
  );
}

Uint8List _jpegBytes(int length) {
  final Uint8List bytes = Uint8List(length);
  bytes.setRange(0, 4, <int>[0xff, 0xd8, 0xff, 0xe0]);
  for (int index = 4; index < length; index++) {
    bytes[index] = index % 251;
  }
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

final class FakeImageLibraryRepository implements ImageLibraryRepository {
  final Map<String, File> files = <String, File>{};
  final Map<String, Uint8List> thumbnails = <String, Uint8List>{};
  final Set<String> deletedIds = <String>{};
  bool cacheCleared = false;
  Future<File?> Function(String id)? loadOriginalOverride;

  @override
  Future<void> clearCache() async {
    cacheCleared = true;
  }

  @override
  Future<Set<String>> deleteOriginals(Iterable<String> ids) async {
    deletedIds.addAll(ids);
    return ids.toSet();
  }

  @override
  Future<File?> loadOriginal(String id) async {
    final Future<File?> Function(String id)? override = loadOriginalOverride;
    return override == null ? files[id] : override(id);
  }

  @override
  Future<List<GalleryImage>> loadRecent({
    required int page,
    required int pageSize,
  }) async {
    return <GalleryImage>[];
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
  Future<bool> deleteById(String id) async {
    final int before = items.length;
    items.removeWhere((item) => item.id == id);
    return before != items.length;
  }

  @override
  Future<VaultItem?> getById(String id) async {
    for (final VaultItem item in items) {
      if (item.id == id) {
        return item;
      }
    }
    return null;
  }

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
