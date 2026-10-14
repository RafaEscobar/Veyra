import 'package:equatable/equatable.dart';

enum VaultItemType {
  image('image'),
  video('video'),
  file('file');

  const VaultItemType(this.storageValue);

  final String storageValue;

  static VaultItemType fromStorageValue(String value) {
    return VaultItemType.values.firstWhere(
      (type) => type.storageValue == value,
      orElse: () =>
          throw FormatException('Unsupported vault item type: $value'),
    );
  }
}

final class VaultItem extends Equatable {
  const VaultItem({
    required this.id,
    required this.originalName,
    required this.encryptedFileName,
    required this.type,
    required this.mimeType,
    required this.size,
    required this.createdAt,
    required this.importedAt,
    this.thumbnailPath,
    this.duration,
    this.folderId,
  }) : assert(size >= 0, 'size cannot be negative');

  final String id;
  final String originalName;
  final String encryptedFileName;
  final VaultItemType type;
  final String mimeType;
  final int size;
  final DateTime createdAt;
  final DateTime importedAt;
  final String? thumbnailPath;
  final Duration? duration;
  final String? folderId;

  @override
  List<Object?> get props => <Object?>[
    id,
    originalName,
    encryptedFileName,
    type,
    mimeType,
    size,
    createdAt,
    importedAt,
    thumbnailPath,
    duration,
    folderId,
  ];
}
