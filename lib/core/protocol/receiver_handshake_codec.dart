import 'dart:convert';

import '../../domain/entities/receiver_handshake.dart';

class ReceiverHandshakeCodec {
  const ReceiverHandshakeCodec();

  String encode(ReceiverHandshake handshake) {
    return jsonEncode(handshake.toJson());
  }

  ReceiverHandshake decode(String handshakeJson) {
    final decoded = jsonDecode(handshakeJson);

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('El handshake no contiene un objeto JSON');
    }

    return ReceiverHandshake.fromJson(decoded);
  }
}
