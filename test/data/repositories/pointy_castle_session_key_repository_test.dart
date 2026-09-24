import 'package:flutter_test/flutter_test.dart';
import 'package:secure_transfer_poc_flutter/data/local/identity_key_store.dart';
import 'package:secure_transfer_poc_flutter/data/repositories/pointy_castle_device_identity_repository.dart';
import 'package:secure_transfer_poc_flutter/data/repositories/pointy_castle_session_invitation_repository.dart';
import 'package:secure_transfer_poc_flutter/data/repositories/pointy_castle_session_key_repository.dart';

void main() {
  test('emisor y receptor derivan la misma huella AES', () async {
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

    final receiverResult = await sessionKeyRepository.prepareReceiverSession(
      sessionId: invitation.sessionId,
      senderEphemeralPublicKey: invitation.ephemeralPublicKey,
    );

    final senderResult = await sessionKeyRepository.completeSenderSession(
      sessionId: invitation.sessionId,
      receiverEphemeralPublicKey: receiverResult.receiverEphemeralPublicKey,
    );

    expect(
      receiverResult.sessionKeyFingerprint,
      senderResult.sessionKeyFingerprint,
    );

    expect(sessionKeyRepository.hasSessionKey(invitation.sessionId), isTrue);
  });
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
