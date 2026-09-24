import '../entities/session_invitation.dart';

abstract interface class SessionInvitationRepository {
  Future<SessionInvitation> createSenderInvitation();

  Future<bool> verifyInvitation(SessionInvitation invitation);

  bool isActiveSession(String sessionId);

  Future<List<int>> calculateSenderSharedSecret({
    required String sessionId,
    required String receiverEphemeralPublicKey,
  });
}
