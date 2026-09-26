import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:secure_transfer_poc_flutter/core/protocol/encrypted_transfer_envelope_codec.dart';
import 'package:secure_transfer_poc_flutter/data/local/identity_key_store.dart';
import 'package:secure_transfer_poc_flutter/data/repositories/pointy_castle_device_identity_repository.dart';
import 'package:secure_transfer_poc_flutter/data/repositories/pointy_castle_session_invitation_repository.dart';
import 'package:secure_transfer_poc_flutter/data/repositories/pointy_castle_session_key_repository.dart';
import 'package:secure_transfer_poc_flutter/domain/entities/encrypted_transfer_envelope.dart';
import 'package:secure_transfer_poc_flutter/domain/repositories/session_key_repository.dart';

void main() {
  test('cifra y descifra un mensaje con AES-GCM', () async {
    final identityRepository = PointyCastleDeviceIdentityRepository(
      keyStore: _MemoryIdentityKeyStore(),
    );

    final invitationRepository = PointyCastleSessionInvitationRepository(
      identityRepository: identityRepository,
    );

    final sessionKeyRepository = PointyCastleSessionKeyRepository(
      sessionInvitationRepository: invitationRepository,
    );

    final invitation = await invitationRepository.createSenderInvitation();

    final receiver = await sessionKeyRepository.prepareReceiverSession(
      sessionId: invitation.sessionId,
      senderEphemeralPublicKey: invitation.ephemeralPublicKey,
    );

    await sessionKeyRepository.completeSenderSession(
      sessionId: invitation.sessionId,
      receiverEphemeralPublicKey: receiver.receiverEphemeralPublicKey,
    );

    const originalText =
        '{"guia":"123456789",'
        '"estado":"ENTREGADA"}';

    final envelope = await sessionKeyRepository.encryptSessionMessage(
      sessionId: invitation.sessionId,
      messageId: 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
      plainText: originalText,
    );

    const codec = EncryptedTransferEnvelopeCodec();

    final envelopeJson = codec.encode(envelope);

    final decodedEnvelope = codec.decode(envelopeJson);

    final decryptedText = await sessionKeyRepository.decryptSessionMessage(
      decodedEnvelope,
    );

    expect(decryptedText, originalText);

    final reverseEnvelope = await sessionKeyRepository.encryptSessionMessage(
      sessionId: invitation.sessionId,
      messageId: 'bbbbbbbb-cccc-dddd-eeee-ffffffffffff',
      plainText: originalText,
      purpose: SessionMessagePurpose.reverseData,
    );

    expect(
      await sessionKeyRepository.decryptSessionMessage(
        reverseEnvelope,
        purpose: SessionMessagePurpose.reverseData,
      ),
      originalText,
    );

    expect(
      sessionKeyRepository.decryptSessionMessage(
        reverseEnvelope,
        purpose: SessionMessagePurpose.legacy,
      ),
      throwsA(anything),
    );

    final reverseAckEnvelope =
        await sessionKeyRepository.encryptSessionMessage(
      sessionId: invitation.sessionId,
      messageId: 'cccccccc-dddd-eeee-ffff-000000000000',
      plainText: '{"ack":"ok"}',
      purpose: SessionMessagePurpose.reverseAck,
    );

    expect(
      await sessionKeyRepository.decryptSessionMessage(
        reverseAckEnvelope,
        purpose: SessionMessagePurpose.reverseAck,
      ),
      '{"ack":"ok"}',
    );

    expect(
      sessionKeyRepository.decryptSessionMessage(
        reverseAckEnvelope,
        purpose: SessionMessagePurpose.reverseData,
      ),
      throwsA(anything),
    );

  });

  test('AES-GCM rechaza un ciphertext modificado', () async {
    final identityRepository = PointyCastleDeviceIdentityRepository(
      keyStore: _MemoryIdentityKeyStore(),
    );

    final invitationRepository = PointyCastleSessionInvitationRepository(
      identityRepository: identityRepository,
    );

    final sessionKeyRepository = PointyCastleSessionKeyRepository(
      sessionInvitationRepository: invitationRepository,
    );

    final invitation = await invitationRepository.createSenderInvitation();

    final receiver = await sessionKeyRepository.prepareReceiverSession(
      sessionId: invitation.sessionId,
      senderEphemeralPublicKey: invitation.ephemeralPublicKey,
    );

    await sessionKeyRepository.completeSenderSession(
      sessionId: invitation.sessionId,
      receiverEphemeralPublicKey: receiver.receiverEphemeralPublicKey,
    );

    final envelope = await sessionKeyRepository.encryptSessionMessage(
      sessionId: invitation.sessionId,
      messageId: '11111111-2222-3333-4444-555555555555',
      plainText: 'mensaje protegido',
    );

    final modifiedCipherText = _decodeBase64Url(envelope.cipherText);

    modifiedCipherText[0] ^= 0x01;

    final modifiedEnvelope = EncryptedTransferEnvelope(
      protocolVersion: envelope.protocolVersion,
      sessionId: envelope.sessionId,
      messageId: envelope.messageId,
      iv: envelope.iv,
      cipherText: base64Url.encode(modifiedCipherText).replaceAll('=', ''),
    );

    expect(
      sessionKeyRepository.decryptSessionMessage(modifiedEnvelope),
      throwsA(anything),
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
  Future<String?> read() async => _value;

  @override
  Future<void> write(String value) async {
    _value = value;
  }
}
