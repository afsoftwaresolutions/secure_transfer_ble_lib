import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';
import 'package:uuid/uuid.dart';

import '../../core/crypto/p256_interop_codec.dart';
import '../../domain/entities/session_invitation.dart';
import '../../domain/repositories/device_identity_repository.dart';
import '../../domain/repositories/session_invitation_repository.dart';

class PointyCastleSessionInvitationRepository
    implements SessionInvitationRepository {
  PointyCastleSessionInvitationRepository({
    required this._identityRepository,
    String appId = defaultAppId,
    Uuid? uuid,
    int Function()? currentTimeMillis,
  }) : _appId = appId,
       _uuid = uuid ?? Uuid(),
       _currentTimeMillis =
           currentTimeMillis ?? (() => DateTime.now().millisecondsSinceEpoch);

  static const int _protocolVersion = 1;

  /// Por ahora debe coincidir exactamente con Kotlin porque
  /// AndroidSessionInvitationRepository valida este valor.
  static const String defaultAppId = 'SECURE_TRANSFER_POC_KOTLIN';
  final String _appId;

  static const int _sessionDurationMillis = 2 * 60 * 1000;

  static const int _allowedClockDifferenceMillis = 30 * 1000;

  static const int _nonceLength = 32;
  static const int _coordinateLength = 32;

  final DeviceIdentityRepository _identityRepository;
  final Uuid _uuid;
  final int Function() _currentTimeMillis;

  final ECDomainParameters _domain = ECDomainParameters('prime256v1');

  final Random _secureRandom = Random.secure();

  /// Las claves privadas ECDH temporales permanecen
  /// solamente en memoria.
  final Map<String, _EphemeralSession> _activeSessions =
      <String, _EphemeralSession>{};

  @override
  Future<SessionInvitation> createSenderInvitation() async {
    _removeExpiredSessions();

    final identity = await _identityRepository.getOrCreateIdentity();

    final ephemeralKeyPair = _generateEphemeralKeyPair();

    final sessionId = _uuid.v4();
    final now = _currentTimeMillis();
    final expiresAt = now + _sessionDurationMillis;

    final identityPublicKeyBytes = _decodeBase64Url(identity.publicKey);

    final unsignedInvitation = SessionInvitation(
      protocolVersion: _protocolVersion,
      sessionId: sessionId,
      sourceApp: _appId,
      sourceDeviceId: _createDeviceId(identityPublicKeyBytes),
      createdAtEpochMillis: now,
      expiresAtEpochMillis: expiresAt,
      nonce: _encodeBase64Url(_generateSecureBytes(_nonceLength)),
      identityPublicKey: identity.publicKey,
      ephemeralPublicKey: P256InteropCodec.encodePublicKeyBase64Url(
        x: ephemeralKeyPair.x,
        y: ephemeralKeyPair.y,
      ),
      signature: '',
    );

    final signature = await _identityRepository.sign(
      unsignedInvitation.signingBytes(),
    );

    final signedInvitation = SessionInvitation(
      protocolVersion: unsignedInvitation.protocolVersion,
      sessionId: unsignedInvitation.sessionId,
      sourceApp: unsignedInvitation.sourceApp,
      sourceDeviceId: unsignedInvitation.sourceDeviceId,
      createdAtEpochMillis: unsignedInvitation.createdAtEpochMillis,
      expiresAtEpochMillis: unsignedInvitation.expiresAtEpochMillis,
      nonce: unsignedInvitation.nonce,
      identityPublicKey: unsignedInvitation.identityPublicKey,
      ephemeralPublicKey: unsignedInvitation.ephemeralPublicKey,
      signature: _encodeBase64Url(signature),
    );

    _activeSessions[sessionId] = _EphemeralSession(
      privateValue: ephemeralKeyPair.privateValue,
      expiresAtEpochMillis: expiresAt,
    );

    return signedInvitation;
  }

  @override
  Future<bool> verifyInvitation(SessionInvitation invitation) async {
    final now = _currentTimeMillis();

    final protocolIsValid = invitation.protocolVersion == _protocolVersion;

    final sourceAppIsValid = invitation.sourceApp == _appId;

    final expirationIsValid = invitation.expiresAtEpochMillis > now;

    final creationTimeIsValid =
        invitation.createdAtEpochMillis <= now + _allowedClockDifferenceMillis;

    final duration =
        invitation.expiresAtEpochMillis - invitation.createdAtEpochMillis;

    final durationIsValid = duration > 0 && duration <= _sessionDurationMillis;

    final requiredValuesExist =
        invitation.sessionId.isNotEmpty &&
        invitation.sourceDeviceId.isNotEmpty &&
        invitation.nonce.isNotEmpty &&
        invitation.identityPublicKey.isNotEmpty &&
        invitation.ephemeralPublicKey.isNotEmpty &&
        invitation.signature.isNotEmpty;

    if (!protocolIsValid ||
        !sourceAppIsValid ||
        !expirationIsValid ||
        !creationTimeIsValid ||
        !durationIsValid ||
        !requiredValuesExist) {
      return false;
    }

    try {
      // También validamos que la clave temporal recibida
      // sea realmente una clave pública P-256 X.509.
      P256InteropCodec.decodePublicKeyBase64Url(invitation.ephemeralPublicKey);

      return await _identityRepository.verify(
        data: invitation.signingBytes(),
        signature: _decodeBase64Url(invitation.signature),
        publicKey: invitation.identityPublicKey,
      );
    } on Object {
      return false;
    }
  }

  @override
  bool isActiveSession(String sessionId) {
    final session = _activeSessions[sessionId];

    if (session == null) {
      return false;
    }

    if (_currentTimeMillis() > session.expiresAtEpochMillis) {
      _activeSessions.remove(sessionId);
      session.destroy();

      return false;
    }

    return true;
  }

  @override
  Future<List<int>> calculateSenderSharedSecret({
    required String sessionId,
    required String receiverEphemeralPublicKey,
  }) async {
    if (!isActiveSession(sessionId)) {
      throw StateError('La sesión no existe o ya expiró');
    }

    final senderSession = _activeSessions[sessionId];

    if (senderSession == null) {
      throw StateError('No existe la clave ECDH temporal del emisor');
    }

    final receiverCoordinates = P256InteropCodec.decodePublicKeyBase64Url(
      receiverEphemeralPublicKey,
    );

    final receiverPoint = _domain.curve.createPoint(
      _bytesToBigInt(receiverCoordinates.x),
      _bytesToBigInt(receiverCoordinates.y),
    );

    final receiverPublicKey = ECPublicKey(receiverPoint, _domain);

    final senderPrivateKey = ECPrivateKey(senderSession.privateValue, _domain);

    final agreement = ECDHBasicAgreement();

    agreement.init(senderPrivateKey);

    final sharedSecret = agreement.calculateAgreement(receiverPublicKey);

    return _bigIntToFixedBytes(sharedSecret, _coordinateLength);
  }

  _GeneratedEphemeralKeyPair _generateEphemeralKeyPair() {
    final random = FortunaRandom();

    random.seed(KeyParameter(_generateSecureBytes(32)));

    final generator = ECKeyGenerator();

    generator.init(
      ParametersWithRandom(ECKeyGeneratorParameters(_domain), random),
    );

    final keyPair = generator.generateKeyPair();

    final privateKey = keyPair.privateKey;

    final publicKey = keyPair.publicKey;

    final privateValue = privateKey.d;
    final publicPoint = publicKey.Q;

    if (privateValue == null || publicPoint == null) {
      throw StateError('No fue posible generar la clave ECDH temporal');
    }

    final x = publicPoint.x?.toBigInteger();
    final y = publicPoint.y?.toBigInteger();

    if (x == null || y == null) {
      throw StateError('La clave ECDH no contiene coordenadas públicas');
    }

    return _GeneratedEphemeralKeyPair(
      privateValue: privateValue,
      x: _bigIntToFixedBytes(x, _coordinateLength),
      y: _bigIntToFixedBytes(y, _coordinateLength),
    );
  }

  String _createDeviceId(List<int> identityPublicKeyBytes) {
    final digest = SHA256Digest().process(
      Uint8List.fromList(identityPublicKeyBytes),
    );

    return _encodeBase64Url(digest.sublist(0, 16));
  }

  Uint8List _generateSecureBytes(int length) {
    return Uint8List.fromList(
      List<int>.generate(length, (_) => _secureRandom.nextInt(256)),
    );
  }

  void _removeExpiredSessions() {
    final now = _currentTimeMillis();

    final expiredSessionIds = _activeSessions.entries
        .where((entry) => now > entry.value.expiresAtEpochMillis)
        .map((entry) => entry.key)
        .toList(growable: false);

    for (final sessionId in expiredSessionIds) {
      final removed = _activeSessions.remove(sessionId);

      removed?.destroy();
    }
  }

  String _encodeBase64Url(List<int> bytes) {
    return base64Url.encode(bytes).replaceAll('=', '');
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

class _EphemeralSession {
  _EphemeralSession({
    required this.privateValue,
    required this.expiresAtEpochMillis,
  });

  BigInt privateValue;
  final int expiresAtEpochMillis;

  void destroy() {
    privateValue = BigInt.zero;
  }
}
