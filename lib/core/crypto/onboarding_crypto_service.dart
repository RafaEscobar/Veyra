import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:veyra/core/constants/app_constants.dart';
import 'package:veyra/core/crypto/crypto_service.dart';
import 'package:veyra/core/errors/app_exception.dart';
import 'package:veyra/core/security/encrypted_value.dart';
import 'package:veyra/core/security/pin_key_replacement.dart';
import 'package:veyra/core/security/security_config.dart';

final class OnboardingCryptoService {
  OnboardingCryptoService({
    int kdfIterations = 310000,
    CryptoService? cryptoService,
  }) : _cryptoService =
           cryptoService ?? CryptoService(kdfIterations: kdfIterations),
       kdfIterations = cryptoService?.kdfIterations ?? kdfIterations;

  static const String _pinPurpose = 'pin';
  static const String _recoveryPurpose = 'recovery';

  final int kdfIterations;
  final CryptoService _cryptoService;
  final AesGcm _cipher = AesGcm.with256bits();

  Future<SecurityConfig> createSecurityConfig({
    required String pin,
    required String normalizedRecoveryAnswer,
    required String securityQuestionId,
  }) async {
    _validateInput(pin, normalizedRecoveryAnswer, securityQuestionId);

    final SecretKeyData masterKey = await _cryptoService.generateMasterKey();
    final Uint8List pinSalt = _cryptoService.generateSalt();
    final Uint8List recoverySalt = _cryptoService.generateSalt();

    try {
      final EncryptedValue pinWrapper = await _wrapMasterKey(
        masterKey: masterKey,
        password: pin,
        salt: pinSalt,
        purpose: _pinPurpose,
        iterations: kdfIterations,
      );
      final EncryptedValue recoveryWrapper = await _wrapMasterKey(
        masterKey: masterKey,
        password: normalizedRecoveryAnswer,
        salt: recoverySalt,
        purpose: _recoveryPurpose,
        iterations: kdfIterations,
      );

      return SecurityConfig(
        version: 1,
        kdfAlgorithm: 'PBKDF2-HMAC-SHA256',
        kdfIterations: kdfIterations,
        cipherAlgorithm: 'AES-256-GCM',
        pinSalt: base64Encode(pinSalt),
        encryptedMasterKeyWithPin: pinWrapper,
        recoverySalt: base64Encode(recoverySalt),
        encryptedMasterKeyWithRecovery: recoveryWrapper,
        securityQuestionId: securityQuestionId,
        failedAttempts: 0,
        lockUntil: null,
        createdAt: DateTime.now().toUtc(),
      );
    } finally {
      masterKey.destroy();
      pinSalt.fillRange(0, pinSalt.length, 0);
      recoverySalt.fillRange(0, recoverySalt.length, 0);
    }
  }

  Future<Uint8List> unwrapWithPin(SecurityConfig config, String pin) {
    return _unwrapMasterKey(
      encryptedValue: config.encryptedMasterKeyWithPin,
      password: pin,
      salt: base64Decode(config.pinSalt),
      iterations: config.kdfIterations,
      purpose: _pinPurpose,
    );
  }

  Future<Uint8List> unwrapWithRecoveryAnswer(
    SecurityConfig config,
    String normalizedRecoveryAnswer,
  ) {
    return _unwrapMasterKey(
      encryptedValue: config.encryptedMasterKeyWithRecovery,
      password: normalizedRecoveryAnswer,
      salt: base64Decode(config.recoverySalt),
      iterations: config.kdfIterations,
      purpose: _recoveryPurpose,
    );
  }

  Future<PinKeyReplacement> createPinReplacement({
    required Uint8List masterKey,
    required String newPin,
    required int iterations,
  }) async {
    final RegExp pinPattern = RegExp('^\\d{${AppConstants.pinLength}}\$');
    if (!pinPattern.hasMatch(newPin)) {
      throw const FormatException('Invalid PIN.');
    }

    final Uint8List pinSalt = _cryptoService.generateSalt();
    final SecretKeyData temporaryMasterKey = SecretKeyData(
      Uint8List.fromList(masterKey),
      overwriteWhenDestroyed: true,
    );
    try {
      final EncryptedValue wrapper = await _wrapMasterKey(
        masterKey: temporaryMasterKey,
        password: newPin,
        salt: pinSalt,
        purpose: _pinPurpose,
        iterations: iterations,
      );
      return PinKeyReplacement(
        pinSalt: base64Encode(pinSalt),
        encryptedMasterKey: wrapper,
      );
    } finally {
      temporaryMasterKey.destroy();
      pinSalt.fillRange(0, pinSalt.length, 0);
    }
  }

  Future<EncryptedValue> _wrapMasterKey({
    required SecretKeyData masterKey,
    required String password,
    required List<int> salt,
    required String purpose,
    required int iterations,
  }) async {
    final SecretKey derivedKey = await _derivePurposeKey(
      password: password,
      salt: salt,
      purpose: purpose,
      iterations: iterations,
    );
    try {
      final SecretBox secretBox = await _cipher.encrypt(
        masterKey.bytes,
        secretKey: derivedKey,
        nonce: _cipher.newNonce(),
        aad: _associatedData(purpose),
      );
      return EncryptedValue.fromSecretBox(secretBox);
    } on Object catch (error) {
      throw EncryptionException(cause: error);
    } finally {
      derivedKey.destroy();
    }
  }

  Future<Uint8List> _unwrapMasterKey({
    required EncryptedValue encryptedValue,
    required String password,
    required List<int> salt,
    required int iterations,
    required String purpose,
  }) async {
    final SecretKey derivedKey = await _derivePurposeKey(
      password: password,
      salt: salt,
      purpose: purpose,
      iterations: iterations,
    );
    try {
      final List<int> clearText = await _cipher.decrypt(
        encryptedValue.toSecretBox(),
        secretKey: derivedKey,
        aad: _associatedData(purpose),
      );
      return Uint8List.fromList(clearText);
    } on SecretBoxAuthenticationError catch (error) {
      throw VaultFileCorruptedException(cause: error);
    } on Object catch (error) {
      throw DecryptionException(cause: error);
    } finally {
      derivedKey.destroy();
    }
  }

  Future<SecretKey> _derivePurposeKey({
    required String password,
    required List<int> salt,
    required String purpose,
    required int iterations,
  }) {
    return purpose == _pinPurpose
        ? _cryptoService.derivePinKey(
            pin: password,
            salt: salt,
            iterations: iterations,
          )
        : _cryptoService.deriveRecoveryKey(
            normalizedRecoveryAnswer: password,
            salt: salt,
            iterations: iterations,
          );
  }

  List<int> _associatedData(String purpose) {
    return utf8.encode('veyra.master-key.$purpose.v1');
  }

  void _validateInput(
    String pin,
    String normalizedRecoveryAnswer,
    String securityQuestionId,
  ) {
    final RegExp pinPattern = RegExp('^\\d{${AppConstants.pinLength}}\$');
    if (!pinPattern.hasMatch(pin)) {
      throw const FormatException('Invalid PIN.');
    }
    if (normalizedRecoveryAnswer.isEmpty || securityQuestionId.isEmpty) {
      throw const FormatException('Invalid recovery configuration.');
    }
  }
}
