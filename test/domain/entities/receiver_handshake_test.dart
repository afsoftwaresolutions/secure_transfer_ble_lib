import 'package:flutter_test/flutter_test.dart';
import 'package:secure_transfer_poc_flutter/domain/entities/receiver_handshake.dart';

void main() {
  test('signingBytes usa el mismo formato binario de Kotlin', () {
    const handshake = ReceiverHandshake(
      protocolVersion: 1,
      sessionId: 's',
      receiverApp: 'f',
      createdAtEpochMillis: 1,
      nonce: 'n',
      identityPublicKey: 'i',
      ephemeralPublicKey: 'e',
      signature: '',
    );

    final actualHex = handshake
        .signingBytes()
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();

    expect(
      actualHex,
      '00000001'
      '0000000173'
      '0000000166'
      '0000000000000001'
      '000000016e'
      '0000000169'
      '0000000165',
    );
  });
}
