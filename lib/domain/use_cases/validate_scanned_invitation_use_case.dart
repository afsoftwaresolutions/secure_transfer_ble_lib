import '../../core/protocol/session_invitation_codec.dart';
import '../models/scanned_invitation_result.dart';
import '../repositories/session_invitation_repository.dart';

class ValidateScannedInvitationUseCase {
  const ValidateScannedInvitationUseCase({
    required this._repository,
    required this._codec,
  });

  final SessionInvitationRepository _repository;
  final SessionInvitationCodec _codec;

  Future<ScannedInvitationResult> call(String invitationJson) async {
    if (invitationJson.trim().isEmpty) {
      throw const FormatException('El contenido del QR está vacío');
    }

    final invitation = _codec.decode(invitationJson);

    final signatureValid = await _repository.verifyInvitation(invitation);

    if (!signatureValid) {
      throw const FormatException(
        'La invitación no es válida, fue modificada '
        'o ya expiró',
      );
    }

    return ScannedInvitationResult(
      invitation: invitation,
      invitationJson: invitationJson,
      signatureValid: true,
    );
  }
}
