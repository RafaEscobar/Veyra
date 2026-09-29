import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

final class VaultSession {
  SecretKeyData? _masterKey;

  bool get isUnlocked => _masterKey != null;

  void open(Uint8List masterKeyBytes) {
    lock();
    _masterKey = SecretKeyData(
      Uint8List.fromList(masterKeyBytes),
      overwriteWhenDestroyed: true,
    );
  }

  Future<T> withMasterKey<T>(Future<T> Function(SecretKey key) operation) {
    final SecretKeyData? masterKey = _masterKey;
    if (masterKey == null) {
      throw StateError('Vault session is locked.');
    }
    return operation(masterKey);
  }

  void lock() {
    _masterKey?.destroy();
    _masterKey = null;
  }
}
