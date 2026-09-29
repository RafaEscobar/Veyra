import 'dart:convert';

import 'package:cryptography/cryptography.dart';

final class EncryptedValue {
  const EncryptedValue({
    required this.cipherText,
    required this.nonce,
    required this.mac,
  });

  factory EncryptedValue.fromJson(Map<String, Object?> json) {
    return EncryptedValue(
      cipherText: _readString(json, 'cipherText'),
      nonce: _readString(json, 'nonce'),
      mac: _readString(json, 'mac'),
    );
  }

  factory EncryptedValue.fromSecretBox(SecretBox secretBox) {
    return EncryptedValue(
      cipherText: base64Encode(secretBox.cipherText),
      nonce: base64Encode(secretBox.nonce),
      mac: base64Encode(secretBox.mac.bytes),
    );
  }

  final String cipherText;
  final String nonce;
  final String mac;

  SecretBox toSecretBox() {
    return SecretBox(
      base64Decode(cipherText),
      nonce: base64Decode(nonce),
      mac: Mac(base64Decode(mac)),
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'cipherText': cipherText,
      'nonce': nonce,
      'mac': mac,
    };
  }
}

String _readString(Map<String, Object?> json, String key) {
  final Object? value = json[key];
  if (value is! String || value.isEmpty) {
    throw const FormatException('Invalid encrypted value.');
  }
  return value;
}
