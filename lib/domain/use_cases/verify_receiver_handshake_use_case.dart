import 'dart:convert';
import 'dart:typed_data';

import '../../core/protocol/receiver_handshake_codec.dart';
import '../entities/receiver_handshake.dart';
import '../repositories/device_identity_repository.dart';

class VerifyReceiverHandshakeUseCase {
  const VerifyReceiverHandshakeUseCase({
  required DeviceIdentityRepository identityRepository,
  required ReceiverHandshakeCodec codec,
  String expectedAppId = defaultAppId,
})  : _identityRepository = identityRepository,
      _codec = codec,
      _expectedAppId = expectedAppId;

  static const int _protocolVersion = 1;

  static const int _nonceSizeBytes = 32;

  static const Duration _maximumHandshakeAge = Duration(minutes: 2);

  static const Duration _allowedFutureDifference = Duration(seconds: 30);

  final DeviceIdentityRepository _identityRepository;

  final ReceiverHandshakeCodec _codec;

  static const String defaultAppId = 'SECURE_TRANSFER_POC_KOTLIN';

  final String _expectedAppId;

  Future<ReceiverHandshake> call({
    required String handshakeJson,
    required String expectedSessionId,
  }) async {
    final ReceiverHandshake handshake;

    try {
      handshake = _codec.decode(handshakeJson);
    } on Object {
      throw const FormatException('El handshake no contiene un JSON válido');
    }

    if (handshake.protocolVersion != _protocolVersion) {
      throw const FormatException('Versión de handshake no soportada');
    }

    if (handshake.sessionId != expectedSessionId) {
      throw const FormatException('El handshake pertenece a otra sesión');
    }

    if (handshake.receiverApp != _expectedAppId) {
      throw const FormatException(
        'El handshake pertenece a otra aplicación',
      );
    }

    final now = DateTime.now().millisecondsSinceEpoch;

    final minimumTimestamp = now - _maximumHandshakeAge.inMilliseconds;

    final maximumTimestamp = now + _allowedFutureDifference.inMilliseconds;

    if (handshake.createdAtEpochMillis < minimumTimestamp ||
        handshake.createdAtEpochMillis > maximumTimestamp) {
      throw const FormatException(
        'El handshake expiró o tiene una fecha futura',
      );
    }

    if (handshake.nonce.trim().isEmpty ||
        handshake.identityPublicKey.trim().isEmpty ||
        handshake.ephemeralPublicKey.trim().isEmpty ||
        handshake.signature.trim().isEmpty) {
      throw const FormatException('El handshake contiene campos vacíos');
    }

    final nonce = _decodeBase64Url(handshake.nonce);

    if (nonce.length != _nonceSizeBytes) {
      throw const FormatException('El nonce del receptor es inválido');
    }

    final signature = _decodeBase64Url(handshake.signature);

    final signatureIsValid = await _identityRepository.verify(
      data: handshake.signingBytes(),
      signature: signature,
      publicKey: handshake.identityPublicKey,
    );

    if (!signatureIsValid) {
      throw const FormatException('La firma del receptor es inválida');
    }

    return handshake;
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
}
