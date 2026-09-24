class ReceiverKeyAgreementResult {
  const ReceiverKeyAgreementResult({
    required this.sessionId,
    required this.receiverEphemeralPublicKey,
    required this.sessionKeyFingerprint,
  });

  final String sessionId;
  final String receiverEphemeralPublicKey;
  final String sessionKeyFingerprint;
}

class SenderKeyAgreementResult {
  const SenderKeyAgreementResult({
    required this.sessionId,
    required this.sessionKeyFingerprint,
  });

  final String sessionId;
  final String sessionKeyFingerprint;
}
