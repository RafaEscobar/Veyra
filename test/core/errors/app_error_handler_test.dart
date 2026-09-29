import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:veyra/core/errors/app_error_handler.dart';
import 'package:veyra/core/errors/app_exception.dart';

void main() {
  test('error reporting omits messages and stack traces with secrets', () {
    final DebugPrintCallback originalDebugPrint = debugPrint;
    final List<String> messages = <String>[];
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) {
        messages.add(message);
      }
    };
    addTearDown(() => debugPrint = originalDebugPrint);

    AppErrorHandler.report(
      StateError(
        'NIP 4826, respuesta privada, '
        'MasterKey=QkJCQkJCQkJCQkJCQkJCQkJCQkJCQkJCQkJCQkJCQkI=',
      ),
      StackTrace.fromString('ruta/sensible/4826'),
    );

    final String output = messages.join('\n');
    expect(output, contains('unexpected_error'));
    expect(output, isNot(contains('4826')));
    expect(output, isNot(contains('respuesta privada')));
    expect(output, isNot(contains('QkJCQkJC')));
    expect(output, isNot(contains('ruta/sensible')));
  });

  test('logs only the safe code of a typed application error', () {
    final DebugPrintCallback originalDebugPrint = debugPrint;
    final List<String> messages = <String>[];
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) {
        messages.add(message);
      }
    };
    addTearDown(() => debugPrint = originalDebugPrint);

    AppErrorHandler.report(
      EncryptionException(cause: StateError('MasterKey=secret')),
      StackTrace.fromString('/private/path'),
    );

    final String output = messages.join('\n');
    expect(output, contains('encryption_failed'));
    expect(output, isNot(contains('MasterKey')));
    expect(output, isNot(contains('/private/path')));
  });
}
