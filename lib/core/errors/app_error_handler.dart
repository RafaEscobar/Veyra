import 'package:flutter/foundation.dart';
import 'package:veyra/core/errors/app_exception.dart';

abstract final class AppErrorHandler {
  static void initialize() {
    FlutterError.onError = _onFlutterError;
    PlatformDispatcher.instance.onError = _onPlatformError;
  }

  static void report(Object error, StackTrace stackTrace) {
    if (kDebugMode) {
      final String code = error is AppException
          ? error.code
          : 'unexpected_error';
      debugPrint('Veyra error: $code');
    }
  }

  static void _onFlutterError(FlutterErrorDetails details) {
    report(details.exception, details.stack ?? StackTrace.current);
  }

  static bool _onPlatformError(Object error, StackTrace stackTrace) {
    report(error, stackTrace);
    return true;
  }
}
