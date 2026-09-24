import '../entities/session_invitation.dart';

class SignedInvitationResult {
  const SignedInvitationResult({
    required this.invitation,
    required this.invitationJson,
    required this.signatureValid,
  });

  final SessionInvitation invitation;
  final String invitationJson;
  final bool signatureValid;
}
