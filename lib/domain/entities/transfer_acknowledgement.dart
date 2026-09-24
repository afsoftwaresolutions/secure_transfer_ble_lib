class TransferAcknowledgement {
  const TransferAcknowledgement({
    required this.protocolVersion,
    required this.sessionId,
    required this.acknowledgedMessageId,
    required this.duplicate,
  });

  final int protocolVersion;
  final String sessionId;
  final String acknowledgedMessageId;
  final bool duplicate;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'protocolVersion': protocolVersion,
      'sessionId': sessionId,
      'acknowledgedMessageId': acknowledgedMessageId,
      'duplicate': duplicate,
    };
  }

  factory TransferAcknowledgement.fromJson(Map<String, dynamic> json) {
    return TransferAcknowledgement(
      protocolVersion: json['protocolVersion'] as int,
      sessionId: json['sessionId'] as String,
      acknowledgedMessageId: json['acknowledgedMessageId'] as String,
      duplicate: json['duplicate'] as bool,
    );
  }
}
