import 'package:veyra/features/vault/domain/entities/vault_item.dart';

abstract final class VaultItemMapper {
  static Map<String, Object?> toMap(VaultItem item) {
    return <String, Object?>{
      'id': item.id,
      'original_name': item.originalName,
      'encrypted_file_name': item.encryptedFileName,
      'type': item.type.storageValue,
      'mime_type': item.mimeType,
      'size': item.size,
      'created_at': item.createdAt.toUtc().millisecondsSinceEpoch,
      'imported_at': item.importedAt.toUtc().millisecondsSinceEpoch,
      'thumbnail_path': item.thumbnailPath,
      'duration_ms': item.duration?.inMilliseconds,
      'folder_id': item.folderId,
    };
  }

  static VaultItem fromMap(Map<String, Object?> map) {
    return VaultItem(
      id: map['id']! as String,
      originalName: map['original_name']! as String,
      encryptedFileName: map['encrypted_file_name']! as String,
      type: VaultItemType.fromStorageValue(map['type']! as String),
      mimeType: map['mime_type']! as String,
      size: map['size']! as int,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        map['created_at']! as int,
        isUtc: true,
      ),
      importedAt: DateTime.fromMillisecondsSinceEpoch(
        map['imported_at']! as int,
        isUtc: true,
      ),
      thumbnailPath: map['thumbnail_path'] as String?,
      duration: switch (map['duration_ms']) {
        final int milliseconds => Duration(milliseconds: milliseconds),
        _ => null,
      },
      folderId: map['folder_id'] as String?,
    );
  }
}
