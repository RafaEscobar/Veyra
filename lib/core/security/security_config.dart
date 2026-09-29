import 'dart:convert';

import 'package:veyra/core/security/encrypted_value.dart';

final class SecurityConfig {
  const SecurityConfig({
    required this.version,
    required this.kdfAlgorithm,
    required this.kdfIterations,
    required this.cipherAlgorithm,
    required this.pinSalt,
    required this.encryptedMasterKeyWithPin,
    required this.recoverySalt,
    required this.encryptedMasterKeyWithRecovery,
    required this.securityQuestionId,
    required this.failedAttempts,
    required this.lockUntil,
    required this.createdAt,
    this.recoveryFailedAttempts = 0,
    this.recoveryLockUntil,
  });

  factory SecurityConfig.fromJson(Map<String, Object?> json) {
    return SecurityConfig(
      version: _readInt(json, 'version'),
      kdfAlgorithm: _readString(json, 'kdfAlgorithm'),
      kdfIterations: _readInt(json, 'kdfIterations'),
      cipherAlgorithm: _readString(json, 'cipherAlgorithm'),
      pinSalt: _readString(json, 'pinSalt'),
      encryptedMasterKeyWithPin: EncryptedValue.fromJson(
        _readMap(json, 'encryptedMasterKeyWithPin'),
      ),
      recoverySalt: _readString(json, 'recoverySalt'),
      encryptedMasterKeyWithRecovery: EncryptedValue.fromJson(
        _readMap(json, 'encryptedMasterKeyWithRecovery'),
      ),
      securityQuestionId: _readString(json, 'securityQuestionId'),
      failedAttempts: _readInt(json, 'failedAttempts'),
      lockUntil: _readNullableDateTime(json, 'lockUntil'),
      createdAt: DateTime.parse(_readString(json, 'createdAt')).toUtc(),
      recoveryFailedAttempts: _readOptionalInt(json, 'recoveryFailedAttempts'),
      recoveryLockUntil: _readNullableDateTime(json, 'recoveryLockUntil'),
    );
  }

  factory SecurityConfig.fromJsonString(String value) {
    final Object? decoded = jsonDecode(value);
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('Invalid security configuration.');
    }
    return SecurityConfig.fromJson(decoded);
  }

  final int version;
  final String kdfAlgorithm;
  final int kdfIterations;
  final String cipherAlgorithm;
  final String pinSalt;
  final EncryptedValue encryptedMasterKeyWithPin;
  final String recoverySalt;
  final EncryptedValue encryptedMasterKeyWithRecovery;
  final String securityQuestionId;
  final int failedAttempts;
  final DateTime? lockUntil;
  final DateTime createdAt;
  final int recoveryFailedAttempts;
  final DateTime? recoveryLockUntil;

  SecurityConfig copyWith({
    String? pinSalt,
    EncryptedValue? encryptedMasterKeyWithPin,
    EncryptedValue? encryptedMasterKeyWithRecovery,
    int? failedAttempts,
    DateTime? lockUntil,
    bool clearLockUntil = false,
    int? recoveryFailedAttempts,
    DateTime? recoveryLockUntil,
    bool clearRecoveryLockUntil = false,
  }) {
    return SecurityConfig(
      version: version,
      kdfAlgorithm: kdfAlgorithm,
      kdfIterations: kdfIterations,
      cipherAlgorithm: cipherAlgorithm,
      pinSalt: pinSalt ?? this.pinSalt,
      encryptedMasterKeyWithPin:
          encryptedMasterKeyWithPin ?? this.encryptedMasterKeyWithPin,
      recoverySalt: recoverySalt,
      encryptedMasterKeyWithRecovery:
          encryptedMasterKeyWithRecovery ?? this.encryptedMasterKeyWithRecovery,
      securityQuestionId: securityQuestionId,
      failedAttempts: failedAttempts ?? this.failedAttempts,
      lockUntil: clearLockUntil ? null : lockUntil ?? this.lockUntil,
      createdAt: createdAt,
      recoveryFailedAttempts:
          recoveryFailedAttempts ?? this.recoveryFailedAttempts,
      recoveryLockUntil: clearRecoveryLockUntil
          ? null
          : recoveryLockUntil ?? this.recoveryLockUntil,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'version': version,
      'kdfAlgorithm': kdfAlgorithm,
      'kdfIterations': kdfIterations,
      'cipherAlgorithm': cipherAlgorithm,
      'pinSalt': pinSalt,
      'encryptedMasterKeyWithPin': encryptedMasterKeyWithPin.toJson(),
      'recoverySalt': recoverySalt,
      'encryptedMasterKeyWithRecovery': encryptedMasterKeyWithRecovery.toJson(),
      'securityQuestionId': securityQuestionId,
      'failedAttempts': failedAttempts,
      'lockUntil': lockUntil?.toUtc().toIso8601String(),
      'createdAt': createdAt.toUtc().toIso8601String(),
      'recoveryFailedAttempts': recoveryFailedAttempts,
      'recoveryLockUntil': recoveryLockUntil?.toUtc().toIso8601String(),
    };
  }

  String toJsonString() => jsonEncode(toJson());
}

int _readInt(Map<String, Object?> json, String key) {
  final Object? value = json[key];
  if (value is! int) {
    throw const FormatException('Invalid security configuration.');
  }
  return value;
}

int _readOptionalInt(Map<String, Object?> json, String key) {
  final Object? value = json[key];
  if (value == null) {
    return 0;
  }
  if (value is! int) {
    throw const FormatException('Invalid security configuration.');
  }
  return value;
}

Map<String, Object?> _readMap(Map<String, Object?> json, String key) {
  final Object? value = json[key];
  if (value is! Map<String, Object?>) {
    throw const FormatException('Invalid security configuration.');
  }
  return value;
}

DateTime? _readNullableDateTime(Map<String, Object?> json, String key) {
  final Object? value = json[key];
  if (value == null) {
    return null;
  }
  if (value is! String) {
    throw const FormatException('Invalid security configuration.');
  }
  return DateTime.parse(value).toUtc();
}

String _readString(Map<String, Object?> json, String key) {
  final Object? value = json[key];
  if (value is! String || value.isEmpty) {
    throw const FormatException('Invalid security configuration.');
  }
  return value;
}
