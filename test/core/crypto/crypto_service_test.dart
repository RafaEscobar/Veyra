import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:veyra/core/crypto/crypto_service.dart';
import 'package:veyra/core/errors/app_exception.dart';
import 'package:veyra/core/security/encrypted_value.dart';

void main() {
  group('key generation and derivation', () {
    test('generates independent master keys and salts', () async {
      final CryptoService service = CryptoService();
      final SecretKeyData firstKey = await service.generateMasterKey();
      final SecretKeyData secondKey = await service.generateMasterKey();
      final Uint8List firstSalt = service.generateSalt();
      final Uint8List secondSalt = service.generateSalt();

      try {
        expect(firstKey.bytes, hasLength(CryptoService.masterKeyLength));
        expect(secondKey.bytes, hasLength(CryptoService.masterKeyLength));
        expect(firstKey.bytes, isNot(orderedEquals(secondKey.bytes)));
        expect(firstSalt, hasLength(CryptoService.saltLength));
        expect(firstSalt, isNot(orderedEquals(secondSalt)));
      } finally {
        firstKey.destroy();
        secondKey.destroy();
        firstSalt.fillRange(0, firstSalt.length, 0);
        secondSalt.fillRange(0, secondSalt.length, 0);
      }
    });

    test('matches a deterministic PBKDF2-HMAC-SHA256 vector', () async {
      final CryptoService service = CryptoService(kdfIterations: 1);
      final Uint8List salt = Uint8List.fromList(
        List<int>.generate(16, (index) => index),
      );
      final SecretKey key = await service.deriveRecoveryKey(
        normalizedRecoveryAnswer: 'password',
        salt: salt,
      );

      try {
        final SecretKeyData extracted = await key.extract();
        expect(
          _hex(extracted.bytes),
          'e1b08f92be8174d9f442d95d89aa4ccdc311231a4d70d0b854d1548de8fabdfd',
        );
      } finally {
        key.destroy();
      }
    });
  });

  group('authenticated bytes', () {
    final CryptoService service = CryptoService(random: Random(7));
    final SecretKeyData key = SecretKeyData(Uint8List(32));

    tearDownAll(key.destroy);

    test('encrypts and decrypts bytes with a fresh nonce', () async {
      final Uint8List clearText = Uint8List.fromList(
        utf8.encode('contenido privado'),
      );

      final EncryptedValue first = await service.encryptBytes(
        clearText: clearText,
        secretKey: key,
      );
      final EncryptedValue second = await service.encryptBytes(
        clearText: clearText,
        secretKey: key,
      );
      final Uint8List decrypted = await service.decryptBytes(
        encryptedValue: first,
        secretKey: key,
      );

      expect(decrypted, orderedEquals(clearText));
      expect(first.nonce, isNot(second.nonce));
      expect(first.cipherText, isNot(second.cipherText));
    });

    test('rejects manipulated bytes', () async {
      final EncryptedValue encrypted = await service.encryptBytes(
        clearText: utf8.encode('secreto'),
        secretKey: key,
      );
      final Uint8List manipulatedCipherText = Uint8List.fromList(
        base64Decode(encrypted.cipherText),
      );
      manipulatedCipherText[0] ^= 0x01;
      final EncryptedValue manipulated = EncryptedValue(
        cipherText: base64Encode(manipulatedCipherText),
        nonce: encrypted.nonce,
        mac: encrypted.mac,
      );

      await expectLater(
        service.decryptBytes(encryptedValue: manipulated, secretKey: key),
        throwsA(isA<VaultFileCorruptedException>()),
      );
    });

    test('rejects an incorrect key', () async {
      final EncryptedValue encrypted = await service.encryptBytes(
        clearText: utf8.encode('secreto'),
        secretKey: key,
      );
      final SecretKeyData wrongKey = SecretKeyData(
        Uint8List.fromList(List<int>.filled(32, 1)),
      );

      try {
        await expectLater(
          service.decryptBytes(encryptedValue: encrypted, secretKey: wrongKey),
          throwsA(isA<VaultFileCorruptedException>()),
        );
      } finally {
        wrongKey.destroy();
      }
    });
  });

  group('authenticated files', () {
    late Directory directory;
    late CryptoService service;
    late SecretKeyData key;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('veyra-crypto-test-');
      service = CryptoService(fileChunkSize: 4096, random: Random(19));
      key = SecretKeyData(
        Uint8List.fromList(List<int>.generate(32, (index) => index)),
      );
    });

    tearDown(() async {
      key.destroy();
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    test('encrypts large files in chunks and uses a unique nonce', () async {
      final Uint8List clearText = Uint8List.fromList(
        List<int>.generate(150000, (index) => index % 251),
      );
      final File input = File('${directory.path}/input.bin');
      final File firstEncrypted = File('${directory.path}/first.dat');
      final File secondEncrypted = File('${directory.path}/second.dat');
      final File decrypted = File('${directory.path}/decrypted.bin');
      await input.writeAsBytes(clearText, flush: true);

      await service.encryptFile(
        inputFile: input,
        outputFile: firstEncrypted,
        secretKey: key,
      );
      await service.encryptFile(
        inputFile: input,
        outputFile: secondEncrypted,
        secretKey: key,
      );
      await service.decryptFile(
        inputFile: firstEncrypted,
        outputFile: decrypted,
        secretKey: key,
      );

      expect(await decrypted.readAsBytes(), orderedEquals(clearText));
      expect(
        await firstEncrypted.readAsBytes(),
        isNot(orderedEquals(await secondEncrypted.readAsBytes())),
      );
    });

    test('round trips an empty file with authenticated content', () async {
      final File input = File('${directory.path}/empty.bin');
      final File encrypted = File('${directory.path}/empty.dat');
      final File decrypted = File('${directory.path}/empty-out.bin');
      await input.writeAsBytes(<int>[]);

      await service.encryptFile(
        inputFile: input,
        outputFile: encrypted,
        secretKey: key,
      );
      await service.decryptFile(
        inputFile: encrypted,
        outputFile: decrypted,
        secretKey: key,
      );

      expect(await decrypted.length(), 0);
    });

    test(
      'rejects a manipulated file without replacing the destination',
      () async {
        final File input = File('${directory.path}/input.bin');
        final File encrypted = File('${directory.path}/encrypted.dat');
        final File output = File('${directory.path}/output.bin');
        await input.writeAsBytes(
          List<int>.generate(10000, (index) => index % 255),
        );
        await output.writeAsString('contenido existente');
        await service.encryptFile(
          inputFile: input,
          outputFile: encrypted,
          secretKey: key,
        );
        final Uint8List manipulated = await encrypted.readAsBytes();
        manipulated[manipulated.length ~/ 2] ^= 0x80;
        await encrypted.writeAsBytes(manipulated, flush: true);

        await expectLater(
          service.decryptFile(
            inputFile: encrypted,
            outputFile: output,
            secretKey: key,
          ),
          throwsA(isA<InvalidEncryptedFileException>()),
        );
        expect(await output.readAsString(), 'contenido existente');
        expect(
          directory.listSync().where((entry) => entry.path.contains('.tmp-')),
          isEmpty,
        );
      },
    );

    test('rejects a truncated file and an incorrect key', () async {
      final File input = File('${directory.path}/input.bin');
      final File encrypted = File('${directory.path}/encrypted.dat');
      final File truncated = File('${directory.path}/truncated.dat');
      await input.writeAsBytes(
        List<int>.generate(5000, (index) => index % 255),
      );
      await service.encryptFile(
        inputFile: input,
        outputFile: encrypted,
        secretKey: key,
      );
      final Uint8List encryptedBytes = await encrypted.readAsBytes();
      await truncated.writeAsBytes(
        encryptedBytes.sublist(0, encryptedBytes.length - 1),
      );

      await expectLater(
        service.decryptFile(
          inputFile: truncated,
          outputFile: File('${directory.path}/truncated-output.bin'),
          secretKey: key,
        ),
        throwsA(isA<InvalidEncryptedFileException>()),
      );

      final SecretKeyData wrongKey = SecretKeyData(
        Uint8List.fromList(List<int>.filled(32, 7)),
      );
      try {
        await expectLater(
          service.decryptFile(
            inputFile: encrypted,
            outputFile: File('${directory.path}/wrong-key-output.bin'),
            secretKey: wrongKey,
          ),
          throwsA(isA<InvalidEncryptedFileException>()),
        );
      } finally {
        wrongKey.destroy();
      }
    });
  });
}

String _hex(List<int> bytes) {
  return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
}
