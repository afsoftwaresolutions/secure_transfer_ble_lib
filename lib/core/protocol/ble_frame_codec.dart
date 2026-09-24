import 'dart:typed_data';

import 'package:uuid/uuid.dart';

import 'ble_frame.dart';

class BleFrameCodec {
  BleFrameCodec({Uuid? uuid}) : _uuid = uuid ?? Uuid();

  static const int frameHeaderSize = 26;

  static const int _attHeaderSize = 3;
  static const int _maximumUnsignedShort = 65535;

  static const int _magicFirst = 0x49;
  static const int _magicSecond = 0x52;

  static const int _currentProtocolVersion = 1;

  final Uuid _uuid;

  List<Uint8List> fragment({
    required BleMessageType messageType,
    required List<int> payload,
    required int negotiatedMtu,
    String? messageId,
  }) {
    final maximumGattValueSize = negotiatedMtu - _attHeaderSize;

    final maximumPayloadSize = maximumGattValueSize - frameHeaderSize;

    if (maximumPayloadSize <= 0) {
      throw ArgumentError('El MTU $negotiatedMtu es demasiado pequeño');
    }

    final totalChunks = payload.isEmpty
        ? 1
        : (payload.length + maximumPayloadSize - 1) ~/ maximumPayloadSize;

    if (totalChunks > _maximumUnsignedShort) {
      throw ArgumentError('El mensaje requiere demasiados fragmentos');
    }

    final effectiveMessageId = messageId ?? _uuid.v4();

    return List<Uint8List>.generate(totalChunks, (index) {
      final start = index * maximumPayloadSize;

      final end = payload.isEmpty
          ? 0
          : _minimum(start + maximumPayloadSize, payload.length);

      final chunkPayload = payload.isEmpty
          ? Uint8List(0)
          : Uint8List.fromList(payload.sublist(start, end));

      return encode(
        BleFrame(
          protocolVersion: _currentProtocolVersion,
          messageType: messageType,
          messageId: effectiveMessageId,
          chunkIndex: index,
          totalChunks: totalChunks,
          payload: chunkPayload,
        ),
      );
    });
  }

  Uint8List encode(BleFrame frame) {
    if (frame.payload.length > _maximumUnsignedShort) {
      throw ArgumentError('El payload del fragmento es demasiado grande');
    }

    final messageIdBytes = _uuidToBytes(frame.messageId);

    final output = Uint8List(frameHeaderSize + frame.payload.length);

    final data = ByteData.sublistView(output);

    data.setUint8(0, _magicFirst);
    data.setUint8(1, _magicSecond);
    data.setUint8(2, frame.protocolVersion);
    data.setUint8(3, frame.messageType.code);

    output.setRange(4, 20, messageIdBytes);

    data.setUint16(20, frame.chunkIndex, Endian.big);

    data.setUint16(22, frame.totalChunks, Endian.big);

    data.setUint16(24, frame.payload.length, Endian.big);

    output.setRange(frameHeaderSize, output.length, frame.payload);

    return output;
  }

  BleFrame decode(List<int> packet) {
    if (packet.length < frameHeaderSize) {
      throw const FormatException('El fragmento BLE está incompleto');
    }

    final bytes = Uint8List.fromList(packet);
    final data = ByteData.sublistView(bytes);

    if (data.getUint8(0) != _magicFirst || data.getUint8(1) != _magicSecond) {
      throw const FormatException('El fragmento no pertenece a IR_TRANSFER');
    }

    final protocolVersion = data.getUint8(2);

    if (protocolVersion != _currentProtocolVersion) {
      throw const FormatException('Versión de protocolo no soportada');
    }

    final messageType = BleMessageType.fromCode(data.getUint8(3));

    final messageId = _bytesToUuid(bytes.sublist(4, 20));

    final chunkIndex = data.getUint16(20, Endian.big);

    final totalChunks = data.getUint16(22, Endian.big);

    final payloadLength = data.getUint16(24, Endian.big);

    if (totalChunks <= 0) {
      throw const FormatException('Cantidad de fragmentos inválida');
    }

    if (chunkIndex >= totalChunks) {
      throw const FormatException('Índice de fragmento inválido');
    }

    final remainingBytes = bytes.length - frameHeaderSize;

    if (payloadLength != remainingBytes) {
      throw const FormatException('El tamaño del payload no coincide');
    }

    return BleFrame(
      protocolVersion: protocolVersion,
      messageType: messageType,
      messageId: messageId,
      chunkIndex: chunkIndex,
      totalChunks: totalChunks,
      payload: bytes.sublist(frameHeaderSize),
    );
  }

  Uint8List _uuidToBytes(String uuid) {
    final normalized = uuid.replaceAll('-', '').toLowerCase();

    if (normalized.length != 32 ||
        !RegExp(r'^[0-9a-f]{32}$').hasMatch(normalized)) {
      throw const FormatException('El messageId no es un UUID válido');
    }

    final output = Uint8List(16);

    for (var index = 0; index < output.length; index++) {
      output[index] = int.parse(
        normalized.substring(index * 2, index * 2 + 2),
        radix: 16,
      );
    }

    return output;
  }

  String _bytesToUuid(List<int> bytes) {
    if (bytes.length != 16) {
      throw const FormatException('Un UUID debe contener 16 bytes');
    }

    final hexadecimal = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();

    return '${hexadecimal.substring(0, 8)}-'
        '${hexadecimal.substring(8, 12)}-'
        '${hexadecimal.substring(12, 16)}-'
        '${hexadecimal.substring(16, 20)}-'
        '${hexadecimal.substring(20, 32)}';
  }

  int _minimum(int first, int second) {
    return first < second ? first : second;
  }
}
