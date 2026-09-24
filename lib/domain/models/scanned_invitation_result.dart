import '../entities/session_invitation.dart';

class ScannedInvitationResult {
  const ScannedInvitationResult({
    required this.invitation,
    required this.invitationJson,
    required this.signatureValid,
  });

  final SessionInvitation invitation;
  final String invitationJson;
  final bool signatureValid;

  String get sessionId => invitation.sessionId;

  String get senderDeviceId => invitation.sourceDeviceId;

  String get senderEphemeralPublicKey => invitation.ephemeralPublicKey;
}
