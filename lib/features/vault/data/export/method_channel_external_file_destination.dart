import 'package:flutter/services.dart';
import 'package:veyra/features/vault/domain/services/external_file_destination.dart';

final class MethodChannelExternalFileDestination
    implements ExternalFileDestination {
  const MethodChannelExternalFileDestination();

  static const MethodChannel _channel = MethodChannel(
    'com.veyra.app/file_export',
  );

  @override
  Future<ExternalFileWriteResult?> saveFromPath({
    required String sourcePath,
    required String fileName,
    required String mimeType,
  }) async {
    final Map<Object?, Object?>? result = await _channel
        .invokeMapMethod<Object?, Object?>('saveFile', <String, Object>{
          'sourcePath': sourcePath,
          'fileName': fileName,
          'mimeType': mimeType,
        });
    if (result == null) {
      return null;
    }
    final Object? uri = result['uri'];
    final Object? bytesWritten = result['bytesWritten'];
    if (uri is! String || uri.isEmpty || bytesWritten is! int) {
      throw const FormatException('Invalid external file result.');
    }
    return ExternalFileWriteResult(
      uri: Uri.parse(uri),
      bytesWritten: bytesWritten,
    );
  }
}
