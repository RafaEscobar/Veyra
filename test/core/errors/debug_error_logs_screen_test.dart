import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:veyra/core/errors/app_error_handler.dart';
import 'package:veyra/core/errors/app_exception.dart';
import 'package:veyra/core/errors/debug_error_log.dart';
import 'package:veyra/core/errors/debug_error_logs_screen.dart';

void main() {
  final DebugErrorLog log = DebugErrorLog.instance;

  setUp(log.clear);
  tearDown(log.clear);

  testWidgets('shows safe error details and clears the debug log', (
    WidgetTester tester,
  ) async {
    AppErrorHandler.report(
      EncryptionException(
        cause: PlatformException(
          code: 'secure_failure',
          message: 'MasterKey=secret',
        ),
      ),
      StackTrace.fromString(
        '#0 VaultService.encrypt (package:veyra/core/vault_service.dart:10)\n'
        '#1 ruta/sensible/4826',
      ),
      operation: 'image_import',
    );

    await tester.pumpWidget(MaterialApp(home: DebugErrorLogsScreen(log: log)));

    expect(find.text('Logs de errores'), findsOneWidget);
    expect(find.text('encryption_failed'), findsOneWidget);
    expect(find.textContaining('EncryptionException'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('error-log-0')));
    await tester.pumpAndSettle();

    expect(find.text('Operación: image_import'), findsOneWidget);
    expect(find.text('Causa: PlatformException'), findsOneWidget);
    expect(
      find.text('Detalle seguro: platform:secure_failure'),
      findsOneWidget,
    );
    expect(
      find.textContaining('package:veyra/core/vault_service.dart'),
      findsOneWidget,
    );
    expect(find.textContaining('MasterKey'), findsNothing);
    expect(find.textContaining('4826'), findsNothing);

    await tester.tap(find.byKey(const ValueKey<String>('clear-error-logs')));
    await tester.pump();

    expect(
      find.text('No se han registrado errores en esta ejecución.'),
      findsOneWidget,
    );
  });
}
