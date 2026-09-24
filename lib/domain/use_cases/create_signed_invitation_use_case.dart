import '../../core/protocol/session_invitation_codec.dart';
import '../models/signed_invitation_result.dart';
import '../repositories/session_invitation_repository.dart';

class CreateSignedInvitationUseCase {
  const CreateSignedInvitationUseCase({
    required this._repository,
    required this._codec,
  });

  final SessionInvitationRepository _repository;
  final SessionInvitationCodec _codec;

  Future<SignedInvitationResult> call() async {
    final invitation = await _repository.createSenderInvitation();

    final signatureValid = await _repository.verifyInvitation(invitation);

    final invitationJson = _codec.encode(invitation);

    return SignedInvitationResult(
      invitation: invitation,
      invitationJson: invitationJson,
      signatureValid: signatureValid,
    );
  }
}
