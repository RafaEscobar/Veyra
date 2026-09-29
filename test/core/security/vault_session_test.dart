import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:veyra/core/security/vault_session.dart';

void main() {
  test('owns an isolated copy of the master key only while unlocked', () async {
    final VaultSession session = VaultSession();
    final Uint8List source = Uint8List.fromList(
      List<int>.generate(32, (index) => index + 1),
    );
    final Uint8List expected = Uint8List.fromList(source);

    session.open(source);
    source.fillRange(0, source.length, 0);

    final List<int> sessionBytes = await session.withMasterKey(
      (key) => key.extractBytes(),
    );
    expect(sessionBytes, expected);
    session.lock();
    expected.fillRange(0, expected.length, 0);
  });

  test('locking destroys the key and rejects all further access', () async {
    final VaultSession session = VaultSession();
    session.open(Uint8List.fromList(List<int>.filled(32, 0x7a)));
    SecretKeyData? heldReference;
    await session.withMasterKey((key) async {
      heldReference = key as SecretKeyData;
    });

    session.lock();

    expect(session.isUnlocked, isFalse);
    expect(heldReference?.isDestroyed, isTrue);
    await expectLater(() => heldReference!.extractBytes(), throwsStateError);
    await expectLater(
      () => session.withMasterKey((key) async => key.extractBytes()),
      throwsStateError,
    );
  });

  test('session has no serializable clear-key representation', () {
    final VaultSession session = VaultSession()
      ..open(Uint8List.fromList(List<int>.filled(32, 0x42)));
    final String encodedKey = base64Encode(List<int>.filled(32, 0x42));

    expect(
      () => jsonEncode(session),
      throwsA(isA<JsonUnsupportedObjectError>()),
    );
    expect(session.toString(), isNot(contains(encodedKey)));
    session.lock();
  });
}
