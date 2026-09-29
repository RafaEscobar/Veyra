import 'package:equatable/equatable.dart';

final class GalleryImage extends Equatable {
  const GalleryImage({
    required this.id,
    required this.name,
    required this.createdAt,
    this.mimeType,
  });

  final String id;
  final String name;
  final DateTime createdAt;
  final String? mimeType;

  @override
  List<Object?> get props => <Object?>[id, name, createdAt, mimeType];
}
