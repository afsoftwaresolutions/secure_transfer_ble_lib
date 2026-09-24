import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:secure_transfer_poc_flutter/core/protocol/ble_frame.dart';
import 'package:secure_transfer_poc_flutter/core/protocol/ble_frame_codec.dart';

void main() {
  final codec = BleFrameCodec();

  test('codifica el encabezado igual que Kotlin', () {
    final frame = BleFrame(
      protocolVersion: 1,
      messageType: BleMessageType.receiverHandshake,
      messageId: '00112233-4455-6677-8899-aabbccddeeff',
      chunkIndex: 0,
      totalChunks: 1,
      payload: utf8.encode('abc'),
    );

    final encoded = codec.encode(frame);

    final hexadecimal = encoded
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();

    expect(
      hexadecimal,
      '49520101'
      '00112233445566778899aabbccddeeff'
      '0000'
      '0001'
      '0003'
      '616263',
    );

    final decoded = codec.decode(encoded);

    expect(decoded.messageType, BleMessageType.receiverHandshake);

    expect(decoded.messageId, '00112233-4455-6677-8899-aabbccddeeff');

    expect(decoded.chunkIndex, 0);
    expect(decoded.totalChunks, 1);
    expect(utf8.decode(decoded.payload), 'abc');
  });

  test('fragmenta respetando el MTU negociado', () {
    final originalPayload = List<int>.generate(80, (index) => index);

    final frames = codec.fragment(
      messageType: BleMessageType.receiverHandshake,
      payload: originalPayload,
      negotiatedMtu: 64,
      messageId: 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
    );

    // MTU 64:
    // 64 - 3 bytes ATT - 26 del header
    // = 35 bytes útiles por fragmento.
    expect(frames.length, 3);

    final reconstructed = <int>[];

    for (var index = 0; index < frames.length; index++) {
      expect(frames[index].length, lessThanOrEqualTo(61));

      final decoded = codec.decode(frames[index]);

      expect(decoded.chunkIndex, index);
      expect(decoded.totalChunks, 3);

      reconstructed.addAll(decoded.payload);
    }

    expect(reconstructed, originalPayload);
  });
}
