import 'package:equatable/equatable.dart';

final class GalleryVideo extends Equatable {
  const GalleryVideo({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.duration,
    this.mimeType,
  });

  final String id;
  final String name;
  final DateTime createdAt;
  final Duration duration;
  final String? mimeType;

  @override
  List<Object?> get props => <Object?>[id, name, createdAt, duration, mimeType];
}
