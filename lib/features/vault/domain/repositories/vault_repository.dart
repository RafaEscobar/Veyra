import 'package:veyra/features/vault/domain/entities/vault_item.dart';

abstract interface class VaultRepository {
  Future<void> insert(VaultItem item);

  Future<VaultItem?> getById(String id);

  Future<bool> update(VaultItem item);

  Future<List<VaultItem>> getItemsByType(VaultItemType type);

  Future<bool> deleteById(String id);

  Future<int> countByType(VaultItemType type);
}

abstract interface class PaginatedVaultRepository {
  Future<List<VaultItem>> getItemsPageByType(
    VaultItemType type, {
    required int limit,
    required int offset,
  });
}
