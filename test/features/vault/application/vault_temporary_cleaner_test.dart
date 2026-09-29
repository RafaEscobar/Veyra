import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:veyra/features/vault/application/vault_temporary_cleaner.dart';

void main() {
  test('removes every temporary vault artifact', () async {
    final Directory root = await Directory.systemTemp.createTemp(
      'veyra-temp-cleaner-',
    );
    addTearDown(() async {
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    });
    final Directory temporary = Directory('${root.path}/vault/tmp');
    await temporary.create(recursive: true);
    await File('${temporary.path}/preview.jpg').writeAsBytes(<int>[1, 2, 3]);
    final Directory nested = Directory('${temporary.path}/nested');
    await nested.create();
    await File('${nested.path}/video.mp4').writeAsBytes(<int>[4, 5]);
    final PrivateVaultTemporaryCleaner cleaner = PrivateVaultTemporaryCleaner(
      directoryProvider: () async => root,
    );

    await cleaner.clear();

    expect(await temporary.list().toList(), isEmpty);
  });
}
