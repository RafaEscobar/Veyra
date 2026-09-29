import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:veyra/features/vault/data/database/vault_database_migrations.dart';
import 'package:veyra/features/vault/data/database/vault_database_schema.dart';

final class VaultDatabase {
  VaultDatabase({this.databaseFactory, this.databasePath});

  final sqflite.DatabaseFactory? databaseFactory;
  final String? databasePath;
  sqflite.Database? _database;
  Future<sqflite.Database>? _openingDatabase;

  Future<sqflite.Database> get instance async {
    final sqflite.Database? openDatabase = _database;
    if (openDatabase != null && openDatabase.isOpen) {
      return openDatabase;
    }

    final Future<sqflite.Database>? openingDatabase = _openingDatabase;
    if (openingDatabase != null) {
      return openingDatabase;
    }

    final Future<sqflite.Database> opening = _open();
    _openingDatabase = opening;
    try {
      return await opening;
    } finally {
      if (identical(_openingDatabase, opening)) {
        _openingDatabase = null;
      }
    }
  }

  Future<sqflite.Database> _open() async {
    final sqflite.DatabaseFactory resolvedFactory =
        databaseFactory ?? sqflite.databaseFactory;
    final String resolvedPath =
        databasePath ??
        path.join(
          await resolvedFactory.getDatabasesPath(),
          VaultDatabaseSchema.databaseName,
        );
    final sqflite.Database database = await resolvedFactory.openDatabase(
      resolvedPath,
      options: sqflite.OpenDatabaseOptions(
        version: VaultDatabaseSchema.version,
        onConfigure: (database) async {
          await database.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (database, version) async {
          await VaultDatabaseMigrations.createVersion1(database);
          if (version >= 2) {
            await VaultDatabaseMigrations.migrateVersion1To2(database);
          }
        },
        onUpgrade: (database, oldVersion, newVersion) async {
          if (oldVersion < 2 && newVersion >= 2) {
            await VaultDatabaseMigrations.migrateVersion1To2(database);
          }
        },
      ),
    );
    _database = database;
    return database;
  }

  Future<void> close() async {
    sqflite.Database? database = _database;
    final Future<sqflite.Database>? openingDatabase = _openingDatabase;
    if (database == null && openingDatabase != null) {
      try {
        database = await openingDatabase;
      } on Object {
        return;
      }
    }
    _database = null;
    if (database != null && database.isOpen) {
      await database.close();
    }
  }
}
