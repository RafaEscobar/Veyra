import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const Set<String> _allBackupDomains = <String>{
  'root',
  'file',
  'database',
  'sharedpref',
  'external',
  'device_root',
  'device_file',
  'device_database',
  'device_sharedpref',
};

void main() {
  late String manifest;
  late String legacyRules;
  late String modernRules;

  setUpAll(() async {
    manifest = await File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsString();
    legacyRules = await File(
      'android/app/src/main/res/xml/backup_rules.xml',
    ).readAsString();
    modernRules = await File(
      'android/app/src/main/res/xml/data_extraction_rules.xml',
    ).readAsString();
  });

  test('manifest disables backup and references both rule generations', () {
    expect(manifest, contains('android:allowBackup="false"'));
    expect(manifest, contains('android:fullBackupContent="@xml/backup_rules"'));
    expect(
      manifest,
      contains('android:dataExtractionRules="@xml/data_extraction_rules"'),
    );
  });

  test('legacy rules exclude every backup domain', () {
    expect(_excludedDomains(legacyRules), _allBackupDomains);
    expect(legacyRules, isNot(contains('<include')));
  });

  test('modern rules exclude every domain from cloud and device transfer', () {
    final String cloudRules = _section(modernRules, 'cloud-backup');
    final String transferRules = _section(modernRules, 'device-transfer');

    expect(_excludedDomains(cloudRules), _allBackupDomains);
    expect(_excludedDomains(transferRules), _allBackupDomains);
    expect(modernRules, isNot(contains('<include')));
    expect(cloudRules, contains('disableIfNoEncryptionCapabilities="true"'));
  });

  test('simulated backup and restore produces an empty data snapshot', () {
    final Map<String, List<String>> privateData = <String, List<String>>{
      'file': <String>['vault/images/item.dat', 'vault/tmp/preview.jpg'],
      'database': <String>['veyra_vault.db'],
      'sharedpref': <String>['FlutterSecureStorage.xml'],
      'root': <String>['files/device_state'],
      'external': <String>['export-cache/item.jpg'],
      'device_file': <String>['vault/device-item.dat'],
      'device_database': <String>['device-vault.db'],
      'device_sharedpref': <String>['device-secrets.xml'],
      'device_root': <String>['device-state'],
    };

    for (final String rules in <String>[
      legacyRules,
      _section(modernRules, 'cloud-backup'),
      _section(modernRules, 'device-transfer'),
    ]) {
      final Set<String> excluded = _excludedDomains(rules);
      final Map<String, List<String>> backupSnapshot = Map.fromEntries(
        privateData.entries.where((entry) => !excluded.contains(entry.key)),
      );
      final Map<String, List<String>> restoredData = <String, List<String>>{}
        ..addAll(backupSnapshot);

      expect(backupSnapshot, isEmpty);
      expect(restoredData, isEmpty);
    }
  });
}

Set<String> _excludedDomains(String xml) {
  return RegExp(
    r'<exclude\s+domain="([^"]+)"\s+path="\."\s*/>',
  ).allMatches(xml).map((match) => match.group(1)!).toSet();
}

String _section(String xml, String tag) {
  final RegExpMatch? match = RegExp(
    '<$tag(?:\\s+[^>]*)?>([\\s\\S]*?)</$tag>',
  ).firstMatch(xml);
  expect(match, isNotNull, reason: 'Missing <$tag> backup section.');
  return match!.group(0)!;
}
