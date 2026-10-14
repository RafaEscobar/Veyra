import 'package:sqflite/sqflite.dart';
import 'package:veyra/features/vault/data/database/vault_database.dart';
import 'package:veyra/features/vault/data/database/vault_database_schema.dart';
import 'package:veyra/features/vault/data/models/vault_item_mapper.dart';
import 'package:veyra/features/vault/domain/entities/vault_folder.dart';
import 'package:veyra/features/vault/domain/entities/vault_item.dart';

final class VaultItemsDao {
  const VaultItemsDao(this._database);

  final VaultDatabase _database;

  Future<void> insert(VaultItem item) async {
    final Database database = await _database.instance;
    await database.insert(
      VaultDatabaseSchema.itemsTable,
      VaultItemMapper.toMap(item),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<VaultItem?> getById(String id) async {
    final Database database = await _database.instance;
    final List<Map<String, Object?>> rows = await database.query(
      VaultDatabaseSchema.itemsTable,
      where: 'id = ?',
      whereArgs: <Object>[id],
      limit: 1,
    );
    return rows.isEmpty ? null : VaultItemMapper.fromMap(rows.single);
  }

  Future<bool> update(VaultItem item) async {
    final Database database = await _database.instance;
    final int updatedRows = await database.update(
      VaultDatabaseSchema.itemsTable,
      VaultItemMapper.toMap(item),
      where: 'id = ?',
      whereArgs: <Object>[item.id],
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
    return updatedRows > 0;
  }

  Future<List<VaultItem>> getItemsByType(VaultItemType type) async {
    final Database database = await _database.instance;
    final List<Map<String, Object?>> rows = await database.query(
      VaultDatabaseSchema.itemsTable,
      where: 'type = ?',
      whereArgs: <Object>[type.storageValue],
      orderBy: 'imported_at DESC, id ASC',
    );
    return rows.map(VaultItemMapper.fromMap).toList(growable: false);
  }

  Future<List<VaultItem>> getItemsPageByType(
    VaultItemType type, {
    required int limit,
    required int offset,
  }) async {
    if (limit <= 0 || offset < 0) {
      throw ArgumentError('Invalid pagination values.');
    }
    final Database database = await _database.instance;
    final List<Map<String, Object?>> rows = await database.query(
      VaultDatabaseSchema.itemsTable,
      where: 'type = ?',
      whereArgs: <Object>[type.storageValue],
      orderBy: 'imported_at DESC, id ASC',
      limit: limit,
      offset: offset,
    );
    return rows.map(VaultItemMapper.fromMap).toList(growable: false);
  }

  Future<bool> deleteById(String id) async {
    final Database database = await _database.instance;
    final int deletedRows = await database.delete(
      VaultDatabaseSchema.itemsTable,
      where: 'id = ?',
      whereArgs: <Object>[id],
    );
    return deletedRows > 0;
  }

  Future<int> countByType(VaultItemType type) async {
    final Database database = await _database.instance;
    final List<Map<String, Object?>> rows = await database.rawQuery(
      '''
      SELECT COUNT(*) AS item_count
      FROM ${VaultDatabaseSchema.itemsTable}
      WHERE type = ?
      ''',
      <Object>[type.storageValue],
    );
    return rows.single['item_count']! as int;
  }

  Future<void> insertFolder(VaultFolder folder) async {
    final Database database = await _database.instance;
    await database.insert(VaultDatabaseSchema.foldersTable, <String, Object?>{
      'id': folder.id,
      'name': folder.name,
      'type': folder.type.storageValue,
      'created_at': folder.createdAt.toUtc().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.abort);
  }

  Future<List<VaultFolder>> getFoldersByType(VaultItemType type) async {
    final Database database = await _database.instance;
    final List<Map<String, Object?>> rows = await database.rawQuery(
      '''
      SELECT f.id, f.name, f.type, f.created_at,
             COUNT(i.id) AS item_count
      FROM ${VaultDatabaseSchema.foldersTable} AS f
      LEFT JOIN ${VaultDatabaseSchema.itemsTable} AS i
        ON i.folder_id = f.id
      WHERE f.type = ?
      GROUP BY f.id, f.name, f.type, f.created_at
      ORDER BY f.created_at ASC, f.name COLLATE NOCASE ASC
      ''',
      <Object>[type.storageValue],
    );
    return rows
        .map(
          (row) => VaultFolder(
            id: row['id']! as String,
            name: row['name']! as String,
            type: VaultItemType.fromStorageValue(row['type']! as String),
            createdAt: DateTime.fromMillisecondsSinceEpoch(
              row['created_at']! as int,
              isUtc: true,
            ),
            itemCount: row['item_count']! as int,
          ),
        )
        .toList(growable: false);
  }

  Future<bool> deleteFolder(String id) async {
    final Database database = await _database.instance;
    return await database.delete(
          VaultDatabaseSchema.foldersTable,
          where: 'id = ?',
          whereArgs: <Object>[id],
        ) >
        0;
  }

  Future<bool> moveItemToFolder(String itemId, String? folderId) async {
    final Database database = await _database.instance;
    return database.transaction<bool>((transaction) async {
      final List<Map<String, Object?>> itemRows = await transaction.query(
        VaultDatabaseSchema.itemsTable,
        columns: <String>['type'],
        where: 'id = ?',
        whereArgs: <Object>[itemId],
        limit: 1,
      );
      if (itemRows.isEmpty) {
        return false;
      }
      if (folderId != null) {
        final List<Map<String, Object?>> folderRows = await transaction.query(
          VaultDatabaseSchema.foldersTable,
          columns: <String>['type'],
          where: 'id = ?',
          whereArgs: <Object>[folderId],
          limit: 1,
        );
        if (folderRows.isEmpty ||
            folderRows.single['type'] != itemRows.single['type']) {
          throw ArgumentError('Folder and item types must match.');
        }
      }
      return await transaction.update(
            VaultDatabaseSchema.itemsTable,
            <String, Object?>{'folder_id': folderId},
            where: 'id = ?',
            whereArgs: <Object>[itemId],
          ) >
          0;
    });
  }

  Future<List<VaultItem>> getItemsPageByFolder(
    VaultItemType type, {
    required String? folderId,
    required int limit,
    required int offset,
  }) async {
    if (limit <= 0 || offset < 0) {
      throw ArgumentError('Invalid pagination values.');
    }
    final Database database = await _database.instance;
    final List<Map<String, Object?>> rows = await database.query(
      VaultDatabaseSchema.itemsTable,
      where: folderId == null
          ? 'type = ? AND folder_id IS NULL'
          : 'type = ? AND folder_id = ?',
      whereArgs: folderId == null
          ? <Object>[type.storageValue]
          : <Object>[type.storageValue, folderId],
      orderBy: 'imported_at DESC, id ASC',
      limit: limit,
      offset: offset,
    );
    return rows.map(VaultItemMapper.fromMap).toList(growable: false);
  }
}
