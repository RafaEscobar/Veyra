import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String manifest;
  late String activity;
  late String errorHandler;
  late String privateStorage;
  late String productionDart;

  setUpAll(() async {
    manifest = await File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsString();
    activity = await File(
      'android/app/src/main/kotlin/com/veyra/app/MainActivity.kt',
    ).readAsString();
    errorHandler = await File(
      'lib/core/errors/app_error_handler.dart',
    ).readAsString();
    privateStorage = await File(
      'lib/features/vault/data/storage/private_vault_file_storage.dart',
    ).readAsString();
    productionDart =
        (await Directory('lib')
                .list(recursive: true, followLinks: false)
                .where(
                  (entity) => entity is File && entity.path.endsWith('.dart'),
                )
                .cast<File>()
                .toList())
            .map((file) => file.readAsStringSync())
            .join('\n');
  });

  test('production manifest disables backup and cleartext traffic', () {
    expect(manifest, contains('android:allowBackup="false"'));
    expect(manifest, contains('android:fullBackupContent="false"'));
    expect(manifest, contains('android:usesCleartextTraffic="false"'));
  });

  test('production manifest contains only required media permissions', () {
    final Iterable<String> permissions = RegExp(r'<uses-permission[^>]+>')
        .allMatches(manifest)
        .map((match) => match.group(0)!)
        .where((declaration) => !declaration.contains('tools:node="remove"'))
        .map(
          (declaration) => RegExp(
            r'android:name="([^"]+)"',
          ).firstMatch(declaration)!.group(1)!,
        );

    expect(permissions.toSet(), <String>{
      'android.permission.READ_EXTERNAL_STORAGE',
      'android.permission.READ_MEDIA_IMAGES',
      'android.permission.READ_MEDIA_VIDEO',
      'android.permission.READ_MEDIA_VISUAL_USER_SELECTED',
    });
    expect(manifest, contains('android:maxSdkVersion="32"'));
    expect(
      manifest,
      contains(
        'android:name="android.permission.ACCESS_NETWORK_STATE" '
        'tools:node="remove"',
      ),
    );
    expect(
      manifest,
      contains(
        'android:name="android.permission.WAKE_LOCK" tools:node="remove"',
      ),
    );
  });

  test('vault storage stays private and rejects path traversal', () {
    expect(privateStorage, contains('getApplicationSupportDirectory'));
    expect(privateStorage, contains('path.basename(fileName) != fileName'));
    expect(privateStorage, isNot(contains('getExternalStorageDirectory')));
  });

  test('production source contains no literal PIN or direct print calls', () {
    expect(productionDart, isNot(matches(RegExp(r'''['"]\d{4}['"]'''))));
    expect(productionDart, isNot(contains('print(')));
    expect(errorHandler, contains("'unexpected_error'"));
    expect(errorHandler, isNot(contains('stackTrace.toString')));
    expect(errorHandler, isNot(contains('error.toString')));
  });

  test('Android protects screenshots and the recent-apps snapshot', () {
    expect(
      activity,
      contains('window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)'),
    );
    expect(activity, contains('setRecentsScreenshotEnabled(false)'));
  });
}
