import 'package:equatable/equatable.dart';

final class ExternalFileWriteResult extends Equatable {
  const ExternalFileWriteResult({
    required this.uri,
    required this.bytesWritten,
  });

  final Uri uri;
  final int bytesWritten;

  @override
  List<Object> get props => <Object>[uri, bytesWritten];
}

abstract interface class ExternalFileDestination {
  Future<ExternalFileWriteResult?> saveFromPath({
    required String sourcePath,
    required String fileName,
    required String mimeType,
  });
}
