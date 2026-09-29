import 'package:veyra/features/vault/data/database/vault_items_dao.dart';
import 'package:veyra/features/vault/domain/entities/vault_item.dart';
import 'package:veyra/features/vault/domain/repositories/vault_repository.dart';

final class LocalVaultRepository
    implements VaultRepository, PaginatedVaultRepository {
  const LocalVaultRepository(this._dao);

  final VaultItemsDao _dao;

  @override
  Future<int> countByType(VaultItemType type) => _dao.countByType(type);

  @override
  Future<bool> deleteById(String id) => _dao.deleteById(id);

  @override
  Future<VaultItem?> getById(String id) => _dao.getById(id);

  @override
  Future<List<VaultItem>> getItemsByType(VaultItemType type) {
    return _dao.getItemsByType(type);
  }

  @override
  Future<List<VaultItem>> getItemsPageByType(
    VaultItemType type, {
    required int limit,
    required int offset,
  }) {
    return _dao.getItemsPageByType(type, limit: limit, offset: offset);
  }

  @override
  Future<void> insert(VaultItem item) => _dao.insert(item);

  @override
  Future<bool> update(VaultItem item) => _dao.update(item);
}
