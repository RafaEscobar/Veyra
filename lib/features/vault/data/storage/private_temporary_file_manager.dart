import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:veyra/features/vault/domain/services/temporary_file_manager.dart';

typedef TemporaryDirectoryProvider = Future<Directory> Function();

final class PrivateTemporaryFileManager implements TemporaryFileManager {
  PrivateTemporaryFileManager({TemporaryDirectoryProvider? directoryProvider})
    : _directoryProvider = directoryProvider ?? getApplicationSupportDirectory;

  final TemporaryDirectoryProvider _directoryProvider;
  final Set<String> _registeredPaths = <String>{};

  @override
  Future<File> create(String fileName) async {
    if (path.basename(fileName) != fileName) {
      throw const FormatException('Invalid temporary file name.');
    }
    final Directory directory = await _temporaryDirectory();
    await directory.create(recursive: true);
    final File file = File(path.join(directory.path, fileName));
    _registeredPaths.add(path.absolute(file.path));
    return file;
  }

  @override
  bool isRegistered(File file) {
    return _registeredPaths.contains(path.absolute(file.path));
  }

  @override
  Future<void> release(File file) async {
    final String absolutePath = path.absolute(file.path);
    if (!_registeredPaths.contains(absolutePath)) {
      return;
    }
    if (await file.exists()) {
      await file.delete();
    }
    _registeredPaths.remove(absolutePath);
  }

  @override
  Future<void> clear() async {
    final Directory temporary = await _temporaryDirectory();
    if (!await temporary.exists()) {
      _registeredPaths.clear();
      return;
    }

    Object? firstError;
    StackTrace? firstStackTrace;
    await for (final FileSystemEntity entity in temporary.list(
      followLinks: false,
    )) {
      try {
        await entity.delete(recursive: entity is Directory);
      } on Object catch (error, stackTrace) {
        firstError ??= error;
        firstStackTrace ??= stackTrace;
      }
    }
    _registeredPaths.clear();
    if (firstError != null) {
      Error.throwWithStackTrace(firstError, firstStackTrace!);
    }
  }

  Future<Directory> _temporaryDirectory() async {
    final Directory root = await _directoryProvider();
    return Directory(path.join(root.path, 'vault', 'tmp'));
  }
}
