import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:secure_transfer_poc_flutter/core/protocol/ir_transfer_protocol.dart';

void main() {
  group('IrTransferProtocol', () {
    const sessionId = 'e06c8c35-4d1c-4ae1-95ee-a70d1bdf0997';

    const messageId = '24e85b00-55b7-4b26-9fc9-e6bf501c73a9';

    test('utiliza la versión IR_TRANSFER_V1', () {
      expect(IrTransferProtocol.version, 1);
      expect(IrTransferProtocol.name, 'IR_TRANSFER_V1');
    });

    test('conserva los UUID utilizados por Kotlin', () {
      expect(
        IrTransferProtocol.serviceUuid,
        '7d2ea28a-f7bd-485a-bd9d-92ad6ecfe93e',
      );

      expect(
        IrTransferProtocol.sessionControlUuid,
        '7d2ea28b-f7bd-485a-bd9d-92ad6ecfe93e',
      );

      expect(
        IrTransferProtocol.dataTransferUuid,
        '7d2ea28c-f7bd-485a-bd9d-92ad6ecfe93e',
      );

      expect(
        IrTransferProtocol.transferStatusUuid,
        '7d2ea28d-f7bd-485a-bd9d-92ad6ecfe93e',
      );
    });

    test('crea el mismo comando HELLO de Kotlin', () {
      final command = IrTransferProtocol.createHelloCommand(sessionId);

      expect(command, 'HELLO|$sessionId');
    });

    test('extrae el sessionId del comando HELLO', () {
      final result = IrTransferProtocol.extractSessionIdFromHello(
        'HELLO|$sessionId',
      );

      expect(result, sessionId);
    });

    test('rechaza un comando que no sea HELLO', () {
      expect(
        () =>
            IrTransferProtocol.extractSessionIdFromHello('INVALID|$sessionId'),
        throwsFormatException,
      );
    });

    test('genera el material correcto para HKDF salt', () {
      final result = utf8.decode(
        IrTransferProtocol.createHkdfSaltMaterial(sessionId),
      );

      expect(result, 'IR_TRANSFER_V1|$sessionId');
    });

    test('genera la información correcta para HKDF', () {
      final result = utf8.decode(IrTransferProtocol.createHkdfInfo(sessionId));

      expect(result, 'IR_TRANSFER_V1|AES_256_GCM|$sessionId');
    });

    test('genera el AAD usado por AES-GCM', () {
      final result = utf8.decode(
        IrTransferProtocol.createAssociatedData(
          sessionId: sessionId,
          messageId: messageId,
        ),
      );

      expect(result, 'IR_TRANSFER_V1|$sessionId|$messageId');
    });
  });
}
