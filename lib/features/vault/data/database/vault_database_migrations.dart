import 'package:sqflite/sqflite.dart';
import 'package:veyra/features/vault/data/database/vault_database_schema.dart';

abstract final class VaultDatabaseMigrations {
  static Future<void> createVersion1(Database database) async {
    final Batch batch = database.batch();
    batch.execute('''
      CREATE TABLE ${VaultDatabaseSchema.itemsTable} (
        id TEXT NOT NULL PRIMARY KEY,
        original_name TEXT NOT NULL,
        encrypted_file_name TEXT NOT NULL UNIQUE,
        type TEXT NOT NULL CHECK (type IN ('image', 'video', 'file')),
        mime_type TEXT NOT NULL,
        size INTEGER NOT NULL CHECK (size >= 0),
        created_at INTEGER NOT NULL,
        imported_at INTEGER NOT NULL,
        thumbnail_path TEXT
      )
    ''');
    batch.execute('''
      CREATE INDEX ${VaultDatabaseSchema.typeImportedAtIndex}
      ON ${VaultDatabaseSchema.itemsTable} (type, imported_at DESC)
    ''');
    await batch.commit(noResult: true);
  }

  static Future<void> migrateVersion1To2(Database database) async {
    await database.execute(
      'ALTER TABLE ${VaultDatabaseSchema.itemsTable} '
      'ADD COLUMN duration_ms INTEGER '
      'CHECK (duration_ms IS NULL OR duration_ms >= 0)',
    );
  }
}
