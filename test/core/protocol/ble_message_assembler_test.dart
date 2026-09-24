import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:secure_transfer_poc_flutter/core/protocol/ble_frame.dart';
import 'package:secure_transfer_poc_flutter/core/protocol/ble_frame_codec.dart';
import 'package:secure_transfer_poc_flutter/core/protocol/ble_message_assembler.dart';

void main() {
  test('reconstruye un mensaje recibido '
      'en varios fragmentos', () {
    final codec = BleFrameCodec();

    final assembler = BleMessageAssembler(codec: codec);

    final originalText = List<String>.filled(
      20,
      'Mensaje cifrado desde Kotlin',
    ).join('|');

    final frames = codec.fragment(
      messageType: BleMessageType.encryptedData,
      payload: utf8.encode(originalText),
      negotiatedMtu: 64,
      messageId: '00112233-4455-6677-8899-aabbccddeeff',
    );

    AssembledBleMessage? result;

    for (final frame in frames) {
      result = assembler.accept(frame);
    }

    expect(result, isNotNull);

    expect(result!.messageType, BleMessageType.encryptedData);

    expect(result.messageId, '00112233-4455-6677-8899-aabbccddeeff');

    expect(utf8.decode(result.payload), originalText);
  });

  test('acepta fragmentos recibidos '
      'fuera de orden', () {
    final codec = BleFrameCodec();

    final assembler = BleMessageAssembler(codec: codec);

    final originalPayload = List<int>.generate(100, (index) => index);

    final frames = codec.fragment(
      messageType: BleMessageType.encryptedData,
      payload: originalPayload,
      negotiatedMtu: 64,
      messageId: 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
    );

    AssembledBleMessage? result;

    for (final frame in frames.reversed) {
      final accepted = assembler.accept(frame);

      if (accepted != null) {
        result = accepted;
      }
    }

    expect(result, isNotNull);
    expect(result!.payload, originalPayload);
  });
}
