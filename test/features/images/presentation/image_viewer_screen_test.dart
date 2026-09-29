import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MethodChannel;
import 'package:flutter_test/flutter_test.dart';
import 'package:veyra/core/errors/app_exception.dart';
import 'package:veyra/core/security/screen_security_service.dart';
import 'package:veyra/features/images/presentation/pages/image_viewer_screen.dart';
import 'package:veyra/features/vault/domain/entities/vault_item.dart';

void main() {
  testWidgets('protects fullscreen viewer, supports zoom, and clears memory', (
    tester,
  ) async {
    final FakeScreenSecurity screenSecurity = FakeScreenSecurity();
    final Uint8List imageBytes = _pngBytes();

    await tester.pumpWidget(
      MaterialApp(
        home: ImageViewerScreen(
          item: _item,
          imageLoader: (item) async => imageBytes,
          onDelete: (item) async => true,
          onExport: (item) async {},
          screenSecurity: screenSecurity,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(screenSecurity.values, <bool>[true]);
    expect(find.byKey(const ValueKey<String>('vault-image-preview')), findsOne);
    final InteractiveViewer viewer = tester.widget<InteractiveViewer>(
      find.byKey(const ValueKey<String>('vault-image-zoom')),
    );
    expect(viewer.minScale, 1);
    expect(viewer.maxScale, 5);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();

    expect(screenSecurity.values, <bool>[true, false]);
    expect(imageBytes.every((byte) => byte == 0), isTrue);
  });

  testWidgets('confirms deletion from the viewer', (tester) async {
    final FakeScreenSecurity screenSecurity = FakeScreenSecurity();
    bool deleted = false;
    await tester.pumpWidget(
      MaterialApp(
        home: ImageViewerScreen(
          item: _item,
          imageLoader: (item) async => _pngBytes(),
          onDelete: (item) async {
            deleted = true;
            return true;
          },
          onExport: (item) async {},
          screenSecurity: screenSecurity,
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey<String>('delete-vault-image')));
    await tester.pumpAndSettle();
    expect(find.text('Eliminar permanentemente'), findsOne);
    expect(
      find.text(
        'Este archivo será eliminado de la bóveda. '
        'Esta acción no se puede deshacer.',
      ),
      findsOne,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('confirm-delete-image')),
    );
    await tester.pumpAndSettle();

    expect(deleted, isTrue);
  });

  testWidgets('shows a friendly error without technical details', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ImageViewerScreen(
          item: _item,
          imageLoader: (item) => Future<Uint8List>.error(
            EncryptionException(cause: StateError('MasterKey=secret')),
          ),
          onDelete: (item) async => true,
          onExport: (item) async {},
          screenSecurity: FakeScreenSecurity(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('No se pudo proteger el archivo. Inténtalo de nuevo.'),
      findsOneWidget,
    );
    expect(find.textContaining('MasterKey'), findsNothing);
    expect(find.textContaining('StateError'), findsNothing);
  });

  testWidgets('shows corruption message and still allows deletion', (
    tester,
  ) async {
    bool deleted = false;
    await tester.pumpWidget(
      MaterialApp(
        home: ImageViewerScreen(
          item: _item,
          imageLoader: (item) =>
              Future<Uint8List>.error(const VaultFileCorruptedException()),
          onDelete: (item) async {
            deleted = true;
            return true;
          },
          onExport: (item) async {},
          screenSecurity: FakeScreenSecurity(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'No se pudo abrir este elemento.\nEl archivo puede estar dañado.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey<String>('delete-vault-image')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('confirm-delete-image')),
    );
    await tester.pumpAndSettle();

    expect(deleted, isTrue);
  });

  test('method channel maps secure states to native method names', () async {
    final List<String> calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.veyra.app/screen_security'),
          (call) async {
            calls.add(call.method);
            return null;
          },
        );
    const MethodChannelScreenSecurityService service =
        MethodChannelScreenSecurityService();

    await service.setSecure(true);
    await service.setSecure(false);

    expect(calls, <String>['enableSecure', 'disableSecure']);
  });
}

final VaultItem _item = VaultItem(
  id: 'image-id',
  originalName: 'private.jpg',
  encryptedFileName: 'image-id.dat',
  type: VaultItemType.image,
  mimeType: 'image/jpeg',
  size: 100,
  createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  importedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
);

Uint8List _pngBytes() => Uint8List.fromList(
  base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
  ),
);

final class FakeScreenSecurity implements ScreenSecurityService {
  final List<bool> values = <bool>[];

  @override
  Future<void> setSecure(bool secure) async {
    values.add(secure);
  }
}
