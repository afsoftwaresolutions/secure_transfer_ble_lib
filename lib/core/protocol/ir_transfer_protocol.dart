import 'dart:convert';

abstract final class IrTransferProtocol {
  IrTransferProtocol._();

  // Identificación general del protocolo.
  static const int version = 1;
  static const String name = 'IR_TRANSFER_V1';

  /*
   * Debe mantenerse temporalmente igual al proyecto Kotlin.
   *
   * Actualmente Kotlin exige exactamente este valor al validar
   * una invitación. Más adelante podremos cambiar ambos proyectos
   * a un identificador común como SECURE_TRANSFER_POC.
   */
  static const String sourceApp = 'SECURE_TRANSFER_POC_KOTLIN';

  // Servicio GATT principal.
  static const String serviceUuid = '7d2ea28a-f7bd-485a-bd9d-92ad6ecfe93e';

  // Escritura de HELLO y handshake ECDH.
  static const String sessionControlUuid =
      '7d2ea28b-f7bd-485a-bd9d-92ad6ecfe93e';

  // Notificaciones con los datos cifrados.
  static const String dataTransferUuid = '7d2ea28c-f7bd-485a-bd9d-92ad6ecfe93e';

  // Escritura del ACK cifrado.
  static const String transferStatusUuid =
      '7d2ea28d-f7bd-485a-bd9d-92ad6ecfe93e';

  static const String reverseDataUuid =
    '7d2ea28e-f7bd-485a-bd9d-92ad6ecfe93e';

  // Descriptor estándar para habilitar notificaciones BLE.
  static const String clientConfigurationUuid =
      '00002902-0000-1000-8000-00805f9b34fb';

  // Negociación BLE.
  static const int requestedMtu = 185;
  static const int minimumSessionMtu = 64;

  // Temporizadores.
  static const Duration scanTimeout = Duration(seconds: 15);
  static const Duration invitationDuration = Duration(minutes: 2);
  static const Duration allowedClockDifference = Duration(seconds: 30);
  static const Duration acknowledgementTimeout = Duration(seconds: 5);

  static const int maximumAcknowledgementRetries = 2;

  // Criptografía.
  static const int identityNonceLengthBytes = 32;
  static const int aesKeyLengthBytes = 32;
  static const int aesGcmIvLengthBytes = 12;
  static const int aesGcmTagLengthBits = 128;

  // Datos de negocio.
  static const int maximumPlainTextLengthBytes = 100000;

  static const String helloPrefix = 'HELLO|';

  static String createHelloCommand(String sessionId) {
    final normalizedSessionId = sessionId.trim();

    if (normalizedSessionId.isEmpty) {
      throw ArgumentError.value(
        sessionId,
        'sessionId',
        'El sessionId no puede estar vacío',
      );
    }

    return '$helloPrefix$normalizedSessionId';
  }

  static String extractSessionIdFromHello(String command) {
    if (!command.startsWith(helloPrefix)) {
      throw const FormatException('El comando no comienza con HELLO|');
    }

    final sessionId = command.substring(helloPrefix.length).trim();

    if (sessionId.isEmpty) {
      throw const FormatException('El comando HELLO no contiene sessionId');
    }

    return sessionId;
  }

  static List<int> createHkdfSaltMaterial(String sessionId) {
    return utf8.encode('$name|$sessionId');
  }

  static List<int> createHkdfInfo(String sessionId) {
    return utf8.encode('$name|AES_256_GCM|$sessionId');
  }

  static List<int> createAssociatedData({
    required String sessionId,
    required String messageId,
  }) {
    return utf8.encode('$name|$sessionId|$messageId');
  }
}
