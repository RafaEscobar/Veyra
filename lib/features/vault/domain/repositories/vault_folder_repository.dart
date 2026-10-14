import 'package:veyra/features/vault/domain/entities/vault_folder.dart';
import 'package:veyra/features/vault/domain/entities/vault_item.dart';

abstract interface class VaultFolderRepository {
  Future<void> insertFolder(VaultFolder folder);

  Future<List<VaultFolder>> getFoldersByType(VaultItemType type);

  Future<bool> deleteFolder(String id);

  Future<bool> moveItemToFolder(String itemId, String? folderId);

  Future<List<VaultItem>> getItemsPageByFolder(
    VaultItemType type, {
    required String? folderId,
    required int limit,
    required int offset,
  });
}
