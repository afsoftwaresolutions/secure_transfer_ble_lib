import 'dart:async';
import 'dart:io';

import 'package:bluetooth_low_energy/bluetooth_low_energy.dart' as ble;
import 'package:secure_transfer_poc_flutter/domain/entities/transfer_acknowledgement.dart';

import '../../core/protocol/ir_transfer_protocol.dart';
import '../../domain/entities/ble_peripheral_state.dart';
import '../../domain/repositories/ble_peripheral_repository.dart';

import '../../core/protocol/ble_frame.dart';
import '../../core/protocol/ble_frame_codec.dart';
import '../../core/protocol/ble_message_assembler.dart';
import '../../domain/repositories/session_key_repository.dart';
import '../../domain/use_cases/verify_receiver_handshake_use_case.dart';

import 'package:uuid/uuid.dart';

import '../../core/protocol/encrypted_transfer_envelope_codec.dart';
import '../../core/protocol/transfer_acknowledgement_codec.dart';

import 'dart:convert';
import 'dart:typed_data';

class FlutterBlePeripheralRepository implements BlePeripheralRepository {
  FlutterBlePeripheralRepository({
    required ble.PeripheralManager manager,
    required BleFrameCodec frameCodec,
    required SessionKeyRepository sessionKeyRepository,
    required VerifyReceiverHandshakeUseCase verifyReceiverHandshakeUseCase,
    required EncryptedTransferEnvelopeCodec envelopeCodec,
    required TransferAcknowledgementCodec acknowledgementCodec,
    Uuid? uuid,
  }) : _manager = manager,
       _frameCodec = frameCodec,
       _sessionKeyRepository = sessionKeyRepository,
       _verifyReceiverHandshakeUseCase = verifyReceiverHandshakeUseCase,
       _envelopeCodec = envelopeCodec,
       _acknowledgementCodec = acknowledgementCodec,
       _handshakeAssembler = BleMessageAssembler(codec: frameCodec),
       _ackAssembler = BleMessageAssembler(codec: frameCodec),
       _reverseDataAssembler = BleMessageAssembler(codec: frameCodec),
       _uuid = uuid ?? Uuid() {
    if (Platform.isAndroid) {
      _connectionSubscription = _manager.connectionStateChanged.listen(
        _handleConnectionStateChanged,
      );
    }

    _writeRequestedSubscription = _manager.characteristicWriteRequested.listen(
      _handleCharacteristicWriteRequested,
    );

    _notifyStateSubscription = _manager.characteristicNotifyStateChanged.listen(
      _handleNotifyStateChanged,
    );
  }

  final ble.PeripheralManager _manager;

  final SessionKeyRepository _sessionKeyRepository;

  final VerifyReceiverHandshakeUseCase _verifyReceiverHandshakeUseCase;

  final BleMessageAssembler _handshakeAssembler;

  bool _sessionWasVerified = false;

  final StreamController<BlePeripheralState> _stateController =
      StreamController<BlePeripheralState>.broadcast();

  final StreamController<String> _receivedTextsController =
    StreamController<String>.broadcast();

  StreamSubscription<ble.CentralConnectionStateChangedEventArgs>?
  _connectionSubscription;

  late final StreamSubscription<ble.GATTCharacteristicWriteRequestedEventArgs>
  _writeRequestedSubscription;

  BlePeripheralState _state = const BlePeripheralState();

  String? _activeSessionId;
  ble.Central? _connectedCentral;

  ble.GATTCharacteristic? _sessionControlCharacteristic;

  ble.GATTCharacteristic? _dataTransferCharacteristic;

  ble.GATTCharacteristic? _transferStatusCharacteristic;

  ble.GATTCharacteristic? _reverseDataCharacteristic;

  final BleMessageAssembler _reverseDataAssembler;
  final Set<String> _processedReverseMessageIds = <String>{};
  ble.Central? _verifiedCentral;

  bool _isAdvertising = false;

  final ble.UUID _serviceUuid = ble.UUID.fromString(
    IrTransferProtocol.serviceUuid,
  );

  final ble.UUID _sessionControlUuid = ble.UUID.fromString(
    IrTransferProtocol.sessionControlUuid,
  );

  final ble.UUID _dataTransferUuid = ble.UUID.fromString(
    IrTransferProtocol.dataTransferUuid,
  );

  final ble.UUID _transferStatusUuid = ble.UUID.fromString(
    IrTransferProtocol.transferStatusUuid,
  );

  final BleFrameCodec _frameCodec;

  final EncryptedTransferEnvelopeCodec _envelopeCodec;

  final TransferAcknowledgementCodec _acknowledgementCodec;

  final BleMessageAssembler _ackAssembler;

  final Uuid _uuid;

  late final StreamSubscription<
    ble.GATTCharacteristicNotifyStateChangedEventArgs
  >
  _notifyStateSubscription;

  bool _dataNotificationsEnabled = false;

  bool _reverseAckNotificationsEnabled = false;

  String? _awaitingMessageId;

  static const Duration _bluetoothReadyTimeout = Duration(seconds: 10);

  @override
  BlePeripheralState get state => _state;

  @override
  Stream<BlePeripheralState> get states => _stateController.stream;

  @override
  Stream<String> get receivedTexts => _receivedTextsController.stream;

  Future<void> _waitUntilBluetoothIsReady() async {
    var currentState = _manager.state;

    if (currentState == ble.BluetoothLowEnergyState.unknown) {
      currentState = await _manager.stateChanged
          .map((event) => event.state)
          .firstWhere((state) => state != ble.BluetoothLowEnergyState.unknown)
          .timeout(_bluetoothReadyTimeout);
    }

    if (currentState != ble.BluetoothLowEnergyState.poweredOn) {
      throw StateError(
        'Bluetooth está apagado, no autorizado o no disponible: '
        '$currentState',
      );
    }
  }

  @override
  Future<void> startAdvertising(String sessionId) async {
    if (sessionId.trim().isEmpty) {
      _emitError('No existe un sessionId generado');
      return;
    }

    await _stopInternal(updateState: false);

    _activeSessionId = sessionId;

    _emit(
      BlePeripheralState(
        status: BlePeripheralStatus.starting,
        message: 'Creando servicio GATT...',
        sessionId: sessionId,
      ),
    );

    try {
      if (Platform.isAndroid) {
        final authorized = await _manager.authorize();

        if (!authorized) {
          throw StateError(
            'Los permisos Bluetooth '
            'fueron rechazados',
          );
        }
      }

      await _waitUntilBluetoothIsReady();

      await _manager.removeAllServices();

      final service = _createGattService();

      await _manager.addService(service);

      final advertisement = ble.Advertisement(
        name: 'IR_TRANSFER',
        serviceUUIDs: <ble.UUID>[_serviceUuid],
      );

      await _manager.startAdvertising(advertisement);

      _isAdvertising = true;

      _emit(
        BlePeripheralState(
          status: BlePeripheralStatus.advertising,
          message:
              'Anunciando IR_TRANSFER; '
              'esperando receptor',
          sessionId: sessionId,
        ),
      );
    } on Object catch (error, stackTrace) {
      await _stopInternal(updateState: false);

      _emitError(
        'No fue posible iniciar '
        'el periférico BLE: $error',
      );

      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  ble.GATTService _createGattService() {
    final sessionControl = ble.GATTCharacteristic.mutable(
      uuid: _sessionControlUuid,
      properties: const [
        ble.GATTCharacteristicProperty.write,
        ble.GATTCharacteristicProperty.notify,
      ],
      permissions: const [ble.GATTCharacteristicPermission.write],
      descriptors: const [],
    );

    final dataTransfer = ble.GATTCharacteristic.mutable(
      uuid: _dataTransferUuid,
      properties: const [
        ble.GATTCharacteristicProperty.read,
        ble.GATTCharacteristicProperty.notify,
      ],
      permissions: const [ble.GATTCharacteristicPermission.read],
      descriptors: const [],
    );

    final transferStatus = ble.GATTCharacteristic.mutable(
      uuid: _transferStatusUuid,
      properties: const [
        ble.GATTCharacteristicProperty.write,
        ble.GATTCharacteristicProperty.notify,
      ],
      permissions: const [ble.GATTCharacteristicPermission.write],
      descriptors: const [],
    );

    final reverseData = ble.GATTCharacteristic.mutable(
      uuid: ble.UUID.fromString(IrTransferProtocol.reverseDataUuid),
      properties: const [ble.GATTCharacteristicProperty.write],
      permissions: const [ble.GATTCharacteristicPermission.write],
      descriptors: const [],
    );

    _sessionControlCharacteristic = sessionControl;

    _dataTransferCharacteristic = dataTransfer;

    _transferStatusCharacteristic = transferStatus;

    _reverseDataCharacteristic = reverseData;

    return ble.GATTService(
      uuid: _serviceUuid,
      isPrimary: true,
      includedServices: const [],
      characteristics: [sessionControl, dataTransfer, transferStatus, reverseData],
    );
  }

  void _handleConnectionStateChanged(
    ble.CentralConnectionStateChangedEventArgs event,
  ) {
    if (event.state == ble.ConnectionState.connected) {

      if (_verifiedCentral != null && event.central != _verifiedCentral) {
        return;
      }
      _connectedCentral = event.central;

      _emit(
        BlePeripheralState(
          status: BlePeripheralStatus.connected,
          message: 'Un receptor se conectó',
          sessionId: _activeSessionId,
          centralId: event.central.uuid.toString(),
        ),
      );

      return;
    }

    if (event.state == ble.ConnectionState.disconnected) {
      if (_connectedCentral != event.central) {
        return;
      }

      _connectedCentral = null;
      final hadPendingAck = _awaitingMessageId != null;
      _awaitingMessageId = null;
      _ackAssembler.clear();
      _dataNotificationsEnabled = false;
      _reverseAckNotificationsEnabled = false;
      _sessionWasVerified = false;
      _verifiedCentral = null;
      _reverseDataAssembler.clear();
      _processedReverseMessageIds.clear();

      if (hadPendingAck) {
        _emitError('El receptor se desconectó antes de confirmar el mensaje');
        return;
      }

      _emit(
        BlePeripheralState(
          status: BlePeripheralStatus.advertising,
          message: 'Receptor desconectado; esperando otro',
          sessionId: _activeSessionId,
        ),
      );
    }
  }

  void _handleNotifyStateChanged(
    ble.GATTCharacteristicNotifyStateChangedEventArgs event,
  ) {

    if (event.characteristic == _transferStatusCharacteristic) {
      if (_connectedCentral != null && event.central != _connectedCentral) {
        return;
      }

      _connectedCentral = event.central;
      _reverseAckNotificationsEnabled = event.state;
      return;
    }

    if (event.characteristic != _dataTransferCharacteristic) {
      return;
    }

    if (_connectedCentral != null && event.central != _connectedCentral) {
      return;
    }

    _connectedCentral = event.central;
    _dataNotificationsEnabled = event.state;
  }

  void _handleCharacteristicWriteRequested(
    ble.GATTCharacteristicWriteRequestedEventArgs event,
  ) {
    unawaited(_processCharacteristicWrite(event));
  }

  Future<void> _processCharacteristicWrite(
    ble.GATTCharacteristicWriteRequestedEventArgs event,
  ) async {
    final characteristic = event.characteristic;
    final request = event.request;

    if (_verifiedCentral != null && event.central != _verifiedCentral) {
      await _manager.respondWriteRequestWithError(
        request,
        error: ble.GATTError.insufficientAuthorization,
      );
      return;
    }

    _connectedCentral = event.central;

    if (request.offset != 0) {
      await _manager.respondWriteRequestWithError(
        request,
        error: ble.GATTError.invalidOffset,
      );

      _emit(
        BlePeripheralState(
          status: BlePeripheralStatus.error,
          message: 'La escritura contiene un offset inválido',
          sessionId: _activeSessionId,
          centralId: event.central.uuid.toString(),
        ),
      );

      return;
    }

    if (characteristic == _reverseDataCharacteristic) {
      await _processReverseDataFrame(event);
      return;
    }

    if (characteristic == _transferStatusCharacteristic) {
      await _processAckFrame(event);
      return;
    }

    if (characteristic != _sessionControlCharacteristic) {
      await _manager.respondWriteRequestWithError(
        request,
        error: ble.GATTError.requestNotSupported,
      );

      return;
    }

    if (_startsWithHello(request.value)) {
      await _processHelloCommand(event);
      return;
    }

    if (!_sessionWasVerified) {
      await _rejectSession(
        event: event,
        message: 'Primero debe verificarse la sesión mediante HELLO',
        error: ble.GATTError.insufficientAuthorization,
      );
      return;
    }

    await _processHandshakeFrame(event);
  }

  bool _startsWithHello(List<int> value) {
    final prefix = utf8.encode('HELLO|');

    if (value.length < prefix.length) {
      return false;
    }

    for (var index = 0; index < prefix.length; index++) {
      if (value[index] != prefix[index]) {
        return false;
      }
    }

    return true;
  }

  Future<void> _processHelloCommand(
    ble.GATTCharacteristicWriteRequestedEventArgs event,
  ) async {
    final command = (() {
      try {
        return utf8.decode(event.request.value, allowMalformed: false);
      } on Object {
        return null;
      }
    })();

    if (command == null) {
      await _rejectSession(
        event: event,
        message: 'El comando HELLO no contiene UTF-8 válido',
        error: ble.GATTError.invalidPDU,
      );
      return;
    }

    final components = command.split('|');

    final validFormat =
        components.length == 2 &&
        components.first == 'HELLO' &&
        components.last.isNotEmpty;

    if (!validFormat) {
      await _rejectSession(
        event: event,
        message: 'El comando HELLO tiene un formato inválido',
        error: ble.GATTError.invalidAttributeValueLength,
      );
      return;
    }

    final receivedSessionId = components.last;
    final activeSessionId = _activeSessionId;

    if (activeSessionId == null || receivedSessionId != activeSessionId) {
      await _rejectSession(
        event: event,
        message: 'La sesión no existe o no corresponde al QR del emisor',
        error: ble.GATTError.insufficientAuthorization,
      );
      return;
    }

    _sessionWasVerified = true;

    await _manager.respondWriteRequest(event.request);

    _emit(
      BlePeripheralState(
        status: BlePeripheralStatus.sessionVerified,
        message: 'Receptor vinculado a la sesión $activeSessionId',
        sessionId: activeSessionId,
        centralId: event.central.uuid.toString(),
      ),
    );
  }

  Future<void> _processHandshakeFrame(
    ble.GATTCharacteristicWriteRequestedEventArgs event,
  ) async {
    final activeSessionId = _activeSessionId;

    if (activeSessionId == null) {
      await _rejectSession(
        event: event,
        message: 'No existe una sesión activa',
        error: ble.GATTError.insufficientAuthorization,
      );
      return;
    }

    try {
      final assembledMessage = _handshakeAssembler.accept(event.request.value);

      if (assembledMessage == null) {
        await _manager.respondWriteRequest(event.request);

        _emit(
          BlePeripheralState(
            status: BlePeripheralStatus.receivingHandshake,
            message: 'Recibiendo fragmentos del handshake ECDH...',
            sessionId: activeSessionId,
            centralId: event.central.uuid.toString(),
          ),
        );

        return;
      }

      if (assembledMessage.messageType != BleMessageType.receiverHandshake) {
        throw const FormatException('Se recibió un tipo de mensaje inesperado');
      }

      final handshakeJson = utf8.decode(
        assembledMessage.payload,
        allowMalformed: false,
      );

      final handshake = await _verifyReceiverHandshakeUseCase(
        handshakeJson: handshakeJson,
        expectedSessionId: activeSessionId,
      );

      final keyAgreement = await _sessionKeyRepository.completeSenderSession(
        sessionId: activeSessionId,
        receiverEphemeralPublicKey: handshake.ephemeralPublicKey,
      );

      _handshakeAssembler.clear();

      _verifiedCentral = event.central;

      await _manager.respondWriteRequest(event.request);

      _emit(
        BlePeripheralState(
          status: BlePeripheralStatus.sessionKeyReady,
          message:
              'Handshake verificado. '
              'Huella AES emisor: '
              '${keyAgreement.sessionKeyFingerprint}',
          sessionId: activeSessionId,
          centralId: event.central.uuid.toString(),
          sessionKeyFingerprint: keyAgreement.sessionKeyFingerprint,
        ),
      );
    } on Object catch (error) {
      _handshakeAssembler.clear();

      await _rejectSession(
        event: event,
        message: 'Handshake ECDH rechazado: $error',
        error: ble.GATTError.invalidPDU,
      );
    }
  }

  Future<void> _rejectSession({
    required ble.GATTCharacteristicWriteRequestedEventArgs event,
    required String message,
    required ble.GATTError error,
  }) async {
    await _manager.respondWriteRequestWithError(event.request, error: error);

    _emit(
      BlePeripheralState(
        status: BlePeripheralStatus.sessionRejected,
        message: message,
        sessionId: _activeSessionId,
        centralId: event.central.uuid.toString(),
      ),
    );
  }

  @override
  Future<void> sendEncryptedData(String plainText) async {
    if (plainText.trim().isEmpty) {
      _emitError('El texto que se desea enviar está vacío');
      return;
    }

    final sessionId = _activeSessionId;
    final central = _connectedCentral;
    final dataTransfer = _dataTransferCharacteristic;

    if (sessionId == null) {
      _emitError('No existe una sesión activa');
      return;
    }

    if (!_sessionKeyRepository.hasSessionKey(sessionId)) {
      _emitError('No existe una clave AES para la sesión');
      return;
    }

    if (central == null) {
      _emitError('No existe un receptor conectado');
      return;
    }

    if (dataTransfer == null) {
      _emitError('No existe DATA_TRANSFER');
      return;
    }

    if (!_dataNotificationsEnabled) {
      _emitError(
        'El receptor todavía no habilitó '
        'las notificaciones de DATA_TRANSFER',
      );
      return;
    }

    if (_awaitingMessageId != null) {
      _emitError('Ya existe una transferencia esperando ACK');
      return;
    }

    try {
      final maximumNotifyLength = await _manager.getMaximumNotifyLength(
        central,
      );

      // BleFrameCodec recibe un MTU y descuenta
      // internamente los 3 bytes del encabezado ATT.
      final negotiatedMtu = maximumNotifyLength + 3;

      final messageId = _uuid.v4();

      final envelope = await _sessionKeyRepository.encryptSessionMessage(
        sessionId: sessionId,
        messageId: messageId,
        plainText: plainText,
      );

      final envelopeJson = _envelopeCodec.encode(envelope);

      final frames = _frameCodec.fragment(
        messageType: BleMessageType.encryptedData,
        payload: utf8.encode(envelopeJson),
        negotiatedMtu: negotiatedMtu,
      );

      _awaitingMessageId = messageId;

      for (var index = 0; index < frames.length; index++) {
        _emit(
          BlePeripheralState(
            status: BlePeripheralStatus.dataSending,
            message:
                'Enviando fragmento '
                '${index + 1} de ${frames.length}...',
            sessionId: sessionId,
            centralId: central.uuid.toString(),
            sessionKeyFingerprint: _state.sessionKeyFingerprint,
            messageId: messageId,
          ),
        );

        await _manager.notifyCharacteristic(
          central,
          dataTransfer,
          value: Uint8List.fromList(frames[index]),
        );
      }

      if (_awaitingMessageId == messageId) {
        _emit(
          BlePeripheralState(
            status: BlePeripheralStatus.waitingAck,
            message:
                'Mensaje cifrado enviado; '
                'esperando ACK del receptor',
            sessionId: sessionId,
            centralId: central.uuid.toString(),
            sessionKeyFingerprint: _state.sessionKeyFingerprint,
            messageId: messageId,
          ),
        );
      }
    } on Object catch (error) {
      _awaitingMessageId = null;

      _emitError('No fue posible enviar el mensaje: $error');
    }
  }

  Future<void> _processAckFrame(
    ble.GATTCharacteristicWriteRequestedEventArgs event,
  ) async {
    final sessionId = _activeSessionId;

    if (sessionId == null) {
      await _rejectAck(event: event, message: 'No existe una sesión activa');
      return;
    }

    try {
      final assembledMessage = _ackAssembler.accept(event.request.value);

      if (assembledMessage == null) {
        await _manager.respondWriteRequest(event.request);
        return;
      }

      if (assembledMessage.messageType != BleMessageType.ack) {
        throw const FormatException('Se recibió un tipo de ACK inesperado');
      }

      final envelopeJson = utf8.decode(
        assembledMessage.payload,
        allowMalformed: false,
      );

      final envelope = _envelopeCodec.decode(envelopeJson);

      if (envelope.sessionId != sessionId) {
        throw const FormatException('El ACK no pertenece a la sesión activa');
      }

      final acknowledgementJson = await _sessionKeyRepository
          .decryptSessionMessage(envelope);

      final acknowledgement = _acknowledgementCodec.decode(acknowledgementJson);

      if (acknowledgement.protocolVersion != 1) {
        throw const FormatException('Versión de ACK no soportada');
      }

      if (acknowledgement.sessionId != sessionId) {
        throw const FormatException(
          'El ACK descifrado pertenece a otra sesión',
        );
      }

      final expectedMessageId = _awaitingMessageId;

      if (expectedMessageId == null ||
          acknowledgement.acknowledgedMessageId != expectedMessageId) {
        throw const FormatException('El ACK no corresponde al mensaje enviado');
      }

      _ackAssembler.clear();
      _awaitingMessageId = null;

      await _manager.respondWriteRequest(event.request);

      _emit(
        BlePeripheralState(
          status: BlePeripheralStatus.dataConfirmed,
          message: acknowledgement.duplicate
              ? 'ACK válido: el receptor ya '
                    'tenía el mensaje'
              : 'ACK válido: transferencia confirmada',
          sessionId: sessionId,
          centralId: event.central.uuid.toString(),
          sessionKeyFingerprint: _state.sessionKeyFingerprint,
          messageId: expectedMessageId,
        ),
      );
    } on Object catch (error) {
      _ackAssembler.clear();

      await _rejectAck(event: event, message: 'ACK cifrado rechazado: $error');
    }
  }

  Future<void> _rejectAck({
    required ble.GATTCharacteristicWriteRequestedEventArgs event,
    required String message,
  }) async {
    await _manager.respondWriteRequestWithError(
      event.request,
      error: ble.GATTError.invalidPDU,
    );

    _emit(
      BlePeripheralState(
        status: BlePeripheralStatus.error,
        message: message,
        sessionId: _activeSessionId,
        centralId: event.central.uuid.toString(),
        sessionKeyFingerprint: _state.sessionKeyFingerprint,
        messageId: _awaitingMessageId,
      ),
    );
  }

  @override
  Future<void> stopAdvertising() async {
    await _stopInternal(updateState: true);
  }

  Future<void> _stopInternal({required bool updateState}) async {
    if (_isAdvertising) {
      try {
        await _manager.stopAdvertising();
      } on Object {
        // El anuncio podría haber terminado.
      }
    }

    _isAdvertising = false;
    _connectedCentral = null;
    _handshakeAssembler.clear();
    _sessionWasVerified = false;

    final sessionId = _activeSessionId;

    if (sessionId != null) {
      _sessionKeyRepository.removeSession(sessionId);
    }
    _activeSessionId = null;

    _sessionControlCharacteristic = null;
    _dataTransferCharacteristic = null;
    _transferStatusCharacteristic = null;

    _ackAssembler.clear();
    _awaitingMessageId = null;
    _dataNotificationsEnabled = false;

    _reverseAckNotificationsEnabled = false;

    _verifiedCentral = null;
    _reverseDataAssembler.clear();
    _processedReverseMessageIds.clear();

    try {
      await _manager.removeAllServices();
    } on Object {
      // Los servicios podrían haberse eliminado.
    }

    if (updateState) {
      _emit(
        const BlePeripheralState(
          status: BlePeripheralStatus.idle,
          message: 'Periférico BLE detenido',
        ),
      );
    }
  }

  void _emit(BlePeripheralState state) {
    _state = state;

    if (!_stateController.isClosed) {
      _stateController.add(state);
    }
  }

  void _emitError(String message) {
    _emit(
      BlePeripheralState(
        status: BlePeripheralStatus.error,
        message: message,
        sessionId: _activeSessionId,
        centralId: _connectedCentral?.uuid.toString(),
      ),
    );
  }

  @override
  Future<void> dispose() async {
    await _stopInternal(updateState: false);

    await _connectionSubscription?.cancel();

    await _writeRequestedSubscription.cancel();

    await _notifyStateSubscription.cancel();

    await _stateController.close();

    await _receivedTextsController.close();

  }

  Future<void> _processReverseDataFrame(
    ble.GATTCharacteristicWriteRequestedEventArgs event,
  ) async {
    final sessionId = _activeSessionId;

    if (sessionId == null ||
        event.central != _verifiedCentral ||
        !_sessionKeyRepository.hasSessionKey(sessionId)) {
      await _manager.respondWriteRequestWithError(
        event.request,
        error: ble.GATTError.insufficientAuthorization,
      );
      return;
    }

    var writeResponded = false;

    try {
      final assembled = _reverseDataAssembler.accept(event.request.value);

      if (assembled == null) {
        await _manager.respondWriteRequest(event.request);
        return;
      }

      if (assembled.messageType != BleMessageType.encryptedData) {
        throw const FormatException('Se esperaba un mensaje cifrado');
      }

      final envelopeJson = utf8.decode(
        assembled.payload,
        allowMalformed: false,
      );
      final envelope = _envelopeCodec.decode(envelopeJson);

      if (envelope.sessionId != sessionId) {
        throw const FormatException('El mensaje pertenece a otra sesión');
      }

      final text = await _sessionKeyRepository.decryptSessionMessage(
        envelope,
        purpose: SessionMessagePurpose.reverseData,
      );

      final messageKey = '$sessionId|${envelope.messageId}';
      final isNew = !_processedReverseMessageIds.contains(messageKey);

      _reverseDataAssembler.clear();
      await _manager.respondWriteRequest(event.request);
      writeResponded = true;

      if (isNew) {
        _processedReverseMessageIds.add(messageKey);

        if (!_receivedTextsController.isClosed) {
          _receivedTextsController.add(text);
        }
      }

      unawaited(
        _sendReverseAck(
          sessionId: sessionId,
          messageId: envelope.messageId,
          duplicate: !isNew,
        ),
      );

    } on Object {
      _reverseDataAssembler.clear();

      if (!writeResponded) {
        try {
          await _manager.respondWriteRequestWithError(
            event.request,
            error: ble.GATTError.invalidPDU,
          );
        } on Object {
          // La conexión pudo cerrarse mientras se respondía la escritura.
        }
      }
    }
  }

  Future<void> _sendReverseAck({
    required String sessionId,
    required String messageId,
    required bool duplicate,
  }) async {
    try {
      final central = _verifiedCentral;
      final transferStatus = _transferStatusCharacteristic;

      if (central == null ||
          transferStatus == null ||
          !_reverseAckNotificationsEnabled ||
          _activeSessionId != sessionId) {
        throw StateError('El receptor no está listo para recibir el ACK');
      }

      final acknowledgement = TransferAcknowledgement(
        protocolVersion: 1,
        sessionId: sessionId,
        acknowledgedMessageId: messageId,
        duplicate: duplicate,
      );

      final acknowledgementJson =
          _acknowledgementCodec.encode(acknowledgement);

      final envelope = await _sessionKeyRepository.encryptSessionMessage(
        sessionId: sessionId,
        messageId: _uuid.v4(),
        plainText: acknowledgementJson,
        purpose: SessionMessagePurpose.reverseAck,
      );

      final frames = _frameCodec.fragment(
        messageType: BleMessageType.ack,
        payload: utf8.encode(_envelopeCodec.encode(envelope)),
        negotiatedMtu: await _manager.getMaximumNotifyLength(central) + 3,
      );

      for (final frame in frames) {
        if (_activeSessionId != sessionId || _verifiedCentral != central) {
          return;
        }

        await _manager.notifyCharacteristic(
          central,
          transferStatus,
          value: Uint8List.fromList(frame),
        );
      }
    } on Object catch (error) {
      // La escritura del texto ya fue respondida. B podrá reintentar
      // y recibirá un nuevo ACK sin volver a entregar el texto a la app.
      final current = _state;
      _emit(
        BlePeripheralState(
          status: current.status,
          message: 'No fue posible confirmar el texto recibido: $error',
          sessionId: current.sessionId,
          centralId: current.centralId,
          sessionKeyFingerprint: current.sessionKeyFingerprint,
          messageId: current.messageId,
        ),
      );
    }
  }
}
