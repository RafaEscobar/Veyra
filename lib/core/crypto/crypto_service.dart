import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:veyra/core/constants/app_constants.dart';
import 'package:veyra/core/errors/app_exception.dart';
import 'package:veyra/core/errors/app_exception_mapper.dart';
import 'package:veyra/core/security/encrypted_value.dart';

final class CryptoService {
  CryptoService({
    this.kdfIterations = 310000,
    this.fileChunkSize = 64 * 1024,
    this.random,
  });

  static const int masterKeyLength = 32;
  static const int saltLength = 16;
  static const int _derivedKeyBits = 256;
  static const int _nonceLength = 12;
  static const int _macLength = 16;
  static const int _maximumChunkSize = 4 * 1024 * 1024;
  static const int _formatVersion = 1;
  static const List<int> _fileMagic = <int>[0x56, 0x45, 0x59, 0x52, 0x41];
  static const int _headerLength = 5 + 1 + _nonceLength + 8 + 4;

  final int kdfIterations;
  final int fileChunkSize;
  final Random? random;
  final AesGcm _cipher = AesGcm.with256bits();

  Future<SecretKeyData> generateMasterKey() async {
    return SecretKeyData.random(length: masterKeyLength, random: random);
  }

  Uint8List generateSalt({int length = saltLength}) {
    if (length < saltLength) {
      throw ArgumentError.value(length, 'length', 'Must be at least 16 bytes.');
    }
    return _randomBytes(length);
  }

  Future<SecretKey> derivePinKey({
    required String pin,
    required List<int> salt,
    int? iterations,
  }) {
    final RegExp pinPattern = RegExp('^\\d{${AppConstants.pinLength}}\$');
    if (!pinPattern.hasMatch(pin)) {
      throw const FormatException('Invalid PIN.');
    }
    return _deriveKey(
      password: pin,
      salt: salt,
      iterations: iterations ?? kdfIterations,
    );
  }

  Future<SecretKey> deriveRecoveryKey({
    required String normalizedRecoveryAnswer,
    required List<int> salt,
    int? iterations,
  }) {
    if (normalizedRecoveryAnswer.isEmpty) {
      throw const FormatException('Invalid recovery answer.');
    }
    return _deriveKey(
      password: normalizedRecoveryAnswer,
      salt: salt,
      iterations: iterations ?? kdfIterations,
    );
  }

  Future<EncryptedValue> encryptBytes({
    required List<int> clearText,
    required SecretKey secretKey,
    List<int>? nonce,
  }) async {
    try {
      final SecretBox secretBox = await _cipher.encrypt(
        clearText,
        secretKey: secretKey,
        nonce: nonce ?? _randomBytes(_nonceLength),
        aad: _bytesAssociatedData,
      );
      return EncryptedValue.fromSecretBox(secretBox);
    } on Object catch (error) {
      throw EncryptionException(cause: error);
    }
  }

  Future<Uint8List> decryptBytes({
    required EncryptedValue encryptedValue,
    required SecretKey secretKey,
  }) async {
    try {
      final List<int> clearText = await _cipher.decrypt(
        encryptedValue.toSecretBox(),
        secretKey: secretKey,
        aad: _bytesAssociatedData,
      );
      return Uint8List.fromList(clearText);
    } on SecretBoxAuthenticationError catch (error) {
      throw VaultFileCorruptedException(cause: error);
    } on Object catch (error) {
      throw DecryptionException(cause: error);
    }
  }

  Future<void> encryptFile({
    required File inputFile,
    required File outputFile,
    required SecretKey secretKey,
  }) async {
    _validateChunkSize(fileChunkSize);
    final int clearTextLength = await inputFile.length();
    final int chunkCount = _chunkCount(clearTextLength, fileChunkSize);
    _validateChunkCount(chunkCount);

    final Uint8List fileNonce = _randomBytes(_nonceLength);
    final Uint8List header = _createHeader(
      fileNonce: fileNonce,
      clearTextLength: clearTextLength,
      chunkSize: fileChunkSize,
    );
    final File temporaryFile = _temporaryFileFor(outputFile);
    RandomAccessFile? input;
    RandomAccessFile? output;
    bool completed = false;

    try {
      await temporaryFile.parent.create(recursive: true);
      input = await inputFile.open();
      output = await temporaryFile.open(mode: FileMode.writeOnly);
      await output.writeFrom(header);

      for (int index = 0; index < chunkCount; index++) {
        final int clearChunkLength = _clearChunkLength(
          index: index,
          chunkCount: chunkCount,
          clearTextLength: clearTextLength,
          chunkSize: fileChunkSize,
        );
        final Uint8List clearChunk = await _readExact(input, clearChunkLength);
        try {
          final SecretBox secretBox = await _cipher.encrypt(
            clearChunk,
            secretKey: secretKey,
            nonce: _nonceFor(fileNonce, index),
            aad: _chunkAssociatedData(header, index),
          );
          await output.writeFrom(secretBox.cipherText);
          await output.writeFrom(secretBox.mac.bytes);
        } finally {
          clearChunk.fillRange(0, clearChunk.length, 0);
        }
      }

      await output.flush();
      await input.close();
      input = null;
      await output.close();
      output = null;
      await _replaceFile(temporaryFile, outputFile);
      completed = true;
    } on AppException {
      rethrow;
    } on Object catch (error) {
      throw AppExceptionMapper.map(
        error,
        fallback: (cause) => EncryptionException(cause: cause),
      );
    } finally {
      await input?.close();
      await output?.close();
      fileNonce.fillRange(0, fileNonce.length, 0);
      if (!completed && await temporaryFile.exists()) {
        await temporaryFile.delete();
      }
    }
  }

  Future<void> decryptFile({
    required File inputFile,
    required File outputFile,
    required SecretKey secretKey,
  }) async {
    final File temporaryFile = _temporaryFileFor(outputFile);
    RandomAccessFile? input;
    RandomAccessFile? output;
    bool completed = false;

    try {
      input = await inputFile.open();
      final int encryptedLength = await input.length();
      final Uint8List header = await _readExact(input, _headerLength);
      final _FileHeader parsedHeader = _parseHeader(header);
      final int chunkCount = _chunkCount(
        parsedHeader.clearTextLength,
        parsedHeader.chunkSize,
      );
      _validateChunkCount(chunkCount);
      final int expectedLength =
          _headerLength +
          parsedHeader.clearTextLength +
          (chunkCount * _macLength);
      if (encryptedLength != expectedLength) {
        throw const FormatException('Invalid encrypted file length.');
      }

      await temporaryFile.parent.create(recursive: true);
      output = await temporaryFile.open(mode: FileMode.writeOnly);

      for (int index = 0; index < chunkCount; index++) {
        final int cipherChunkLength = _clearChunkLength(
          index: index,
          chunkCount: chunkCount,
          clearTextLength: parsedHeader.clearTextLength,
          chunkSize: parsedHeader.chunkSize,
        );
        final Uint8List cipherText = await _readExact(input, cipherChunkLength);
        final Uint8List macBytes = await _readExact(input, _macLength);
        final List<int> clearText = await _cipher.decrypt(
          SecretBox(
            cipherText,
            nonce: _nonceFor(parsedHeader.fileNonce, index),
            mac: Mac(macBytes),
          ),
          secretKey: secretKey,
          aad: _chunkAssociatedData(header, index),
        );
        try {
          await output.writeFrom(clearText);
        } finally {
          if (clearText is Uint8List) {
            clearText.fillRange(0, clearText.length, 0);
          }
        }
      }

      await output.flush();
      await input.close();
      input = null;
      await output.close();
      output = null;
      await _replaceFile(temporaryFile, outputFile);
      completed = true;
    } on SecretBoxAuthenticationError catch (error) {
      throw InvalidEncryptedFileException(cause: error);
    } on FormatException catch (error) {
      throw InvalidEncryptedFileException(cause: error);
    } on RangeError catch (error) {
      throw InvalidEncryptedFileException(cause: error);
    } on AppException {
      rethrow;
    } on Object catch (error) {
      throw AppExceptionMapper.map(
        error,
        fallback: (cause) => DecryptionException(cause: cause),
      );
    } finally {
      await input?.close();
      await output?.close();
      if (!completed && await temporaryFile.exists()) {
        await temporaryFile.delete();
      }
    }
  }

  Future<SecretKey> _deriveKey({
    required String password,
    required List<int> salt,
    required int iterations,
  }) {
    if (salt.length < saltLength) {
      throw const FormatException('Invalid salt.');
    }
    if (iterations <= 0) {
      throw StateError('KDF iterations must be positive.');
    }
    final Pbkdf2 kdf = Pbkdf2.hmacSha256(
      iterations: iterations,
      bits: _derivedKeyBits,
    );
    return kdf.deriveKeyFromPassword(password: password, nonce: salt);
  }

  Uint8List _createHeader({
    required Uint8List fileNonce,
    required int clearTextLength,
    required int chunkSize,
  }) {
    final Uint8List header = Uint8List(_headerLength);
    header.setRange(0, _fileMagic.length, _fileMagic);
    header[_fileMagic.length] = _formatVersion;
    final int nonceOffset = _fileMagic.length + 1;
    header.setRange(nonceOffset, nonceOffset + _nonceLength, fileNonce);
    final ByteData data = ByteData.sublistView(header);
    data.setUint64(nonceOffset + _nonceLength, clearTextLength);
    data.setUint32(nonceOffset + _nonceLength + 8, chunkSize);
    return header;
  }

  _FileHeader _parseHeader(Uint8List header) {
    if (header.length != _headerLength) {
      throw const FormatException('Invalid encrypted file header.');
    }
    for (int index = 0; index < _fileMagic.length; index++) {
      if (header[index] != _fileMagic[index]) {
        throw const FormatException('Invalid encrypted file magic.');
      }
    }
    if (header[_fileMagic.length] != _formatVersion) {
      throw const FormatException('Unsupported encrypted file version.');
    }

    final int nonceOffset = _fileMagic.length + 1;
    final Uint8List fileNonce = Uint8List.fromList(
      header.sublist(nonceOffset, nonceOffset + _nonceLength),
    );
    final ByteData data = ByteData.sublistView(header);
    final int clearTextLength = data.getUint64(nonceOffset + _nonceLength);
    final int chunkSize = data.getUint32(nonceOffset + _nonceLength + 8);
    _validateChunkSize(chunkSize);
    return _FileHeader(
      fileNonce: fileNonce,
      clearTextLength: clearTextLength,
      chunkSize: chunkSize,
    );
  }

  Uint8List _nonceFor(Uint8List fileNonce, int chunkIndex) {
    final Uint8List nonce = Uint8List.fromList(fileNonce);
    final ByteData data = ByteData.sublistView(nonce);
    final int counterOffset = _nonceLength - 4;
    data.setUint32(counterOffset, data.getUint32(counterOffset) ^ chunkIndex);
    return nonce;
  }

  Uint8List _chunkAssociatedData(Uint8List header, int chunkIndex) {
    final Uint8List result = Uint8List(header.length + 4);
    result.setRange(0, header.length, header);
    ByteData.sublistView(result).setUint32(header.length, chunkIndex);
    return result;
  }

  int _chunkCount(int clearTextLength, int chunkSize) {
    if (clearTextLength < 0) {
      throw const FormatException('Invalid clear text length.');
    }
    return clearTextLength == 0
        ? 1
        : (clearTextLength + chunkSize - 1) ~/ chunkSize;
  }

  int _clearChunkLength({
    required int index,
    required int chunkCount,
    required int clearTextLength,
    required int chunkSize,
  }) {
    if (clearTextLength == 0) {
      return 0;
    }
    if (index < chunkCount - 1) {
      return chunkSize;
    }
    return clearTextLength - (index * chunkSize);
  }

  void _validateChunkSize(int chunkSize) {
    if (chunkSize <= 0 || chunkSize > _maximumChunkSize) {
      throw const FormatException('Invalid encrypted file chunk size.');
    }
  }

  void _validateChunkCount(int chunkCount) {
    if (chunkCount <= 0 || chunkCount > 0x100000000) {
      throw const FormatException('Encrypted file is too large.');
    }
  }

  Future<Uint8List> _readExact(RandomAccessFile file, int length) async {
    final Uint8List result = Uint8List(length);
    int offset = 0;
    while (offset < length) {
      final Uint8List bytes = await file.read(length - offset);
      if (bytes.isEmpty) {
        throw const FormatException('Unexpected end of encrypted file.');
      }
      result.setRange(offset, offset + bytes.length, bytes);
      offset += bytes.length;
    }
    return result;
  }

  Future<void> _replaceFile(File temporaryFile, File outputFile) async {
    if (await outputFile.exists()) {
      await outputFile.delete();
    }
    await temporaryFile.rename(outputFile.path);
  }

  File _temporaryFileFor(File outputFile) {
    final String suffix = _randomBytes(
      8,
    ).map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
    return File('${outputFile.path}.tmp-$suffix');
  }

  Uint8List _randomBytes(int length) {
    final SecretKeyData randomData = SecretKeyData.random(
      length: length,
      random: random,
    );
    try {
      return Uint8List.fromList(randomData.bytes);
    } finally {
      randomData.destroy();
    }
  }

  List<int> get _bytesAssociatedData {
    return utf8.encode('veyra.content.bytes.v1');
  }
}

final class _FileHeader {
  const _FileHeader({
    required this.fileNonce,
    required this.clearTextLength,
    required this.chunkSize,
  });

  final Uint8List fileNonce;
  final int clearTextLength;
  final int chunkSize;
}
