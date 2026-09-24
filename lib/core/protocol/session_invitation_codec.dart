import 'dart:convert';

import '../../domain/entities/session_invitation.dart';

class SessionInvitationCodec {
  const SessionInvitationCodec();

  String encode(SessionInvitation invitation) {
    return jsonEncode(invitation.toJson());
  }

  SessionInvitation decode(String invitationJson) {
    if (invitationJson.trim().isEmpty) {
      throw const FormatException('El contenido de la invitación está vacío');
    }

    try {
      final decoded = jsonDecode(invitationJson);

      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('La invitación debe ser un objeto JSON');
      }

      return SessionInvitation.fromJson(decoded);
    } on FormatException {
      rethrow;
    } catch (error) {
      throw FormatException(
        'No fue posible interpretar la invitación: '
        '$error',
      );
    }
  }
}
