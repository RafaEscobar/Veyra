import 'package:equatable/equatable.dart';

final class PickedDocument extends Equatable {
  const PickedDocument({
    required this.name,
    required this.path,
    required this.extension,
  });

  final String name;
  final String? path;
  final String? extension;

  @override
  List<Object?> get props => <Object?>[name, path, extension];
}
