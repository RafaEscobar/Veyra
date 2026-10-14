abstract final class VaultDatabaseSchema {
  static const int version = 3;
  static const String databaseName = 'veyra_vault.db';
  static const String itemsTable = 'vault_items';
  static const String foldersTable = 'vault_folders';
  static const String typeImportedAtIndex = 'idx_vault_items_type_imported_at';
  static const String folderImportedAtIndex =
      'idx_vault_items_type_folder_imported_at';
  static const String folderTypeIndex = 'idx_vault_folders_type_created_at';
}
