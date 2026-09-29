import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:veyra/features/vault/data/storage/private_temporary_file_manager.dart';
import 'package:veyra/features/vault/data/storage/private_vault_file_storage.dart';

void main() {
  late Directory root;
  late PrivateTemporaryFileManager manager;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('veyra-temp-manager-');
    manager = PrivateTemporaryFileManager(directoryProvider: () async => root);
  });

  tearDown(() async {
    if (await root.exists()) {
      await root.delete(recursive: true);
    }
  });

  test(
    'registers and releases temporary files through vault storage',
    () async {
      final PrivateVaultFileStorage storage = PrivateVaultFileStorage(
        directoryProvider: () async => root,
        temporaryFileManager: manager,
      );

      final File temporary = await storage.temporaryFile('viewer.mp4');
      await temporary.writeAsBytes(<int>[1, 2, 3]);

      expect(manager.isRegistered(temporary), isTrue);
      expect(await temporary.exists(), isTrue);

      await storage.deleteIfExists(temporary);

      expect(manager.isRegistered(temporary), isFalse);
      expect(await temporary.exists(), isFalse);
    },
  );

  test('removes orphaned files left by an interrupted execution', () async {
    final File orphan = await manager.create('orphan-preview.jpg');
    await orphan.writeAsBytes(<int>[4, 5, 6]);
    final Directory nested = Directory('${orphan.parent.path}/stale');
    await nested.create();
    await File('${nested.path}/orphan-video.mp4').writeAsBytes(<int>[7, 8]);

    final PrivateTemporaryFileManager nextLaunchManager =
        PrivateTemporaryFileManager(directoryProvider: () async => root);
    expect(nextLaunchManager.isRegistered(orphan), isFalse);

    await nextLaunchManager.clear();

    expect(await orphan.parent.list().toList(), isEmpty);
  });

  test('rejects paths outside the private temporary directory', () async {
    expect(
      () => manager.create('../outside.txt'),
      throwsA(isA<FormatException>()),
    );
  });
}
