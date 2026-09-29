import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:veyra/core/errors/app_exception.dart';
import 'package:veyra/core/security/screen_security_service.dart';
import 'package:veyra/features/files/presentation/pages/document_preview_screen.dart';
import 'package:veyra/features/vault/domain/entities/vault_item.dart';

void main() {
  testWidgets('handles a corrupted document and allows deleting its record', (
    tester,
  ) async {
    bool deleted = false;
    await tester.pumpWidget(
      MaterialApp(
        home: DocumentPreviewScreen(
          item: _item,
          textLoader: (item) =>
              Future<String>.error(const VaultFileCorruptedException()),
          onDelete: (item) async {
            deleted = true;
            return true;
          },
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
    await tester.tap(
      find.byKey(const ValueKey<String>('delete-corrupted-file')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('confirm-delete-corrupted-file')),
    );
    await tester.pumpAndSettle();

    expect(deleted, isTrue);
  });
}

final VaultItem _item = VaultItem(
  id: 'document-id',
  originalName: 'private.txt',
  encryptedFileName: 'document-id.dat',
  type: VaultItemType.file,
  mimeType: 'text/plain',
  size: 100,
  createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  importedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
);

final class FakeScreenSecurity implements ScreenSecurityService {
  @override
  Future<void> setSecure(bool secure) async {}
}
