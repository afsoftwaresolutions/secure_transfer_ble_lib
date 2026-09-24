import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:secure_transfer_poc_flutter/data/local/identity_key_store.dart';
import 'package:secure_transfer_poc_flutter/data/repositories/pointy_castle_device_identity_repository.dart';

void main() {
  group('PointyCastleDeviceIdentityRepository', () {
    test('crea una identidad y después reutiliza la misma', () async {
      final keyStore = _MemoryIdentityKeyStore();

      final repository = PointyCastleDeviceIdentityRepository(
        keyStore: keyStore,
      );

      final firstIdentity = await repository.getOrCreateIdentity();

      final secondIdentity = await repository.getOrCreateIdentity();

      expect(firstIdentity.wasCreated, isTrue);
      expect(secondIdentity.wasCreated, isFalse);

      expect(secondIdentity.publicKey, firstIdentity.publicKey);

      expect(keyStore.value, isNotNull);
    });

    test('recupera la misma identidad en otra instancia', () async {
      final keyStore = _MemoryIdentityKeyStore();

      final firstRepository = PointyCastleDeviceIdentityRepository(
        keyStore: keyStore,
      );

      final firstIdentity = await firstRepository.getOrCreateIdentity();

      final secondRepository = PointyCastleDeviceIdentityRepository(
        keyStore: keyStore,
      );

      final recoveredIdentity = await secondRepository.getOrCreateIdentity();

      expect(recoveredIdentity.wasCreated, isFalse);

      expect(recoveredIdentity.publicKey, firstIdentity.publicKey);
    });

    test('firma y verifica correctamente', () async {
      final repository = PointyCastleDeviceIdentityRepository(
        keyStore: _MemoryIdentityKeyStore(),
      );

      final identity = await repository.getOrCreateIdentity();

      final message = utf8.encode('IR_TRANSFER_V1|mensaje de prueba');

      final signature = await repository.sign(message);

      expect(signature.first, 0x30);

      final isValid = await repository.verify(
        data: message,
        signature: signature,
        publicKey: identity.publicKey,
      );

      expect(isValid, isTrue);
    });

    test('rechaza la firma cuando cambian los datos', () async {
      final repository = PointyCastleDeviceIdentityRepository(
        keyStore: _MemoryIdentityKeyStore(),
      );

      final identity = await repository.getOrCreateIdentity();

      final originalMessage = utf8.encode('mensaje original');

      final signature = await repository.sign(originalMessage);

      final isValid = await repository.verify(
        data: utf8.encode('mensaje modificado'),
        signature: signature,
        publicKey: identity.publicKey,
      );

      expect(isValid, isFalse);
    });
  });
}

class _MemoryIdentityKeyStore implements IdentityKeyStore {
  String? value;

  @override
  Future<String?> read() async {
    return value;
  }

  @override
  Future<void> write(String value) async {
    this.value = value;
  }
}
