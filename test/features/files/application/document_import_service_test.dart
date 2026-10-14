import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:veyra/core/crypto/crypto_service.dart';
import 'package:veyra/core/errors/app_exception.dart';
import 'package:veyra/core/security/vault_session.dart';
import 'package:veyra/features/files/application/document_import_service.dart';
import 'package:veyra/features/files/domain/entities/document_import_result.dart';
import 'package:veyra/features/files/domain/entities/picked_document.dart';
import 'package:veyra/features/files/domain/repositories/document_picker_repository.dart';
import 'package:veyra/features/vault/data/storage/private_vault_file_storage.dart';
import 'package:veyra/features/vault/domain/entities/vault_item.dart';
import 'package:veyra/features/vault/domain/repositories/vault_repository.dart';
import 'package:veyra/features/vault/domain/services/vault_file_storage.dart';

void main() {
  late Directory directory;
  late FakeDocumentPickerRepository picker;
  late FakeVaultRepository vaultRepository;
  late VaultSession vaultSession;
  late PrivateVaultFileStorage fileStorage;
  late CryptoService cryptoService;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('veyra-file-import-');
    picker = FakeDocumentPickerRepository();
    vaultRepository = FakeVaultRepository();
    vaultSession = VaultSession()
      ..open(Uint8List.fromList(List<int>.generate(32, (index) => index)));
    fileStorage = PrivateVaultFileStorage(
      directoryProvider: () async => directory,
    );
    cryptoService = CryptoService(fileChunkSize: 32);
  });

  tearDown(() async {
    vaultSession.lock();
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });

  test(
    'selects, encrypts, indexes metadata, and clears temporary files',
    () async {
      final Uint8List original = Uint8List.fromList(<int>[
        0x25,
        0x50,
        0x44,
        0x46,
        ...List<int>.generate(200, (index) => index % 251),
      ]);
      final File source = File('${directory.path}/report.pdf');
      await source.writeAsBytes(original);
      picker.documents = <PickedDocument>[
        PickedDocument(name: 'report.pdf', path: source.path, extension: 'PDF'),
      ];
      final DocumentImportService service = _service(
        picker: picker,
        vaultRepository: vaultRepository,
        fileStorage: fileStorage,
        vaultSession: vaultSession,
        cryptoService: cryptoService,
        idGenerator: () => 'document-id',
      );
      final List<(int, int)> progress = <(int, int)>[];

      final DocumentImportResult? result = await service.selectAndImport(
        onProgress: (completed, total) => progress.add((completed, total)),
      );

      expect(result, isNotNull);
      expect(result!.failed, isEmpty);
      expect(result.imported, hasLength(1));
      expect(progress, <(int, int)>[(1, 1)]);
      expect(picker.temporaryFilesCleared, isTrue);
      final VaultItem item = vaultRepository.items.single;
      expect(item.originalName, 'report.pdf');
      expect(item.type, VaultItemType.file);
      expect(item.mimeType, 'application/pdf');
      expect(item.size, original.length);
      expect(item.createdAt.isUtc, isTrue);

      final File encrypted = File(
        '${directory.path}/vault/files/document-id.dat',
      );
      final File decrypted = File('${directory.path}/decrypted.pdf');
      expect(await encrypted.readAsBytes(), isNot(orderedEquals(original)));
      await vaultSession.withMasterKey((secretKey) {
        return cryptoService.decryptFile(
          inputFile: encrypted,
          outputFile: decrypted,
          secretKey: secretKey,
        );
      });
      expect(await decrypted.readAsBytes(), orderedEquals(original));
    },
  );

  test(
    'keeps valid files and reports unknown, missing, and oversized files',
    () async {
      final File valid = File('${directory.path}/notes.txt');
      final File large = File('${directory.path}/archive.zip');
      await valid.writeAsString('private notes');
      await large.writeAsBytes(List<int>.filled(101, 1));
      final DocumentImportService service = _service(
        picker: picker,
        vaultRepository: vaultRepository,
        fileStorage: fileStorage,
        vaultSession: vaultSession,
        cryptoService: cryptoService,
        idGenerator: () => 'batch-id',
        maximumDocumentBytes: 100,
      );

      final DocumentImportResult
      result = await service.importDocuments(<PickedDocument>[
        PickedDocument(name: 'notes.txt', path: valid.path, extension: 'txt'),
        PickedDocument(name: 'program.exe', path: valid.path, extension: 'exe'),
        const PickedDocument(
          name: 'missing.pdf',
          path: '/missing/file.pdf',
          extension: 'pdf',
        ),
        PickedDocument(name: 'archive.zip', path: large.path, extension: 'zip'),
      ]);

      expect(result.imported, hasLength(1));
      expect(result.failed, hasLength(3));
      expect(result.failed[0].error, isA<UnsupportedDocumentTypeException>());
      expect(result.failed[1].error, isA<VaultSourceFileNotFoundException>());
      expect(result.failed[2].error, isA<DocumentTooLargeException>());
    },
  );

  test('removes encrypted output when indexing fails', () async {
    final File source = File('${directory.path}/document.doc');
    await source.writeAsBytes(List<int>.generate(128, (index) => index));
    vaultRepository.failInserts = true;
    final DocumentImportService service = _service(
      picker: picker,
      vaultRepository: vaultRepository,
      fileStorage: fileStorage,
      vaultSession: vaultSession,
      cryptoService: cryptoService,
      idGenerator: () => 'rollback-document',
    );

    final DocumentImportResult result = await service.importDocuments(
      <PickedDocument>[
        PickedDocument(
          name: 'document.doc',
          path: source.path,
          extension: 'doc',
        ),
      ],
    );

    expect(result.imported, isEmpty);
    expect(result.failed.single.error, isA<DocumentImportException>());
    expect(
      await File(
        '${directory.path}/vault/files/rollback-document.dat',
      ).exists(),
      isFalse,
    );
  });

  test('accepts additional extension and MIME configuration', () async {
    final File source = File('${directory.path}/data.csv');
    await source.writeAsString('name,value\nA,1');
    final DocumentImportService service = _service(
      picker: picker,
      vaultRepository: vaultRepository,
      fileStorage: fileStorage,
      vaultSession: vaultSession,
      cryptoService: cryptoService,
      idGenerator: () => 'custom-document',
      supportedMimeTypes: const <String, String>{'csv': 'text/csv'},
    );

    final DocumentImportResult result = await service.importDocuments(
      <PickedDocument>[
        PickedDocument(name: 'data.csv', path: source.path, extension: 'csv'),
      ],
    );

    expect(result.failed, isEmpty);
    expect(result.imported.single.item.mimeType, 'text/csv');
  });

  test('imports PDF, TXT, DOCX, and ZIP documents', () async {
    const Map<String, String> expectedMimeTypes = <String, String>{
      'pdf': 'application/pdf',
      'txt': 'text/plain',
      'docx':
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'zip': 'application/zip',
    };
    final List<PickedDocument> documents = <PickedDocument>[];
    int id = 0;
    for (final String extension in expectedMimeTypes.keys) {
      final File source = File('${directory.path}/format.$extension');
      await source.writeAsBytes(<int>[1, 2, 3, 4]);
      documents.add(
        PickedDocument(
          name: 'format.$extension',
          path: source.path,
          extension: extension,
        ),
      );
    }
    final DocumentImportService service = _service(
      picker: picker,
      vaultRepository: vaultRepository,
      fileStorage: fileStorage,
      vaultSession: vaultSession,
      cryptoService: CryptoService(fileChunkSize: 1024),
      idGenerator: () => 'format-document-${id++}',
    );

    final DocumentImportResult result = await service.importDocuments(
      documents,
    );

    expect(result.failed, isEmpty);
    expect(
      result.imported.map((entry) => entry.item.mimeType).toSet(),
      expectedMimeTypes.values.toSet(),
    );
  });

  test('imports documents of 1 MB and 50 MB', () async {
    const List<int> sizes = <int>[1 * 1024 * 1024, 50 * 1024 * 1024];
    final List<PickedDocument> documents = <PickedDocument>[];
    for (int index = 0; index < sizes.length; index++) {
      final File source = await _createSparseFile(
        '${directory.path}/size-$index.pdf',
        sizes[index],
        <int>[0x25, 0x50, 0x44, 0x46],
      );
      documents.add(
        PickedDocument(
          name: 'size-$index.pdf',
          path: source.path,
          extension: 'pdf',
        ),
      );
    }
    int id = 0;
    final DocumentImportService service = _service(
      picker: picker,
      vaultRepository: vaultRepository,
      fileStorage: fileStorage,
      vaultSession: vaultSession,
      cryptoService: CryptoService(fileChunkSize: 4 * 1024 * 1024),
      idGenerator: () => 'sized-document-${id++}',
    );

    final DocumentImportResult result = await service.importDocuments(
      documents,
    );

    expect(result.failed, isEmpty);
    expect(
      result.imported.map((entry) => entry.item.size),
      orderedEquals(sizes),
    );
  });

  test('reports a full-storage failure without creating metadata', () async {
    final File source = File('${directory.path}/full-storage.pdf');
    await source.writeAsBytes(<int>[0x25, 0x50, 0x44, 0x46, 1, 2, 3]);
    final DocumentImportService service = _service(
      picker: picker,
      vaultRepository: vaultRepository,
      fileStorage: const FullStorageVaultFileStorage(),
      vaultSession: vaultSession,
      cryptoService: cryptoService,
      idGenerator: () => 'no-space',
    );

    final DocumentImportResult result = await service.importDocuments(
      <PickedDocument>[
        PickedDocument(
          name: 'full-storage.pdf',
          path: source.path,
          extension: 'pdf',
        ),
      ],
    );

    expect(result.imported, isEmpty);
    expect(result.failed.single.error, isA<StorageFullException>());
    expect(vaultRepository.items, isEmpty);
  });
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

DocumentImportService _service({
  required FakeDocumentPickerRepository picker,
  required FakeVaultRepository vaultRepository,
  required VaultFileStorage fileStorage,
  required VaultSession vaultSession,
  required CryptoService cryptoService,
  required DocumentIdGenerator idGenerator,
  int maximumDocumentBytes = 250 * 1024 * 1024,
  Map<String, String>? supportedMimeTypes,
}) {
  return DocumentImportService(
    documentPicker: picker,
    vaultRepository: vaultRepository,
    fileStorage: fileStorage,
    vaultSession: vaultSession,
    cryptoService: cryptoService,
    idGenerator: idGenerator,
    utcNow: () => DateTime.utc(2026, 9, 29),
    maximumDocumentBytes: maximumDocumentBytes,
    supportedMimeTypes: supportedMimeTypes,
  );
}

final class FullStorageVaultFileStorage implements VaultFileStorage {
  const FullStorageVaultFileStorage();

  @override
  Future<void> deleteIfExists(File file) async {}

  @override
  Future<File> encryptedFile({
    required VaultItemType type,
    required String fileName,
  }) {
    throw const FileSystemException(
      'No space left on device',
      null,
      OSError('No space left on device', 28),
    );
  }

  @override
  Future<File> temporaryFile(String fileName) =>
      encryptedFile(type: VaultItemType.file, fileName: fileName);
}

final class FakeDocumentPickerRepository implements DocumentPickerRepository {
  List<PickedDocument> documents = <PickedDocument>[];
  bool temporaryFilesCleared = false;

  @override
  Future<void> clearTemporaryFiles() async {
    temporaryFilesCleared = true;
  }

  @override
  Future<List<PickedDocument>> pickDocuments() async => documents;
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
    final int previousLength = items.length;
    items.removeWhere((item) => item.id == id);
    return items.length != previousLength;
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
      throw StateError('insert failed');
    }
    items.add(item);
  }

  @override
  Future<bool> update(VaultItem item) async {
    final int index = items.indexWhere((candidate) => candidate.id == item.id);
    if (index < 0) {
      return false;
    }
    items[index] = item;
    return true;
  }
}
