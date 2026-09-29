import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:veyra/core/errors/app_exception.dart';
import 'package:veyra/core/security/screen_security_service.dart';
import 'package:veyra/features/vault/domain/entities/vault_item.dart';
import 'package:veyra/features/videos/presentation/pages/vault_video_player_screen.dart';

void main() {
  testWidgets('handles a corrupted video and allows deleting its record', (
    tester,
  ) async {
    bool deleted = false;
    await tester.pumpWidget(
      MaterialApp(
        home: VaultVideoPlayerScreen(
          item: _item,
          prepareVideo: (item) =>
              Future<File>.error(const VaultFileCorruptedException()),
          releaseVideo: (file) async {},
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
      find.byKey(const ValueKey<String>('delete-corrupted-video')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('confirm-delete-corrupted-video')),
    );
    await tester.pumpAndSettle();

    expect(deleted, isTrue);
  });
}

final VaultItem _item = VaultItem(
  id: 'video-id',
  originalName: 'private.mp4',
  encryptedFileName: 'video-id.dat',
  type: VaultItemType.video,
  mimeType: 'video/mp4',
  size: 100,
  createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  importedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
);

final class FakeScreenSecurity implements ScreenSecurityService {
  @override
  Future<void> setSecure(bool secure) async {}
}
