import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:veyra/core/errors/app_error_message.dart';
import 'package:veyra/core/errors/app_exception.dart';
import 'package:veyra/core/errors/app_exception_mapper.dart';

void main() {
  test('defines the required typed error hierarchy', () {
    expect(
      const WrongPinException(failedAttempts: 1),
      isA<AuthenticationException>(),
    );
    expect(
      const WrongRecoveryAnswerException(failedAttempts: 1),
      isA<AuthenticationException>(),
    );
    expect(const VaultFileNotFoundException(), isA<VaultFileException>());
    expect(const VaultFileCorruptedException(), isA<VaultFileException>());
    expect(const StorageFullException(), isA<VaultException>());
    expect(const PermissionDeniedException(), isA<AppException>());
    expect(const EncryptionException(), isA<VaultFileException>());
    expect(const DecryptionException(), isA<VaultFileException>());
    expect(const ExportException(), isA<VaultException>());
  });

  test('maps storage and permission failures without exposing details', () {
    final AppException storage = AppExceptionMapper.map(
      const FileSystemException(
        'private file name',
        '/private/path',
        OSError('secret', 28),
      ),
      fallback: (error) => UnexpectedAppException(cause: error),
    );
    final AppException permission = AppExceptionMapper.map(
      PlatformException(code: 'permission_denied', message: 'private'),
      fallback: (error) => UnexpectedAppException(cause: error),
    );

    expect(storage, isA<StorageFullException>());
    expect(permission, isA<PermissionDeniedException>());
    expect(storage.toString(), 'AppException(code: storage_full)');
    expect(storage.toString(), isNot(contains('/private/path')));
  });

  test('returns friendly messages without cryptographic details', () {
    final String message = AppErrorMessage.forError(
      EncryptionException(cause: StateError('MasterKey=secret')),
    );

    expect(message, 'No se pudo proteger el archivo. Inténtalo de nuevo.');
    expect(message, isNot(contains('MasterKey')));
    expect(message, isNot(contains('secret')));
  });
}
