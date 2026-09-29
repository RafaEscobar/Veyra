import 'package:veyra/core/security/encrypted_value.dart';

final class PinKeyReplacement {
  const PinKeyReplacement({
    required this.pinSalt,
    required this.encryptedMasterKey,
  });

  final String pinSalt;
  final EncryptedValue encryptedMasterKey;
}
