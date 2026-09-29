import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:veyra/features/vault/data/database/vault_database.dart';
import 'package:veyra/features/vault/data/database/vault_database_migrations.dart';
import 'package:veyra/features/vault/data/database/vault_database_schema.dart';
import 'package:veyra/features/vault/data/database/vault_items_dao.dart';
import 'package:veyra/features/vault/data/repositories/local_vault_repository.dart';
import 'package:veyra/features/vault/domain/entities/vault_item.dart';
import 'package:veyra/features/vault/domain/repositories/vault_repository.dart';

void main() {
  sqfliteFfiInit();

  late VaultDatabase database;
  late VaultRepository repository;

  setUp(() {
    database = VaultDatabase(
      databaseFactory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    repository = LocalVaultRepository(VaultItemsDao(database));
  });

  tearDown(() async {
    await database.close();
  });

  test('initial migration creates the table and required index', () async {
    final List<Database> concurrentInstances = await Future.wait<Database>(
      <Future<Database>>[
        database.instance,
        database.instance,
        database.instance,
      ],
    );
    final Database sqliteDatabase = concurrentInstances.first;

    expect(
      concurrentInstances.every(
        (candidate) => identical(candidate, sqliteDatabase),
      ),
      isTrue,
    );
    final List<Map<String, Object?>> versionRows = await sqliteDatabase
        .rawQuery('PRAGMA user_version');
    final List<Map<String, Object?>> schemaRows = await sqliteDatabase.rawQuery(
      '''
      SELECT name, type
      FROM sqlite_master
      WHERE name IN (?, ?)
      ORDER BY name
      ''',
      <Object>[
        VaultDatabaseSchema.itemsTable,
        VaultDatabaseSchema.typeImportedAtIndex,
      ],
    );

    expect(versionRows.single['user_version'], VaultDatabaseSchema.version);
    expect(schemaRows, <Map<String, Object?>>[
      <String, Object?>{
        'name': VaultDatabaseSchema.typeImportedAtIndex,
        'type': 'index',
      },
      <String, Object?>{
        'name': VaultDatabaseSchema.itemsTable,
        'type': 'table',
      },
    ]);
  });

  test('inserts, reads, filters, counts, and deletes metadata', () async {
    final VaultItem olderImage = _item(
      id: 'image-1',
      encryptedFileName: 'encrypted-image-1.dat',
      type: VaultItemType.image,
      importedAt: DateTime.utc(2026, 1, 2),
      thumbnailPath: 'thumbnails/image-1.webp',
    );
    final VaultItem newerImage = _item(
      id: 'image-2',
      encryptedFileName: 'encrypted-image-2.dat',
      type: VaultItemType.image,
      importedAt: DateTime.utc(2026, 2, 3),
    );
    final VaultItem video = _item(
      id: 'video-1',
      encryptedFileName: 'encrypted-video-1.dat',
      type: VaultItemType.video,
      importedAt: DateTime.utc(2026, 3, 4),
      duration: const Duration(minutes: 2, seconds: 3),
    );

    await repository.insert(olderImage);
    await repository.insert(newerImage);
    await repository.insert(video);

    expect(await repository.getById(olderImage.id), olderImage);
    expect(await repository.getById('missing'), isNull);
    expect(await repository.getItemsByType(VaultItemType.image), <VaultItem>[
      newerImage,
      olderImage,
    ]);
    expect(await repository.getItemsByType(VaultItemType.video), <VaultItem>[
      video,
    ]);
    expect(await repository.getItemsByType(VaultItemType.file), isEmpty);
    final PaginatedVaultRepository paginatedRepository =
        repository as PaginatedVaultRepository;
    expect(
      await paginatedRepository.getItemsPageByType(
        VaultItemType.image,
        limit: 1,
        offset: 1,
      ),
      <VaultItem>[olderImage],
    );
    expect(await repository.countByType(VaultItemType.image), 2);
    expect(await repository.countByType(VaultItemType.video), 1);
    expect(await repository.countByType(VaultItemType.file), 0);

    final VaultItem updatedImage = VaultItem(
      id: olderImage.id,
      originalName: 'renamed.jpg',
      encryptedFileName: olderImage.encryptedFileName,
      type: olderImage.type,
      mimeType: 'image/jpeg',
      size: 2048,
      createdAt: olderImage.createdAt,
      importedAt: olderImage.importedAt,
      thumbnailPath: 'thumbnails/updated-image-1.webp',
    );
    expect(await repository.update(updatedImage), isTrue);
    expect(
      await repository.update(
        _item(
          id: 'missing',
          encryptedFileName: 'missing.dat',
          type: VaultItemType.file,
        ),
      ),
      isFalse,
    );
    expect(await repository.getById(olderImage.id), updatedImage);

    expect(await repository.deleteById(olderImage.id), isTrue);
    expect(await repository.deleteById(olderImage.id), isFalse);
    expect(await repository.getById(olderImage.id), isNull);
    expect(await repository.countByType(VaultItemType.image), 1);
  });

  test('rejects duplicate physical encrypted file names', () async {
    final VaultItem first = _item(
      id: 'first',
      encryptedFileName: 'same.dat',
      type: VaultItemType.file,
    );
    final VaultItem duplicate = _item(
      id: 'second',
      encryptedFileName: 'same.dat',
      type: VaultItemType.file,
    );

    await repository.insert(first);

    await expectLater(
      repository.insert(duplicate),
      throwsA(isA<DatabaseException>()),
    );
    expect(await repository.countByType(VaultItemType.file), 1);
  });

  test('preserves metadata after closing and reopening the database', () async {
    final Directory directory = await Directory.systemTemp.createTemp(
      'veyra-database-restart-',
    );
    final String databasePath = '${directory.path}/vault.db';
    final VaultItem persistent = _item(
      id: 'persistent-file',
      encryptedFileName: 'persistent.dat',
      type: VaultItemType.file,
    );
    final VaultDatabase firstDatabase = VaultDatabase(
      databaseFactory: databaseFactoryFfi,
      databasePath: databasePath,
    );
    await LocalVaultRepository(VaultItemsDao(firstDatabase)).insert(persistent);
    await firstDatabase.close();

    final VaultDatabase reopenedDatabase = VaultDatabase(
      databaseFactory: databaseFactoryFfi,
      databasePath: databasePath,
    );
    final VaultItem? restored = await LocalVaultRepository(
      VaultItemsDao(reopenedDatabase),
    ).getById(persistent.id);

    expect(restored, persistent);
    await reopenedDatabase.close();
    await directory.delete(recursive: true);
  });

  test('migrates version 1 metadata and preserves existing items', () async {
    final Directory directory = await Directory.systemTemp.createTemp(
      'veyra-database-migration-',
    );
    final String databasePath = '${directory.path}/vault.db';
    final Database versionOne = await databaseFactoryFfi.openDatabase(
      databasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (database, version) =>
            VaultDatabaseMigrations.createVersion1(database),
      ),
    );
    await versionOne.insert(VaultDatabaseSchema.itemsTable, <String, Object?>{
      'id': 'legacy-video',
      'original_name': 'legacy.mp4',
      'encrypted_file_name': 'legacy.dat',
      'type': 'video',
      'mime_type': 'video/mp4',
      'size': 42,
      'created_at': 0,
      'imported_at': 0,
      'thumbnail_path': null,
    });
    await versionOne.close();

    final VaultDatabase migratedDatabase = VaultDatabase(
      databaseFactory: databaseFactoryFfi,
      databasePath: databasePath,
    );
    final LocalVaultRepository migratedRepository = LocalVaultRepository(
      VaultItemsDao(migratedDatabase),
    );
    final VaultItem? legacy = await migratedRepository.getById('legacy-video');
    final List<Map<String, Object?>> columns =
        await (await migratedDatabase.instance).rawQuery(
          'PRAGMA table_info(${VaultDatabaseSchema.itemsTable})',
        );

    expect(columns.map((column) => column['name']), contains('duration_ms'));
    expect(legacy?.originalName, 'legacy.mp4');
    expect(legacy?.duration, isNull);

    await migratedDatabase.close();
    await directory.delete(recursive: true);
  });
}

VaultItem _item({
  required String id,
  required String encryptedFileName,
  required VaultItemType type,
  DateTime? importedAt,
  String? thumbnailPath,
  Duration? duration,
}) {
  return VaultItem(
    id: id,
    originalName: '$id.bin',
    encryptedFileName: encryptedFileName,
    type: type,
    mimeType: 'application/octet-stream',
    size: 1024,
    createdAt: DateTime.utc(2026, 1),
    importedAt: importedAt ?? DateTime.utc(2026, 1, 1),
    thumbnailPath: thumbnailPath,
    duration: duration,
  );
}
