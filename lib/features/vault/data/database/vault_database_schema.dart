abstract final class VaultDatabaseSchema {
  static const int version = 2;
  static const String databaseName = 'veyra_vault.db';
  static const String itemsTable = 'vault_items';
  static const String typeImportedAtIndex = 'idx_vault_items_type_imported_at';
}
