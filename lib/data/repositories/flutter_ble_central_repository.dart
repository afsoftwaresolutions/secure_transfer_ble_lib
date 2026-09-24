import 'dart:async';
import 'dart:io';

import 'package:bluetooth_low_energy/bluetooth_low_energy.dart' as ble;

import '../../core/protocol/ir_transfer_protocol.dart';
import '../../domain/entities/ble_central_state.dart';
import '../../domain/repositories/ble_central_repository.dart';

import '../../core/protocol/ble_frame.dart';
import '../../core/protocol/ble_frame_codec.dart';

import 'package:uuid/uuid.dart';

import '../../core/protocol/ble_message_assembler.dart';
import '../../core/protocol/encrypted_transfer_envelope_codec.dart';
import '../../core/protocol/transfer_acknowledgement_codec.dart';
import '../../domain/entities/transfer_acknowledgement.dart';
import '../../domain/repositories/session_key_repository.dart';

import 'dart:convert';
import 'dart:typed_data';

class FlutterBleCentralRepository implements BleCentralRepository {
  FlutterBleCentralRepository({
    required this._manager,
    required BleFrameCodec frameCodec,
    required this._sessionKeyRepository,
    required this._envelopeCodec,
    required this._acknowledgementCodec,
    Uuid? uuid,
  }) : _frameCodec = frameCodec,
       _incomingDataAssembler = BleMessageAssembler(codec: frameCodec),
       _uuid = uuid ?? Uuid() {
    _discoveredSubscription = _manager.discovered.listen((event) {
      unawaited(_handleDiscovered(event));
    });

    _connectionSubscription = _manager.connectionStateChanged.listen(
      _handleConnectionStateChanged,
    );

    _characteristicNotifiedSubscription = _manager.characteristicNotified
        .listen(_handleCharacteristicNotified);
  }

  static const Duration _scanTimeout = Duration(seconds: 15);

  static const Duration _bluetoothReadyTimeout = Duration(seconds: 10);

  final ble.CentralManager _manager;

  final BleFrameCodec _frameCodec;

  final SessionKeyRepository _sessionKeyRepository;

  final EncryptedTransferEnvelopeCodec _envelopeCodec;

  final TransferAcknowledgementCodec _acknowledgementCodec;

  final BleMessageAssembler _incomingDataAssembler;

  final Uuid _uuid;

  final Set<String> _processedMessageIds = <String>{};

  String? _verifiedSessionId;

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

  final StreamController<BleCentralState> _stateController =
      StreamController<BleCentralState>.broadcast();

  late final StreamSubscription<ble.DiscoveredEventArgs>
  _discoveredSubscription;

  late final StreamSubscription<ble.PeripheralConnectionStateChangedEventArgs>
  _connectionSubscription;

  late final StreamSubscription<ble.GATTCharacteristicNotifiedEventArgs>
  _characteristicNotifiedSubscription;

  BleCentralState _state = const BleCentralState();

  ble.Peripheral? _connectedPeripheral;
  ble.GATTCharacteristic? _sessionControl;
  ble.GATTCharacteristic? _dataTransfer;
  ble.GATTCharacteristic? _transferStatus;

  Timer? _scanTimer;
  bool _isScanning = false;
  bool _isHandlingPeripheral = false;

  @override
  BleCentralState get state => _state;

  @override
  Stream<BleCentralState> get states => _stateController.stream;

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
  Future<void> scanAndConnect() async {
    if (_isScanning || _isHandlingPeripheral) {
      return;
    }

    try {
      _emit(
        const BleCentralState(
          status: BleCentralStatus.requestingPermissions,
          message: 'Solicitando permisos Bluetooth...',
        ),
      );

      if (Platform.isAndroid) {
        final authorized = await _manager.authorize();

        if (!authorized) {
          throw StateError('Los permisos Bluetooth fueron rechazados');
        }
      }

      await _waitUntilBluetoothIsReady();

      _isScanning = true;
      _isHandlingPeripheral = false;

      _emit(
        const BleCentralState(
          status: BleCentralStatus.scanning,
          message: 'Buscando el servicio IR_TRANSFER...',
        ),
      );

      await _manager.stopDiscovery();

      await _manager.startDiscovery(serviceUUIDs: [_serviceUuid]);

      _scanTimer?.cancel();

      _scanTimer = Timer(_scanTimeout, () {
        unawaited(_handleScanTimeout());
      });
    } on Object catch (error) {
      await _stopScanning();

      _emitError('No fue posible iniciar BLE: $error');
    }
  }

  Future<void> _handleDiscovered(ble.DiscoveredEventArgs event) async {
    if (!_isScanning || _isHandlingPeripheral) {
      return;
    }

    final advertisesIrTransfer = event.advertisement.serviceUUIDs.contains(
      _serviceUuid,
    );

    if (!advertisesIrTransfer) {
      return;
    }

    _isHandlingPeripheral = true;

    await _stopScanning();

    final peripheral = event.peripheral;

    try {
      _emit(
        BleCentralState(
          status: BleCentralStatus.connecting,
          message: 'IR_TRANSFER encontrado. Conectando...',
          peripheralId: peripheral.uuid.toString(),
          rssi: event.rssi,
        ),
      );

      await _manager.connect(peripheral);

      _connectedPeripheral = peripheral;

      int? negotiatedMtu;

      _emit(
        BleCentralState(
          status: BleCentralStatus.negotiatingMtu,
          message: Platform.isAndroid
              ? 'Negociando MTU...'
              : 'Consultando tamaño BLE disponible...',
          peripheralId: peripheral.uuid.toString(),
          rssi: event.rssi,
        ),
      );

      if (Platform.isAndroid) {
        try {
          negotiatedMtu = await _manager.requestMTU(
            peripheral,
            mtu: IrTransferProtocol.requestedMtu,
          );
        } on Object {
          negotiatedMtu = null;
        }
      }

      if (negotiatedMtu == null) {
        final maximumWriteLength = await _manager.getMaximumWriteLength(
          peripheral,
          type: ble.GATTCharacteristicWriteType.withResponse,
        );

        if (maximumWriteLength <= BleFrameCodec.frameHeaderSize) {
          throw StateError(
            'El dispositivo informó un tamaño de escritura BLE inválido',
          );
        }

        negotiatedMtu = maximumWriteLength + 3;
      }

      _emit(
        BleCentralState(
          status: BleCentralStatus.discoveringServices,
          message: 'Descubriendo servicios GATT...',
          peripheralId: peripheral.uuid.toString(),
          rssi: event.rssi,
          negotiatedMtu: negotiatedMtu,
        ),
      );

      final services = await _manager.discoverGATT(peripheral);

      final service = _findService(services, _serviceUuid);

      if (service == null) {
        throw StateError('El dispositivo no contiene IR_TRANSFER');
      }

      _sessionControl = _findCharacteristic(service, _sessionControlUuid);

      _dataTransfer = _findCharacteristic(service, _dataTransferUuid);

      _transferStatus = _findCharacteristic(service, _transferStatusUuid);

      if (_sessionControl == null ||
          _dataTransfer == null ||
          _transferStatus == null) {
        throw StateError('El servicio IR_TRANSFER está incompleto');
      }

      _emit(
        BleCentralState(
          status: BleCentralStatus.enablingNotifications,
          message:
              'Habilitando notificaciones '
              'DATA_TRANSFER...',
          peripheralId: peripheral.uuid.toString(),
          rssi: event.rssi,
          negotiatedMtu: negotiatedMtu,
        ),
      );

      await _manager.setCharacteristicNotifyState(
        peripheral,
        _dataTransfer!,
        state: true,
      );

      _emit(
        BleCentralState(
          status: BleCentralStatus.serviceReady,
          message: 'Servicio IR_TRANSFER encontrado correctamente',
          peripheralId: peripheral.uuid.toString(),
          rssi: event.rssi,
          negotiatedMtu: negotiatedMtu,
        ),
      );
    } on Object catch (error) {
      _emitError('Falló la conexión BLE: $error');

      await _disconnectInternal();
    } finally {
      _isHandlingPeripheral = false;
    }
  }

  void _handleConnectionStateChanged(
    ble.PeripheralConnectionStateChangedEventArgs event,
  ) {
    final connectedPeripheral = _connectedPeripheral;

    if (connectedPeripheral == null ||
        event.peripheral != connectedPeripheral) {
      return;
    }

    if (event.state == ble.ConnectionState.disconnected) {
      _connectedPeripheral = null;
      _clearCharacteristics();

      _emit(
        const BleCentralState(
          status: BleCentralStatus.disconnected,
          message: 'El dispositivo BLE se desconectó',
        ),
      );
    }
  }

  Future<void> _handleScanTimeout() async {
    if (!_isScanning) {
      return;
    }

    await _stopScanning();

    _emitError(
      'No se encontró un emisor IR_TRANSFER '
      'durante 15 segundos',
    );
  }

  ble.GATTService? _findService(List<ble.GATTService> services, ble.UUID uuid) {
    for (final service in services) {
      if (service.uuid == uuid) {
        return service;
      }
    }

    return null;
  }

  ble.GATTCharacteristic? _findCharacteristic(
    ble.GATTService service,
    ble.UUID uuid,
  ) {
    for (final characteristic in service.characteristics) {
      if (characteristic.uuid == uuid) {
        return characteristic;
      }
    }

    return null;
  }

  Future<void> _stopScanning() async {
    _scanTimer?.cancel();
    _scanTimer = null;

    if (!_isScanning) {
      return;
    }

    _isScanning = false;

    try {
      await _manager.stopDiscovery();
    } on Object {
      // El escaneo podría haber terminado previamente.
    }
  }

  @override
  Future<void> confirmSession(String sessionId) async {
    if (sessionId.trim().isEmpty) {
      _emitError('No existe un sessionId validado');
      return;
    }

    final peripheral = _connectedPeripheral;
    final sessionControl = _sessionControl;

    if (peripheral == null) {
      _emitError('No existe una conexión BLE activa');
      return;
    }

    if (sessionControl == null) {
      _emitError('No se encontró SESSION_CONTROL');
      return;
    }

    final payload = Uint8List.fromList(utf8.encode('HELLO|$sessionId'));

    _emit(
      BleCentralState(
        status: BleCentralStatus.verifyingSession,
        message: 'Confirmando la sesión del QR...',
        peripheralId: peripheral.uuid.toString(),
        rssi: _state.rssi,
        negotiatedMtu: _state.negotiatedMtu,
      ),
    );

    try {
      await _manager.writeCharacteristic(
        peripheral,
        sessionControl,
        value: payload,
        type: ble.GATTCharacteristicWriteType.withResponse,
      );

      _verifiedSessionId = sessionId;

      _emit(
        BleCentralState(
          status: BleCentralStatus.sessionVerified,
          message: 'El emisor confirmó la sesión del QR',
          peripheralId: peripheral.uuid.toString(),
          rssi: _state.rssi,
          negotiatedMtu: _state.negotiatedMtu,
        ),
      );
    } on Object catch (error) {
      _emit(
        BleCentralState(
          status: BleCentralStatus.sessionRejected,
          message: 'El emisor rechazó la sesión: $error',
          peripheralId: peripheral.uuid.toString(),
          rssi: _state.rssi,
          negotiatedMtu: _state.negotiatedMtu,
        ),
      );
    }
  }

  Future<void> _sendEncryptedAck({
    required String sessionId,
    required String acknowledgedMessageId,
    required bool duplicate,
    required String? receivedData,
  }) async {
    final peripheral = _connectedPeripheral;
    final transferStatus = _transferStatus;
    final negotiatedMtu = _state.negotiatedMtu;

    if (peripheral == null || transferStatus == null) {
      throw StateError('No existe TRANSFER_STATUS');
    }

    if (negotiatedMtu == null ||
        negotiatedMtu <= BleFrameCodec.frameHeaderSize + 3) {
      throw StateError('El MTU no permite enviar el ACK');
    }

    final acknowledgement = TransferAcknowledgement(
      protocolVersion: 1,
      sessionId: sessionId,
      acknowledgedMessageId: acknowledgedMessageId,
      duplicate: duplicate,
    );

    final acknowledgementJson = _acknowledgementCodec.encode(acknowledgement);

    final encryptedEnvelope = await _sessionKeyRepository.encryptSessionMessage(
      sessionId: sessionId,
      messageId: _uuid.v4(),
      plainText: acknowledgementJson,
    );

    final envelopeJson = _envelopeCodec.encode(encryptedEnvelope);

    final frames = _frameCodec.fragment(
      messageType: BleMessageType.ack,
      payload: utf8.encode(envelopeJson),
      negotiatedMtu: negotiatedMtu,
    );

    _emit(
      BleCentralState(
        status: BleCentralStatus.ackSending,
        message:
            'Enviando ACK cifrado en '
            '${frames.length} fragmentos...',
        peripheralId: peripheral.uuid.toString(),
        rssi: _state.rssi,
        negotiatedMtu: negotiatedMtu,
        sessionKeyFingerprint: _state.sessionKeyFingerprint,
        receivedMessageId: acknowledgedMessageId,
        receivedData: receivedData,
      ),
    );

    for (var index = 0; index < frames.length; index++) {
      await _manager.writeCharacteristic(
        peripheral,
        transferStatus,
        value: frames[index],
        type: ble.GATTCharacteristicWriteType.withResponse,
      );
    }

    _emit(
      BleCentralState(
        status: BleCentralStatus.ackSent,
        message:
            'ACK cifrado enviado para '
            '$acknowledgedMessageId',
        peripheralId: peripheral.uuid.toString(),
        rssi: _state.rssi,
        negotiatedMtu: negotiatedMtu,
        sessionKeyFingerprint: _state.sessionKeyFingerprint,
        receivedMessageId: acknowledgedMessageId,
        receivedData: receivedData,
      ),
    );
  }

  Future<void> _handleDataTransferNotification(Uint8List value) async {
    final assembledMessage = (() {
      try {
        return _incomingDataAssembler.accept(value);
      } on Object catch (error) {
        _incomingDataAssembler.clear();

        _emitError(
          'Fragmento recibido inválido: '
          '$error',
        );

        return null;
      }
    })();

    if (assembledMessage == null) {
      if (_state.status != BleCentralStatus.error) {
        _emit(
          BleCentralState(
            status: BleCentralStatus.dataReceiving,
            message:
                'Recibiendo fragmentos '
                'cifrados...',
            peripheralId: _connectedPeripheral?.uuid.toString(),
            rssi: _state.rssi,
            negotiatedMtu: _state.negotiatedMtu,
            sessionKeyFingerprint: _state.sessionKeyFingerprint,
          ),
        );
      }

      return;
    }

    if (assembledMessage.messageType != BleMessageType.encryptedData) {
      _incomingDataAssembler.clear();

      _emitError(
        'Se recibió un tipo de '
        'mensaje inesperado',
      );
      return;
    }

    try {
      final envelopeJson = utf8.decode(assembledMessage.payload);

      final envelope = _envelopeCodec.decode(envelopeJson);

      final expectedSessionId = _verifiedSessionId;

      if (expectedSessionId == null ||
          expectedSessionId.isEmpty ||
          envelope.sessionId != expectedSessionId) {
        throw StateError(
          'El mensaje no pertenece a '
          'la sesión verificada',
        );
      }

      _emit(
        BleCentralState(
          status: BleCentralStatus.dataReceiving,
          message:
              'Mensaje reconstruido. '
              'Descifrando...',
          peripheralId: _connectedPeripheral?.uuid.toString(),
          rssi: _state.rssi,
          negotiatedMtu: _state.negotiatedMtu,
          sessionKeyFingerprint: _state.sessionKeyFingerprint,
        ),
      );

      final decryptedData = await _sessionKeyRepository.decryptSessionMessage(
        envelope,
      );

      final idempotencyKey =
          '${envelope.sessionId}|'
          '${envelope.messageId}';

      final firstReception = _processedMessageIds.add(idempotencyKey);

      final visibleData = firstReception ? decryptedData : _state.receivedData;

      _incomingDataAssembler.clear();

      _emit(
        BleCentralState(
          status: BleCentralStatus.dataReceived,
          message: firstReception
              ? 'Mensaje recibido y '
                    'descifrado correctamente'
              : 'Mensaje duplicado; no se '
                    'procesó nuevamente',
          peripheralId: _connectedPeripheral?.uuid.toString(),
          rssi: _state.rssi,
          negotiatedMtu: _state.negotiatedMtu,
          sessionKeyFingerprint: _state.sessionKeyFingerprint,
          receivedMessageId: envelope.messageId,
          receivedData: visibleData,
        ),
      );

      await _sendEncryptedAck(
        sessionId: envelope.sessionId,
        acknowledgedMessageId: envelope.messageId,
        duplicate: !firstReception,
        receivedData: visibleData,
      );
    } on Object catch (error) {
      _incomingDataAssembler.clear();

      _emitError(
        'AES-GCM rechazó el mensaje: '
        '$error',
      );
    }
  }

  void _handleCharacteristicNotified(
    ble.GATTCharacteristicNotifiedEventArgs event,
  ) {
    final connectedPeripheral = _connectedPeripheral;

    final dataTransfer = _dataTransfer;

    if (connectedPeripheral == null ||
        dataTransfer == null ||
        event.peripheral != connectedPeripheral ||
        event.characteristic != dataTransfer) {
      return;
    }

    unawaited(_handleDataTransferNotification(event.value));
  }

  @override
  Future<void> sendReceiverHandshake({
    required String handshakeJson,
    required String sessionKeyFingerprint,
  }) async {
    if (handshakeJson.trim().isEmpty) {
      _emitError('El handshake del receptor está vacío');
      return;
    }

    if (sessionKeyFingerprint.trim().isEmpty) {
      _emitError('La huella AES del receptor está vacía');
      return;
    }

    if (_state.status != BleCentralStatus.sessionVerified) {
      _emitError('Primero debe confirmarse la sesión del QR');
      return;
    }

    final peripheral = _connectedPeripheral;
    final sessionControl = _sessionControl;

    if (peripheral == null) {
      _emitError('No existe una conexión BLE activa');
      return;
    }

    if (sessionControl == null) {
      _emitError('No se encontró SESSION_CONTROL');
      return;
    }

    final negotiatedMtu = _state.negotiatedMtu;

    if (negotiatedMtu == null ||
        negotiatedMtu <= BleFrameCodec.frameHeaderSize + 3) {
      _emitError(
        'El MTU negociado no permite enviar '
        'fragmentos IR_TRANSFER',
      );
      return;
    }

    try {
      final frames = _frameCodec.fragment(
        messageType: BleMessageType.receiverHandshake,
        payload: utf8.encode(handshakeJson),
        negotiatedMtu: negotiatedMtu,
      );

      _emit(
        BleCentralState(
          status: BleCentralStatus.exchangingEcdh,
          message:
              'Enviando handshake firmado '
              'en ${frames.length} fragmentos...',
          peripheralId: peripheral.uuid.toString(),
          rssi: _state.rssi,
          negotiatedMtu: negotiatedMtu,
        ),
      );

      for (var index = 0; index < frames.length; index++) {
        _emit(
          BleCentralState(
            status: BleCentralStatus.exchangingEcdh,
            message:
                'Enviando fragmento '
                '${index + 1} de ${frames.length}...',
            peripheralId: peripheral.uuid.toString(),
            rssi: _state.rssi,
            negotiatedMtu: negotiatedMtu,
          ),
        );

        // El await garantiza que no enviemos el
        // siguiente fragmento hasta que Kotlin
        // responda la escritura anterior.
        await _manager.writeCharacteristic(
          peripheral,
          sessionControl,
          value: frames[index],
          type: ble.GATTCharacteristicWriteType.withResponse,
        );
      }

      _emit(
        BleCentralState(
          status: BleCentralStatus.sessionKeyReady,
          message:
              'Handshake aceptado. '
              'Huella AES receptor: '
              '$sessionKeyFingerprint',
          peripheralId: peripheral.uuid.toString(),
          rssi: _state.rssi,
          negotiatedMtu: negotiatedMtu,
          sessionKeyFingerprint: sessionKeyFingerprint,
        ),
      );
    } on Object catch (error) {
      _emit(
        BleCentralState(
          status: BleCentralStatus.sessionRejected,
          message:
              'El emisor rechazó el '
              'handshake ECDH: $error',
          peripheralId: peripheral.uuid.toString(),
          rssi: _state.rssi,
          negotiatedMtu: negotiatedMtu,
        ),
      );
    }
  }

  @override
  Future<void> disconnect() async {
    await _stopScanning();
    await _disconnectInternal();

    _emit(
      const BleCentralState(
        status: BleCentralStatus.idle,
        message: 'Cliente BLE detenido',
      ),
    );
  }

  Future<void> _disconnectInternal() async {
    final peripheral = _connectedPeripheral;

    _connectedPeripheral = null;
    _clearCharacteristics();

    _verifiedSessionId = null;
    _incomingDataAssembler.clear();
    _processedMessageIds.clear();

    if (peripheral == null) {
      return;
    }

    try {
      await _manager.disconnect(peripheral);
    } on Object {
      // Puede estar desconectado previamente.
    }
  }

  void _clearCharacteristics() {
    _sessionControl = null;
    _dataTransfer = null;
    _transferStatus = null;
  }

  void _emit(BleCentralState state) {
    _state = state;

    if (!_stateController.isClosed) {
      _stateController.add(state);
    }
  }

  void _emitError(String message) {
    _emit(
      BleCentralState(
        status: BleCentralStatus.error,
        message: message,
        peripheralId: _connectedPeripheral?.uuid.toString(),
      ),
    );
  }

  @override
  Future<void> dispose() async {
    await _stopScanning();
    await _disconnectInternal();
    await _discoveredSubscription.cancel();
    await _connectionSubscription.cancel();
    await _characteristicNotifiedSubscription.cancel();
    await _stateController.close();
  }
}
