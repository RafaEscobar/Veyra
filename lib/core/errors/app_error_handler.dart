import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:veyra/core/errors/app_exception.dart';
import 'package:veyra/core/errors/debug_error_log.dart';

abstract final class AppErrorHandler {
  static void initialize() {
    FlutterError.onError = _onFlutterError;
    PlatformDispatcher.instance.onError = _onPlatformError;
  }

  static void report(Object error, StackTrace stackTrace, {String? operation}) {
    if (kDebugMode) {
      final String code = error is AppException
          ? error.code
          : 'unexpected_error';
      final Object? cause = error is AppException ? error.cause : null;
      DebugErrorLog.instance.add(
        DebugErrorEntry(
          occurredAt: DateTime.now(),
          code: code,
          errorType: error.runtimeType.toString(),
          causeType: cause?.runtimeType.toString(),
          operation: operation,
          diagnosticCode: _diagnosticCode(error),
          stackFrames: _safeStackFrames(stackTrace),
        ),
      );
      debugPrint('Veyra error: $code');
    }
  }

  static String? _diagnosticCode(Object error) {
    if (error is AppException && error.cause != null) {
      return _diagnosticCode(error.cause!);
    }
    if (error is PlatformException) {
      return 'platform:${error.code}';
    }
    if (error is FileSystemException && error.osError != null) {
      return 'os:${error.osError!.errorCode}';
    }
    return null;
  }

  static List<String> _safeStackFrames(StackTrace stackTrace) {
    return stackTrace
        .toString()
        .split('\n')
        .where(
          (line) =>
              line.contains('package:veyra/') ||
              line.contains('dart:') ||
              line == '<asynchronous suspension>',
        )
        .take(12)
        .toList(growable: false);
  }

  static void _onFlutterError(FlutterErrorDetails details) {
    report(details.exception, details.stack ?? StackTrace.current);
  }

  static bool _onPlatformError(Object error, StackTrace stackTrace) {
    report(error, stackTrace);
    return true;
  }
}
