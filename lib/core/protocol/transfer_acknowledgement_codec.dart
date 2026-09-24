import 'dart:convert';

import '../../domain/entities/transfer_acknowledgement.dart';

class TransferAcknowledgementCodec {
  const TransferAcknowledgementCodec();

  String encode(TransferAcknowledgement acknowledgement) {
    return jsonEncode(acknowledgement.toJson());
  }

  TransferAcknowledgement decode(String acknowledgementJson) {
    final decoded = jsonDecode(acknowledgementJson);

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('El ACK no es un objeto JSON');
    }

    return TransferAcknowledgement.fromJson(decoded);
  }
}
