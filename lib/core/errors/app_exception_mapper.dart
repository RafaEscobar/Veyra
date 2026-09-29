import 'dart:io';

import 'package:flutter/services.dart';
import 'package:veyra/core/errors/app_exception.dart';

typedef AppExceptionFallback = AppException Function(Object error);

abstract final class AppExceptionMapper {
  static AppException map(
    Object error, {
    required AppExceptionFallback fallback,
  }) {
    if (error is AppException) {
      return error;
    }
    if (error is FileSystemException && _isStorageFull(error)) {
      return StorageFullException(cause: error);
    }
    if (error is PlatformException && _isPermissionDenied(error.code)) {
      return PermissionDeniedException(cause: error);
    }
    return fallback(error);
  }

  static bool _isStorageFull(FileSystemException error) {
    final int? code = error.osError?.errorCode;
    return code == 28 || code == 112;
  }

  static bool _isPermissionDenied(String code) {
    final String normalized = code.toLowerCase();
    return normalized.contains('permission') ||
        normalized.contains('denied') ||
        normalized.contains('unauthorized');
  }
}
