import 'receiver_handshake.dart';

class SignedReceiverHandshakeResult {
  const SignedReceiverHandshakeResult({
    required this.handshake,
    required this.handshakeJson,
  });

  final ReceiverHandshake handshake;
  final String handshakeJson;
}
