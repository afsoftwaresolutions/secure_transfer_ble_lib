import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

import '../../core/crypto/hkdf_sha256.dart';
import '../../core/crypto/p256_interop_codec.dart';
import '../../domain/entities/key_agreement_result.dart';
import '../../domain/repositories/session_invitation_repository.dart';
import '../../domain/repositories/session_key_repository.dart';

import '../../domain/entities/encrypted_transfer_envelope.dart';

class PointyCastleSessionKeyRepository implements SessionKeyRepository {
  PointyCastleSessionKeyRepository({
    required this._sessionInvitationRepository,
  });

  static const int _coordinateLength = 32;

  static const int _protocolVersion = 1;
  static const int _aesGcmIvSizeBytes = 12;
  static const int _aesGcmTagSizeBits = 128;

  final SessionInvitationRepository _sessionInvitationRepository;

  final ECDomainParameters _domain = ECDomainParameters('prime256v1');

  final Random _secureRandom = Random.secure();

  final Map<String, Uint8List> _sessionKeys = <String, Uint8List>{};

  @override
  Future<ReceiverKeyAgreementResult> prepareReceiverSession({
    required String sessionId,
    required String senderEphemeralPublicKey,
  }) async {
    if (sessionId.isEmpty) {
      throw ArgumentError('El sessionId está vacío');
    }

    if (senderEphemeralPublicKey.isEmpty) {
      throw ArgumentError('La clave ECDH del emisor está vacía');
    }

    final receiverKeyPair = _generateEphemeralKeyPair();

    final sharedSecret = _calculateSharedSecret(
      ownPrivateValue: receiverKeyPair.privateValue,
      peerPublicKey: senderEphemeralPublicKey,
    );

    final sessionKey = _deriveSessionKey(
      sharedSecret: sharedSecret,
      sessionId: sessionId,
    );

    _saveSessionKey(sessionId: sessionId, sessionKey: sessionKey);

    final receiverPublicKey = P256InteropCodec.encodePublicKeyBase64Url(
      x: receiverKeyPair.x,
      y: receiverKeyPair.y,
    );

    final fingerprint = _encodeBase64Url(_sha256(sessionKey));

    _clear(sharedSecret);
    _clear(sessionKey);

    return ReceiverKeyAgreementResult(
      sessionId: sessionId,
      receiverEphemeralPublicKey: receiverPublicKey,
      sessionKeyFingerprint: fingerprint,
    );
  }

  @override
  Future<SenderKeyAgreementResult> completeSenderSession({
    required String sessionId,
    required String receiverEphemeralPublicKey,
  }) async {
    if (sessionId.isEmpty) {
      throw ArgumentError('El sessionId está vacío');
    }

    final sharedSecret = Uint8List.fromList(
      await _sessionInvitationRepository.calculateSenderSharedSecret(
        sessionId: sessionId,
        receiverEphemeralPublicKey: receiverEphemeralPublicKey,
      ),
    );

    final sessionKey = _deriveSessionKey(
      sharedSecret: sharedSecret,
      sessionId: sessionId,
    );

    _saveSessionKey(sessionId: sessionId, sessionKey: sessionKey);

    final fingerprint = _encodeBase64Url(_sha256(sessionKey));

    _clear(sharedSecret);
    _clear(sessionKey);

    return SenderKeyAgreementResult(
      sessionId: sessionId,
      sessionKeyFingerprint: fingerprint,
    );
  }

  @override
  Future<EncryptedTransferEnvelope> encryptSessionMessage({
    required String sessionId,
    required String messageId,
    required String plainText,
    SessionMessagePurpose purpose = SessionMessagePurpose.legacy,
  }) async {
    if (sessionId.trim().isEmpty) {
      throw ArgumentError('El sessionId está vacío');
    }

    if (messageId.trim().isEmpty) {
      throw ArgumentError('El messageId está vacío');
    }

    if (plainText.trim().isEmpty) {
      throw ArgumentError('El mensaje que se desea cifrar está vacío');
    }

    final storedSessionKey = _sessionKeys[sessionId];

    if (storedSessionKey == null) {
      throw StateError(
        'No existe una clave AES para '
        'la sesión $sessionId',
      );
    }

    final sessionKey = Uint8List.fromList(storedSessionKey);

    try {
      final iv = _generateSecureBytes(_aesGcmIvSizeBytes);

      final associatedData = _createAssociatedData(
        sessionId: sessionId,
        messageId: messageId,
        purpose: purpose
      );

      final encryptedBytes = _processAesGcm(
        encrypting: true,
        input: utf8.encode(plainText),
        sessionKey: sessionKey,
        iv: iv,
        associatedData: associatedData,
      );

      return EncryptedTransferEnvelope(
        protocolVersion: _protocolVersion,
        sessionId: sessionId,
        messageId: messageId,
        iv: _encodeBase64Url(iv),
        cipherText: _encodeBase64Url(encryptedBytes),
      );
    } finally {
      _clear(sessionKey);
    }
  }

  @override
  Future<String> decryptSessionMessage(
    EncryptedTransferEnvelope envelope, {
    SessionMessagePurpose purpose = SessionMessagePurpose.legacy,
  }) async {
    if (envelope.protocolVersion != _protocolVersion) {
      throw FormatException(
        'Versión de protocolo no soportada: '
        '${envelope.protocolVersion}',
      );
    }

    if (envelope.sessionId.trim().isEmpty) {
      throw const FormatException('El sessionId está vacío');
    }

    if (envelope.messageId.trim().isEmpty) {
      throw const FormatException('El messageId está vacío');
    }

    final storedSessionKey = _sessionKeys[envelope.sessionId];

    if (storedSessionKey == null) {
      throw StateError(
        'No existe una clave AES para '
        'la sesión ${envelope.sessionId}',
      );
    }

    final sessionKey = Uint8List.fromList(storedSessionKey);

    try {
      final iv = _decodeBase64Url(envelope.iv);

      if (iv.length != _aesGcmIvSizeBytes) {
        throw const FormatException('El IV de AES-GCM no tiene 12 bytes');
      }

      final encryptedBytes = _decodeBase64Url(envelope.cipherText);

      if (encryptedBytes.isEmpty) {
        throw const FormatException('El contenido cifrado está vacío');
      }

      final associatedData = _createAssociatedData(
        sessionId: envelope.sessionId,
        messageId: envelope.messageId,
        purpose: purpose
      );

      final decryptedBytes = _processAesGcm(
        encrypting: false,
        input: encryptedBytes,
        sessionKey: sessionKey,
        iv: iv,
        associatedData: associatedData,
      );

      return utf8.decode(decryptedBytes);
    } finally {
      _clear(sessionKey);
    }
  }

  @override
  bool hasSessionKey(String sessionId) {
    return _sessionKeys.containsKey(sessionId);
  }

  @override
  void removeSession(String sessionId) {
    final removed = _sessionKeys.remove(sessionId);

    if (removed != null) {
      _clear(removed);
    }
  }

  Uint8List _calculateSharedSecret({
    required BigInt ownPrivateValue,
    required String peerPublicKey,
  }) {
    final coordinates = P256InteropCodec.decodePublicKeyBase64Url(
      peerPublicKey,
    );

    final peerPoint = _domain.curve.createPoint(
      _bytesToBigInt(coordinates.x),
      _bytesToBigInt(coordinates.y),
    );

    final privateKey = ECPrivateKey(ownPrivateValue, _domain);

    final publicKey = ECPublicKey(peerPoint, _domain);

    final agreement = ECDHBasicAgreement();

    // PointyCastle espera directamente ECPrivateKey.
    agreement.init(privateKey);

    final sharedSecret = agreement.calculateAgreement(publicKey);

    return _bigIntToFixedBytes(sharedSecret, _coordinateLength);
  }

  Uint8List _deriveSessionKey({
    required List<int> sharedSecret,
    required String sessionId,
  }) {
    final salt = _sha256(utf8.encode('IR_TRANSFER_V1|$sessionId'));

    final info = utf8.encode('IR_TRANSFER_V1|AES_256_GCM|$sessionId');

    final sessionKey = HkdfSha256.deriveKey(
      inputKeyMaterial: sharedSecret,
      salt: salt,
      info: info,
    );

    _clear(salt);

    return sessionKey;
  }

  _GeneratedEphemeralKeyPair _generateEphemeralKeyPair() {
    final random = FortunaRandom();

    random.seed(KeyParameter(_generateSecureBytes(32)));

    final generator = ECKeyGenerator();

    generator.init(
      ParametersWithRandom(ECKeyGeneratorParameters(_domain), random),
    );

    final keyPair = generator.generateKeyPair();

    final privateValue = keyPair.privateKey.d;
    final publicPoint = keyPair.publicKey.Q;

    if (privateValue == null || publicPoint == null) {
      throw StateError('No fue posible generar la clave ECDH temporal');
    }

    final x = publicPoint.x?.toBigInteger();
    final y = publicPoint.y?.toBigInteger();

    if (x == null || y == null) {
      throw StateError('La clave ECDH no contiene coordenadas');
    }

    return _GeneratedEphemeralKeyPair(
      privateValue: privateValue,
      x: _bigIntToFixedBytes(x, _coordinateLength),
      y: _bigIntToFixedBytes(y, _coordinateLength),
    );
  }

  Uint8List _generateSecureBytes(int length) {
    return Uint8List.fromList(
      List<int>.generate(length, (_) => _secureRandom.nextInt(256)),
    );
  }

  Uint8List _sha256(List<int> value) {
    return SHA256Digest().process(Uint8List.fromList(value));
  }

  void _saveSessionKey({
    required String sessionId,
    required List<int> sessionKey,
  }) {
    final previousKey = _sessionKeys[sessionId];

    _sessionKeys[sessionId] = Uint8List.fromList(sessionKey);

    if (previousKey != null) {
      _clear(previousKey);
    }
  }

  String _encodeBase64Url(List<int> value) {
    return base64Url.encode(value).replaceAll('=', '');
  }

  void _clear(Uint8List bytes) {
    bytes.fillRange(0, bytes.length, 0);
  }

  static BigInt _bytesToBigInt(List<int> bytes) {
    var result = BigInt.zero;

    for (final byte in bytes) {
      result = (result << 8) | BigInt.from(byte);
    }

    return result;
  }

  static Uint8List _bigIntToFixedBytes(BigInt value, int length) {
    final output = Uint8List(length);
    var remaining = value;

    for (var index = length - 1; index >= 0; index--) {
      output[index] = (remaining & BigInt.from(0xFF)).toInt();

      remaining >>= 8;
    }

    if (remaining != BigInt.zero) {
      throw const FormatException('El número no cabe en la longitud esperada');
    }

    return output;
  }

  Uint8List _createAssociatedData({
    required String sessionId,
    required String messageId,
    required SessionMessagePurpose purpose,
  }) {
    final base = 'IR_TRANSFER_V1|$sessionId|$messageId';

    final value = switch (purpose) {
      SessionMessagePurpose.legacy => base,
      SessionMessagePurpose.reverseData => '$base|REVERSE_DATA',
      SessionMessagePurpose.reverseAck => '$base|REVERSE_ACK',
    };

    return Uint8List.fromList(utf8.encode(value));
  }

  Uint8List _processAesGcm({
    required bool encrypting,
    required List<int> input,
    required List<int> sessionKey,
    required List<int> iv,
    required List<int> associatedData,
  }) {
    final cipher = GCMBlockCipher(AESEngine());

    cipher.init(
      encrypting,
      AEADParameters(
        KeyParameter(Uint8List.fromList(sessionKey)),
        _aesGcmTagSizeBits,
        Uint8List.fromList(iv),
        Uint8List.fromList(associatedData),
      ),
    );

    final inputBytes = Uint8List.fromList(input);

    final output = Uint8List(cipher.getOutputSize(inputBytes.length));

    var outputLength = cipher.processBytes(
      inputBytes,
      0,
      inputBytes.length,
      output,
      0,
    );

    outputLength += cipher.doFinal(output, outputLength);

    return Uint8List.fromList(output.sublist(0, outputLength));
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

class _GeneratedEphemeralKeyPair {
  _GeneratedEphemeralKeyPair({
    required this.privateValue,
    required this.x,
    required this.y,
  });

  final BigInt privateValue;
  final Uint8List x;
  final Uint8List y;
}
