import 'dart:typed_data';

import 'ble_frame.dart';
import 'ble_frame_codec.dart';

class BleMessageAssembler {
  BleMessageAssembler({
    required BleFrameCodec codec,
    int Function()? currentTimeMillis,
  }) : _codec = codec,
       _currentTimeMillis =
           currentTimeMillis ?? (() => DateTime.now().millisecondsSinceEpoch);

  static const int _messageTimeoutMillis = 30 * 1000;

  static const int _maximumMessageSize = 256 * 1024;

  static const int _maximumChunks = 2048;

  final BleFrameCodec _codec;

  final int Function() _currentTimeMillis;

  final Map<String, _PendingMessage> _pendingMessages =
      <String, _PendingMessage>{};

  AssembledBleMessage? accept(List<int> packet) {
    _removeExpiredMessages();

    final frame = _codec.decode(packet);

    if (frame.totalChunks > _maximumChunks) {
      throw const FormatException('El mensaje contiene demasiados fragmentos');
    }

    final pending = _pendingMessages.putIfAbsent(
      frame.messageId,
      () => _PendingMessage(
        messageType: frame.messageType,
        totalChunks: frame.totalChunks,
        createdAtMillis: _currentTimeMillis(),
      ),
    );

    if (pending.messageType != frame.messageType) {
      throw const FormatException('Los fragmentos tienen tipos diferentes');
    }

    if (pending.totalChunks != frame.totalChunks) {
      throw const FormatException('Los fragmentos tienen totales diferentes');
    }

    final previousChunk = pending.chunks[frame.chunkIndex];

    if (previousChunk != null) {
      if (!_bytesAreEqual(previousChunk, frame.payload)) {
        throw const FormatException(
          'Se recibió un fragmento '
          'duplicado diferente',
        );
      }

      return null;
    }

    final newTotalSize = pending.receivedBytes + frame.payload.length;

    if (newTotalSize > _maximumMessageSize) {
      _pendingMessages.remove(frame.messageId);

      throw const FormatException('El mensaje supera el tamaño permitido');
    }

    pending.chunks[frame.chunkIndex] = Uint8List.fromList(frame.payload);

    pending.receivedBytes = newTotalSize;

    final isComplete = pending.chunks.every((chunk) => chunk != null);

    if (!isComplete) {
      return null;
    }

    final completePayload = BytesBuilder(copy: false);

    for (final chunk in pending.chunks) {
      completePayload.add(
        chunk ??
            (throw StateError(
              'El mensaje contiene '
              'un fragmento vacío',
            )),
      );
    }

    _pendingMessages.remove(frame.messageId);

    return AssembledBleMessage(
      messageType: pending.messageType,
      messageId: frame.messageId,
      payload: completePayload.takeBytes(),
    );
  }

  void clear() {
    for (final pending in _pendingMessages.values) {
      pending.clear();
    }

    _pendingMessages.clear();
  }

  void _removeExpiredMessages() {
    final expirationLimit = _currentTimeMillis() - _messageTimeoutMillis;

    final expiredIds = _pendingMessages.entries
        .where((entry) => entry.value.createdAtMillis < expirationLimit)
        .map((entry) => entry.key)
        .toList(growable: false);

    for (final messageId in expiredIds) {
      final removed = _pendingMessages.remove(messageId);

      removed?.clear();
    }
  }

  bool _bytesAreEqual(List<int> first, List<int> second) {
    if (first.length != second.length) {
      return false;
    }

    for (var index = 0; index < first.length; index++) {
      if (first[index] != second[index]) {
        return false;
      }
    }

    return true;
  }
}

class _PendingMessage {
  _PendingMessage({
    required this.messageType,
    required this.totalChunks,
    required this.createdAtMillis,
  }) : chunks = List<Uint8List?>.filled(totalChunks, null);

  final BleMessageType messageType;
  final int totalChunks;
  final int createdAtMillis;
  final List<Uint8List?> chunks;

  int receivedBytes = 0;

  void clear() {
    for (final chunk in chunks) {
      chunk?.fillRange(0, chunk.length, 0);
    }
  }
}
