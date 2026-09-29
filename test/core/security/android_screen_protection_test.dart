import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String activitySource;
  late String androidBuildSource;

  setUpAll(() async {
    activitySource = await File(
      'android/app/src/main/kotlin/com/veyra/app/MainActivity.kt',
    ).readAsString();
    androidBuildSource = await File(
      'android/app/build.gradle.kts',
    ).readAsString();
  });

  test('enables FLAG_SECURE globally before Flutter renders', () {
    final int onCreate = activitySource.indexOf('override fun onCreate');
    final int protection = activitySource.indexOf(
      'enableGlobalScreenProtection()',
      onCreate,
    );
    final int superOnCreate = activitySource.indexOf(
      'super.onCreate(savedInstanceState)',
      onCreate,
    );

    expect(onCreate, greaterThanOrEqualTo(0));
    expect(protection, greaterThan(onCreate));
    expect(protection, lessThan(superOnCreate));
    expect(
      activitySource,
      contains('window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)'),
    );
    expect(activitySource, isNot(contains('clearFlags')));
  });

  test('prevents recents snapshots on API 33 and newer', () {
    expect(
      activitySource,
      contains('Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU'),
    );
    expect(activitySource, contains('setRecentsScreenshotEnabled(false)'));
    expect(activitySource, contains('override fun onResume()'));
  });

  test(
    'keeps FLAG_SECURE available across every supported Android version',
    () {
      expect(androidBuildSource, contains('minSdk = 24'));
      expect(
        activitySource,
        isNot(
          contains(
            'if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {\n'
            '            enableGlobalScreenProtection()',
          ),
        ),
      );
    },
  );
}
