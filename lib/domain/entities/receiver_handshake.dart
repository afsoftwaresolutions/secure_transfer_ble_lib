import 'dart:convert';
import 'dart:typed_data';

class ReceiverHandshake {
  const ReceiverHandshake({
    required this.protocolVersion,
    required this.sessionId,
    required this.receiverApp,
    required this.createdAtEpochMillis,
    required this.nonce,
    required this.identityPublicKey,
    required this.ephemeralPublicKey,
    required this.signature,
  });

  final int protocolVersion;
  final String sessionId;
  final String receiverApp;
  final int createdAtEpochMillis;
  final String nonce;
  final String identityPublicKey;
  final String ephemeralPublicKey;
  final String signature;

  ReceiverHandshake copyWith({String? signature}) {
    return ReceiverHandshake(
      protocolVersion: protocolVersion,
      sessionId: sessionId,
      receiverApp: receiverApp,
      createdAtEpochMillis: createdAtEpochMillis,
      nonce: nonce,
      identityPublicKey: identityPublicKey,
      ephemeralPublicKey: ephemeralPublicKey,
      signature: signature ?? this.signature,
    );
  }

  /// Produce exactamente los mismos bytes que:
  ///
  /// DataOutputStream.writeInt()
  /// DataOutputStream.writeLong()
  /// DataOutputStream.write(byte[])
  ///
  /// en Kotlin/Java.
  Uint8List signingBytes() {
    final builder = BytesBuilder(copy: false);

    _writeInt32(builder, protocolVersion);
    _writeString(builder, sessionId);
    _writeString(builder, receiverApp);
    _writeInt64(builder, createdAtEpochMillis);
    _writeString(builder, nonce);
    _writeString(builder, identityPublicKey);
    _writeString(builder, ephemeralPublicKey);

    return builder.takeBytes();
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'protocolVersion': protocolVersion,
      'sessionId': sessionId,
      'receiverApp': receiverApp,
      'createdAtEpochMillis': createdAtEpochMillis,
      'nonce': nonce,
      'identityPublicKey': identityPublicKey,
      'ephemeralPublicKey': ephemeralPublicKey,
      'signature': signature,
    };
  }

  factory ReceiverHandshake.fromJson(Map<String, dynamic> json) {
    return ReceiverHandshake(
      protocolVersion: json['protocolVersion'] as int,
      sessionId: json['sessionId'] as String,
      receiverApp: json['receiverApp'] as String,
      createdAtEpochMillis: json['createdAtEpochMillis'] as int,
      nonce: json['nonce'] as String,
      identityPublicKey: json['identityPublicKey'] as String,
      ephemeralPublicKey: json['ephemeralPublicKey'] as String,
      signature: json['signature'] as String,
    );
  }

  void _writeString(BytesBuilder builder, String value) {
    final bytes = utf8.encode(value);

    _writeInt32(builder, bytes.length);
    builder.add(bytes);
  }

  void _writeInt32(BytesBuilder builder, int value) {
    final data = ByteData(4)..setInt32(0, value, Endian.big);

    builder.add(data.buffer.asUint8List());
  }

  void _writeInt64(BytesBuilder builder, int value) {
    final data = ByteData(8)..setInt64(0, value, Endian.big);

    builder.add(data.buffer.asUint8List());
  }
}
