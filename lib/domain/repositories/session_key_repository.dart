import 'package:secure_transfer_poc_flutter/domain/entities/encrypted_transfer_envelope.dart';

import '../entities/key_agreement_result.dart';

enum SessionMessagePurpose {
  legacy,
  reverseData,
  reverseAck,
}

abstract interface class SessionKeyRepository {
  Future<ReceiverKeyAgreementResult> prepareReceiverSession({
    required String sessionId,
    required String senderEphemeralPublicKey,
  });

  Future<SenderKeyAgreementResult> completeSenderSession({
    required String sessionId,
    required String receiverEphemeralPublicKey,
  });

  Future<EncryptedTransferEnvelope> encryptSessionMessage({
    required String sessionId,
    required String messageId,
    required String plainText,
    SessionMessagePurpose purpose = SessionMessagePurpose.legacy,
  });

  Future<String> decryptSessionMessage(
    EncryptedTransferEnvelope envelope, {
    SessionMessagePurpose purpose = SessionMessagePurpose.legacy,
  });

  bool hasSessionKey(String sessionId);

  void removeSession(String sessionId);
}
