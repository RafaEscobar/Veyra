import 'package:equatable/equatable.dart';
import 'package:veyra/features/vault/domain/entities/vault_item.dart';

final class VaultFolder extends Equatable {
  const VaultFolder({
    required this.id,
    required this.name,
    required this.type,
    required this.createdAt,
    this.itemCount = 0,
  });

  final String id;
  final String name;
  final VaultItemType type;
  final DateTime createdAt;
  final int itemCount;

  @override
  List<Object> get props => <Object>[id, name, type, createdAt, itemCount];
}
