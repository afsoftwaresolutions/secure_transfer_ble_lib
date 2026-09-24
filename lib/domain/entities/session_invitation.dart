import 'dart:convert';

class SessionInvitation {
  const SessionInvitation({
    required this.protocolVersion,
    required this.sessionId,
    required this.sourceApp,
    required this.sourceDeviceId,
    required this.createdAtEpochMillis,
    required this.expiresAtEpochMillis,
    required this.nonce,
    required this.identityPublicKey,
    required this.ephemeralPublicKey,
    required this.signature,
  });

  final int protocolVersion;
  final String sessionId;
  final String sourceApp;
  final String sourceDeviceId;
  final int createdAtEpochMillis;
  final int expiresAtEpochMillis;
  final String nonce;
  final String identityPublicKey;
  final String ephemeralPublicKey;
  final String signature;

  List<int> signingBytes() {
    final fields = <String>[
      protocolVersion.toString(),
      sessionId,
      sourceApp,
      sourceDeviceId,
      createdAtEpochMillis.toString(),
      expiresAtEpochMillis.toString(),
      nonce,
      identityPublicKey,
      ephemeralPublicKey,
    ];

    final canonicalContent = fields
        .map((value) {
          final byteLength = utf8.encode(value).length;

          return '$byteLength:$value';
        })
        .join('|');

    return utf8.encode(canonicalContent);
  }

  Map<String, dynamic> toJson() {
    /*
     * Este orden debe conservarse porque coincide con el JSON
     * producido por AndroidSessionInvitationRepository.kt.
     */
    return <String, dynamic>{
      'protocolVersion': protocolVersion,
      'sessionId': sessionId,
      'sourceApp': sourceApp,
      'sourceDeviceId': sourceDeviceId,
      'createdAtEpochMillis': createdAtEpochMillis,
      'expiresAtEpochMillis': expiresAtEpochMillis,
      'nonce': nonce,
      'identityPublicKey': identityPublicKey,
      'ephemeralPublicKey': ephemeralPublicKey,
      'signature': signature,
    };
  }

  factory SessionInvitation.fromJson(Map<String, dynamic> json) {
    return SessionInvitation(
      protocolVersion: _required<int>(json, 'protocolVersion'),
      sessionId: _required<String>(json, 'sessionId'),
      sourceApp: _required<String>(json, 'sourceApp'),
      sourceDeviceId: _required<String>(json, 'sourceDeviceId'),
      createdAtEpochMillis: _required<int>(json, 'createdAtEpochMillis'),
      expiresAtEpochMillis: _required<int>(json, 'expiresAtEpochMillis'),
      nonce: _required<String>(json, 'nonce'),
      identityPublicKey: _required<String>(json, 'identityPublicKey'),
      ephemeralPublicKey: _required<String>(json, 'ephemeralPublicKey'),
      signature: _required<String>(json, 'signature'),
    );
  }

  SessionInvitation copyWith({
    int? protocolVersion,
    String? sessionId,
    String? sourceApp,
    String? sourceDeviceId,
    int? createdAtEpochMillis,
    int? expiresAtEpochMillis,
    String? nonce,
    String? identityPublicKey,
    String? ephemeralPublicKey,
    String? signature,
  }) {
    return SessionInvitation(
      protocolVersion: protocolVersion ?? this.protocolVersion,
      sessionId: sessionId ?? this.sessionId,
      sourceApp: sourceApp ?? this.sourceApp,
      sourceDeviceId: sourceDeviceId ?? this.sourceDeviceId,
      createdAtEpochMillis: createdAtEpochMillis ?? this.createdAtEpochMillis,
      expiresAtEpochMillis: expiresAtEpochMillis ?? this.expiresAtEpochMillis,
      nonce: nonce ?? this.nonce,
      identityPublicKey: identityPublicKey ?? this.identityPublicKey,
      ephemeralPublicKey: ephemeralPublicKey ?? this.ephemeralPublicKey,
      signature: signature ?? this.signature,
    );
  }

  static T _required<T>(Map<String, dynamic> json, String key) {
    if (!json.containsKey(key)) {
      throw FormatException('Falta el campo obligatorio: $key');
    }

    final value = json[key];

    if (value is! T) {
      throw FormatException('El campo $key no tiene el tipo esperado');
    }

    return value;
  }
}
