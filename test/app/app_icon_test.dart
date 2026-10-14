import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('provides the Veyra launcher icon for every Android density', () {
    const Map<String, int> icons = <String, int>{
      'mdpi': 48,
      'hdpi': 72,
      'xhdpi': 96,
      'xxhdpi': 144,
      'xxxhdpi': 192,
    };

    for (final MapEntry<String, int> icon in icons.entries) {
      final File file = File(
        'android/app/src/main/res/mipmap-${icon.key}/ic_launcher.png',
      );
      expect(file.existsSync(), isTrue, reason: icon.key);
      final Uint8List bytes = file.readAsBytesSync();
      expect(_pngDimension(bytes, 16), icon.value, reason: icon.key);
      expect(_pngDimension(bytes, 20), icon.value, reason: icon.key);
    }
  });

  test('provides an adaptive icon for Android 8 and newer', () {
    final String adaptiveIcon = File(
      'android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml',
    ).readAsStringSync();
    expect(adaptiveIcon, contains('@color/ic_launcher_background'));
    expect(adaptiveIcon, contains('@drawable/ic_launcher_foreground'));
  });
}

int _pngDimension(Uint8List bytes, int offset) {
  return ByteData.sublistView(bytes).getUint32(offset);
}
