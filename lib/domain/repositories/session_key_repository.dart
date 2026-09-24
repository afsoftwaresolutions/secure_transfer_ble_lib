import 'package:secure_transfer_poc_flutter/domain/entities/encrypted_transfer_envelope.dart';

import '../entities/key_agreement_result.dart';

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
  });

  Future<String> decryptSessionMessage(EncryptedTransferEnvelope envelope);

  bool hasSessionKey(String sessionId);

  void removeSession(String sessionId);
}
