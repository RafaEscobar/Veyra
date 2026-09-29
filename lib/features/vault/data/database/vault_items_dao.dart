import 'package:sqflite/sqflite.dart';
import 'package:veyra/features/vault/data/database/vault_database.dart';
import 'package:veyra/features/vault/data/database/vault_database_schema.dart';
import 'package:veyra/features/vault/data/models/vault_item_mapper.dart';
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
}
