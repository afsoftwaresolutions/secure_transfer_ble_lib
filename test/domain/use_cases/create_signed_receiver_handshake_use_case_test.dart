import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:secure_transfer_poc_flutter/core/protocol/receiver_handshake_codec.dart';
import 'package:secure_transfer_poc_flutter/data/local/identity_key_store.dart';
import 'package:secure_transfer_poc_flutter/data/repositories/pointy_castle_device_identity_repository.dart';
import 'package:secure_transfer_poc_flutter/domain/use_cases/create_signed_receiver_handshake_use_case.dart';

import 'package:secure_transfer_poc_flutter/domain/use_cases/verify_receiver_handshake_use_case.dart';

void main() {
  test('crea un handshake firmado verificable', () async {
    final identityRepository = PointyCastleDeviceIdentityRepository(
      keyStore: _MemoryIdentityKeyStore(),
    );

    const codec = ReceiverHandshakeCodec();

    final useCase = CreateSignedReceiverHandshakeUseCase(
      identityRepository: identityRepository,
      codec: codec,
      currentTimeMillis: () => 1_700_000_000_000,
    );

    final result = await useCase(
      sessionId: '11111111-2222-3333-4444-555555555555',
      receiverEphemeralPublicKey: 'CLAVE_PUBLICA_ECDH_PRUEBA',
    );

    final decoded = codec.decode(result.handshakeJson);

    final signatureBytes = _decodeBase64Url(decoded.signature);

    final signatureIsValid = await identityRepository.verify(
      data: decoded.signingBytes(),
      signature: signatureBytes,
      publicKey: decoded.identityPublicKey,
    );

    expect(signatureIsValid, isTrue);

    expect(decoded.sessionId, '11111111-2222-3333-4444-555555555555');

    expect(decoded.ephemeralPublicKey, 'CLAVE_PUBLICA_ECDH_PRUEBA');

    expect(decoded.nonce, isNotEmpty);
  });

  test('rechaza un handshake de otra aplicación', () async {
    final identityRepository = PointyCastleDeviceIdentityRepository(
      keyStore: _MemoryIdentityKeyStore(),
    );
    const codec = ReceiverHandshakeCodec();
    const sessionId = '11111111-2222-3333-4444-555555555555';

    final creator = CreateSignedReceiverHandshakeUseCase(
      identityRepository: identityRepository,
      codec: codec,
      appId: 'INTERAPP',
    );

    final result = await creator(
      sessionId: sessionId,
      receiverEphemeralPublicKey: 'CLAVE_PUBLICA_ECDH_PRUEBA',
    );

    final verifierInterapp = VerifyReceiverHandshakeUseCase(
      identityRepository: identityRepository,
      codec: codec,
      expectedAppId: 'INTERAPP',
    );

    final verifierAppController = VerifyReceiverHandshakeUseCase(
      identityRepository: identityRepository,
      codec: codec,
      expectedAppId: 'APP_CONTROLLER',
    );

    expect(
      (await verifierInterapp(
        handshakeJson: result.handshakeJson,
        expectedSessionId: sessionId,
      )).receiverApp,
      'INTERAPP',
    );

    await expectLater(
      verifierAppController(
        handshakeJson: result.handshakeJson,
        expectedSessionId: sessionId,
      ),
      throwsA(isA<FormatException>()),
    );
  });
}

Uint8List _decodeBase64Url(String value) {
  final remainder = value.length % 4;

  final normalized = switch (remainder) {
    0 => value,
    2 => '$value==',
    3 => '$value=',
    _ => throw const FormatException('Base64 URL-safe inválido'),
  };

  return Uint8List.fromList(base64Url.decode(normalized));
}

class _MemoryIdentityKeyStore implements IdentityKeyStore {
  String? _value;

  @override
  Future<String?> read() async {
    return _value;
  }

  @override
  Future<void> write(String value) async {
    _value = value;
  }
}
