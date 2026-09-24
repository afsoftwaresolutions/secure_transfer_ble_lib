import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import '../../core/protocol/receiver_handshake_codec.dart';
import '../entities/receiver_handshake.dart';
import '../entities/signed_receiver_handshake_result.dart';
import '../repositories/device_identity_repository.dart';

class CreateSignedReceiverHandshakeUseCase {
  CreateSignedReceiverHandshakeUseCase({
    required this._identityRepository,
    required this._codec,
    String appId = defaultAppId,
    int Function()? currentTimeMillis,
    Random? secureRandom,
  }) : _appId = appId,
       _currentTimeMillis =
           currentTimeMillis ?? (() => DateTime.now().millisecondsSinceEpoch),
       _secureRandom = secureRandom ?? Random.secure();

  static const int _protocolVersion = 1;

  // Temporalmente coincide con Kotlin.
  static const String defaultAppId = 'SECURE_TRANSFER_POC_KOTLIN';

  final String _appId;

  static const int _nonceLength = 32;

  final DeviceIdentityRepository _identityRepository;

  final ReceiverHandshakeCodec _codec;

  final int Function() _currentTimeMillis;

  final Random _secureRandom;

  Future<SignedReceiverHandshakeResult> call({
    required String sessionId,
    required String receiverEphemeralPublicKey,
  }) async {
    if (sessionId.isEmpty) {
      throw ArgumentError('El sessionId está vacío');
    }

    if (receiverEphemeralPublicKey.isEmpty) {
      throw ArgumentError('La clave ECDH del receptor está vacía');
    }

    final identity = await _identityRepository.getOrCreateIdentity();

    final unsignedHandshake = ReceiverHandshake(
      protocolVersion: _protocolVersion,
      sessionId: sessionId,
      receiverApp: _appId,
      createdAtEpochMillis: _currentTimeMillis(),
      nonce: _encodeBase64Url(_generateSecureBytes(_nonceLength)),
      identityPublicKey: identity.publicKey,
      ephemeralPublicKey: receiverEphemeralPublicKey,
      signature: '',
    );

    final signature = await _identityRepository.sign(
      unsignedHandshake.signingBytes(),
    );

    final signedHandshake = unsignedHandshake.copyWith(
      signature: _encodeBase64Url(signature),
    );

    return SignedReceiverHandshakeResult(
      handshake: signedHandshake,
      handshakeJson: _codec.encode(signedHandshake),
    );
  }

  Uint8List _generateSecureBytes(int length) {
    return Uint8List.fromList(
      List<int>.generate(length, (_) => _secureRandom.nextInt(256)),
    );
  }

  String _encodeBase64Url(List<int> bytes) {
    return base64Url.encode(bytes).replaceAll('=', '');
  }
}
