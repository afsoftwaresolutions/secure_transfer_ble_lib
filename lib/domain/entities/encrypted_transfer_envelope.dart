class EncryptedTransferEnvelope {
  const EncryptedTransferEnvelope({
    required this.protocolVersion,
    required this.sessionId,
    required this.messageId,
    required this.iv,
    required this.cipherText,
  });

  final int protocolVersion;
  final String sessionId;
  final String messageId;
  final String iv;
  final String cipherText;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'protocolVersion': protocolVersion,
      'sessionId': sessionId,
      'messageId': messageId,
      'iv': iv,
      'cipherText': cipherText,
    };
  }

  factory EncryptedTransferEnvelope.fromJson(Map<String, dynamic> json) {
    return EncryptedTransferEnvelope(
      protocolVersion: json['protocolVersion'] as int,
      sessionId: json['sessionId'] as String,
      messageId: json['messageId'] as String,
      iv: json['iv'] as String,
      cipherText: json['cipherText'] as String,
    );
  }
}
