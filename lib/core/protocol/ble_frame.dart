import 'dart:typed_data';

enum BleMessageType {
  receiverHandshake(1),
  encryptedData(2),
  ack(3),
  error(4);

  const BleMessageType(this.code);

  final int code;

  static BleMessageType fromCode(int code) {
    return BleMessageType.values.firstWhere(
      (type) => type.code == code,
      orElse: () =>
          throw FormatException('Tipo de mensaje BLE desconocido: $code'),
    );
  }
}

class BleFrame {
  BleFrame({
    required this.protocolVersion,
    required this.messageType,
    required this.messageId,
    required this.chunkIndex,
    required this.totalChunks,
    required List<int> payload,
  }) : payload = Uint8List.fromList(payload) {
    if (chunkIndex < 0) {
      throw ArgumentError('chunkIndex no puede ser negativo');
    }

    if (totalChunks <= 0) {
      throw ArgumentError('totalChunks debe ser mayor que cero');
    }

    if (chunkIndex >= totalChunks) {
      throw ArgumentError('chunkIndex debe ser menor que totalChunks');
    }
  }

  final int protocolVersion;
  final BleMessageType messageType;
  final String messageId;
  final int chunkIndex;
  final int totalChunks;
  final Uint8List payload;
}

class AssembledBleMessage {
  AssembledBleMessage({
    required this.messageType,
    required this.messageId,
    required List<int> payload,
  }) : payload = Uint8List.fromList(payload);

  final BleMessageType messageType;
  final String messageId;
  final Uint8List payload;
}
