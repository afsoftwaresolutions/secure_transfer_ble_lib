import 'dart:convert';

import '../../domain/entities/encrypted_transfer_envelope.dart';

class EncryptedTransferEnvelopeCodec {
  const EncryptedTransferEnvelopeCodec();

  String encode(EncryptedTransferEnvelope envelope) {
    return jsonEncode(envelope.toJson());
  }

  EncryptedTransferEnvelope decode(String envelopeJson) {
    final decoded = jsonDecode(envelopeJson);

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('El sobre cifrado no es un objeto JSON');
    }

    return EncryptedTransferEnvelope.fromJson(decoded);
  }
}
