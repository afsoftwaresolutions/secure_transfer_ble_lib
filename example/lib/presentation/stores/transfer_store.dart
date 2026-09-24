import 'dart:async';

import 'package:mobx/mobx.dart';

import 'package:secure_transfer_poc_flutter/domain/use_cases/ble_central_use_case.dart';
import 'package:secure_transfer_poc_flutter/domain/use_cases/create_signed_invitation_use_case.dart';
import 'package:secure_transfer_poc_flutter/domain/use_cases/validate_scanned_invitation_use_case.dart';

import 'package:secure_transfer_poc_flutter/domain/repositories/session_key_repository.dart';
import 'package:secure_transfer_poc_flutter/domain/use_cases/create_signed_receiver_handshake_use_case.dart';

import 'package:secure_transfer_poc_flutter/domain/use_cases/ble_peripheral_use_case.dart';

import 'package:secure_transfer_poc_flutter/secure_transfer_poc_flutter.dart';

part 'transfer_store.g.dart';

enum TransferRole { none, sender, receiver }

class TransferStore = TransferStoreBase with _$TransferStore;

abstract class TransferStoreBase with Store {
  TransferStoreBase({
    required this._createSignedInvitationUseCase,
    required this._validateScannedInvitationUseCase,
    required this._bleCentralUseCase,
    required this._sessionKeyRepository,
    required this._createSignedReceiverHandshakeUseCase,
    required this._blePeripheralUseCase,
  }) {
    final initialBleState = _bleCentralUseCase.state;

    bleCentralStatus = initialBleState.status;
    bleCentralMessage = initialBleState.message;
    blePeripheralId = initialBleState.peripheralId;
    negotiatedMtu = initialBleState.negotiatedMtu;

    final initialPeripheralState = _blePeripheralUseCase.state;

    blePeripheralStatus = initialPeripheralState.status;

    blePeripheralMessage = initialPeripheralState.message;

    connectedCentralId = initialPeripheralState.centralId;

    _blePeripheralSubscription = _blePeripheralUseCase.states.listen(
      _applyPeripheralState,
    );

    _bleStateSubscription = _bleCentralUseCase.states.listen(_applyBleState);

    _receivedTextSubscription = _secureBleTransfer.receivedTexts.listen((text) {
      receivedData = text;
    });
  }

  final CreateSignedInvitationUseCase _createSignedInvitationUseCase;

  final ValidateScannedInvitationUseCase _validateScannedInvitationUseCase;

  final BleCentralUseCase _bleCentralUseCase;

  final SessionKeyRepository _sessionKeyRepository;

  final CreateSignedReceiverHandshakeUseCase _createSignedReceiverHandshakeUseCase;

  final BlePeripheralUseCase _blePeripheralUseCase;

  late final SecureBleTransfer _secureBleTransfer = SecureBleTransfer.create();

  late final StreamSubscription<BlePeripheralState> _blePeripheralSubscription;

  late final StreamSubscription<BleCentralState> _bleStateSubscription;

  late final StreamSubscription<String> _receivedTextSubscription;

  bool _sendAutomaticallyWhenReady = false;

  bool _automaticReceiveFlow = false;

  bool _sessionConfirmationStarted = false;

  bool _handshakeExchangeStarted = false;

  @observable
  bool isLoading = false;

  @observable
  String message = 'Listo para crear una invitación';

  @observable
  String? errorMessage;

  @observable
  String? invitationJson;

  @observable
  String? generatedSessionId;

  @observable
  int? invitationExpiresAtEpochMillis;

  @observable
  String? scannedSessionId;

  @observable
  String? scannedDeviceId;

  @observable
  String? receiverHandshakeJson;

  @observable
  String? receiverSessionKeyFingerprint;

  @observable
  bool receiverHandshakeReady = false;

  @observable
  BleCentralStatus bleCentralStatus = BleCentralStatus.idle;

  @observable
  String bleCentralMessage = 'Cliente BLE detenido';

  @observable
  String? blePeripheralId;

  @observable
  int? bleRssi;

  @observable
  int? negotiatedMtu;

  @observable
  String? receivedMessageId;

  @observable
  String? receivedData;

  @observable
  BlePeripheralStatus blePeripheralStatus = BlePeripheralStatus.idle;

  @observable
  String blePeripheralMessage = 'Periférico BLE detenido';

  @observable
  String? connectedCentralId;

  @observable
  String outgoingPlainText = '''
  {
    "guia": "123456789",
    "estado": "ENTREGADA",
    "origen": "FLUTTER"
  }
  ''';

  @observable
  TransferRole activeRole = TransferRole.none;

  @computed
  bool get hasGeneratedInvitation {
    return invitationJson?.isNotEmpty ?? false;
  }

  @computed
  bool get canSearchBleSender {
    if (scannedSessionId == null) {
      return false;
    }

    return switch (bleCentralStatus) {
      BleCentralStatus.requestingPermissions => false,
      BleCentralStatus.scanning => false,
      BleCentralStatus.connecting => false,
      BleCentralStatus.negotiatingMtu => false,
      BleCentralStatus.discoveringServices => false,
      BleCentralStatus.serviceReady => false,
      _ => true,
    };
  }

  @computed
  bool get canConfirmBleSession {
    return scannedSessionId != null &&
        bleCentralStatus == BleCentralStatus.serviceReady;
  }

  @computed
  bool get canExchangeEcdh {
    return bleCentralStatus == BleCentralStatus.sessionVerified &&
        receiverHandshakeReady &&
        (receiverHandshakeJson?.isNotEmpty ?? false) &&
        (receiverSessionKeyFingerprint?.isNotEmpty ?? false);
  }

  @computed
  bool get canStopBleCentral {
    return bleCentralStatus != BleCentralStatus.idle;
  }

  @computed
  bool get canStartBlePeripheral {
    return generatedSessionId != null &&
        switch (blePeripheralStatus) {
          BlePeripheralStatus.starting => false,
          BlePeripheralStatus.advertising => false,
          BlePeripheralStatus.connected => false,
          _ => true,
        };
  }

  @computed
  bool get canStopBlePeripheral {
    return blePeripheralStatus != BlePeripheralStatus.idle;
  }

  @computed
  bool get canSendEncryptedData {
    if (outgoingPlainText.trim().isEmpty) {
      return false;
    }

    return blePeripheralStatus == BlePeripheralStatus.sessionKeyReady ||
        blePeripheralStatus == BlePeripheralStatus.dataConfirmed;
  }

  @computed
  bool get canStartSendFlow {
    if (activeRole == TransferRole.receiver) {
      return false;
    }

    if (isLoading || outgoingPlainText.trim().isEmpty) {
      return false;
    }

    return switch (blePeripheralStatus) {
      BlePeripheralStatus.starting => false,
      BlePeripheralStatus.advertising => false,
      BlePeripheralStatus.connected => false,
      BlePeripheralStatus.sessionVerified => false,
      BlePeripheralStatus.receivingHandshake => false,
      BlePeripheralStatus.dataSending => false,
      BlePeripheralStatus.waitingAck => false,
      _ => true,
    };
  }

  @computed
  bool get canStartReceiveFlow {
    if (activeRole == TransferRole.sender) {
      return false;
    }

    if (isLoading) {
      return false;
    }

    return switch (bleCentralStatus) {
      BleCentralStatus.idle => true,
      BleCentralStatus.disconnected => true,
      BleCentralStatus.error => true,
      BleCentralStatus.sessionRejected => true,
      _ => false,
    };
  }

  @computed
  bool get canCloseSendFlow {
    return activeRole == TransferRole.sender;
  }

  @computed
  bool get canCloseReceiveFlow {
    return activeRole == TransferRole.receiver;
  }

  @action
  Future<void> startSendFlow() async {
    if (activeRole == TransferRole.receiver) {
      errorMessage = 'Primero debes cerrar el flujo de recepción';
      return;
    }

    activeRole = TransferRole.sender;

    errorMessage = null;

    // Si la sesión ya está preparada, reutilizamos
    // la misma clave y enviamos otro mensaje.
    if (blePeripheralStatus == BlePeripheralStatus.sessionKeyReady ||
        blePeripheralStatus == BlePeripheralStatus.dataConfirmed) {
      await sendEncryptedData();
      return;
    }

    _sendAutomaticallyWhenReady = true;

    receivedData = null;
    receivedMessageId = null;

    try {
      isLoading = true;
      message = 'Creando invitación y activando BLE...';

      final result = await _secureBleTransfer.startSending();

      invitationJson = result.invitationJson;
      generatedSessionId = result.invitation.sessionId;
      invitationExpiresAtEpochMillis = result.invitation.expiresAtEpochMillis;

      message = 'Invitación firmada y lista para escanear';
    } on Object catch (error) {
      _sendAutomaticallyWhenReady = false;
      activeRole = TransferRole.none;
      errorMessage = error.toString();
      message = 'No fue posible iniciar el envío';
    } finally {
      isLoading = false;
    }
  }

  @action
  Future<void> createSignedInvitation() async {
    isLoading = true;
    errorMessage = null;
    message = 'Creando invitación firmada...';

    try {
      final result = await _createSignedInvitationUseCase();

      if (!result.signatureValid) {
        throw StateError(
          'La invitación creada no superó '
          'la verificación local',
        );
      }

      invitationJson = result.invitationJson;
      generatedSessionId = result.invitation.sessionId;

      invitationExpiresAtEpochMillis = result.invitation.expiresAtEpochMillis;

      message = 'Invitación firmada y lista para escanear';
    } on Object catch (error) {
      errorMessage = error.toString();
      message = 'No fue posible crear la invitación';
    } finally {
      isLoading = false;
    }
  }

  @action
  Future<void> startReceiveFlow(String scannedJson) async {
    if (activeRole == TransferRole.sender) {
      errorMessage = 'Primero debes cerrar el flujo de envío';
      return;
    }

    activeRole = TransferRole.receiver;
    errorMessage = null;
    _automaticReceiveFlow = false;

    receivedData = null;
    receivedMessageId = null;
    receiverHandshakeReady = false;
    isLoading = true;
    message = 'Validando QR y buscando emisor...';

    try {
      final result = await _secureBleTransfer.prepareReceiving(scannedJson);

      scannedSessionId = result.sessionId;
      scannedDeviceId = result.senderDeviceId;

      await _secureBleTransfer.connectReceiver();
      message = 'QR válido; conectando con el emisor';
    } on Object catch (error) {
      try {
        await _secureBleTransfer.stopReceiving();
      } on Object {
        // Conservamos el error original para mostrarlo en la pantalla.
      }

      scannedSessionId = null;
      scannedDeviceId = null;
      activeRole = TransferRole.none;
      errorMessage = error.toString();
      message = 'No fue posible iniciar la recepción';
    } finally {
      isLoading = false;
    }
  }

  @action
  Future<void> validateScannedInvitation(String scannedJson) async {
    isLoading = true;
    errorMessage = null;
    message = 'Validando invitación recibida...';

    receiverHandshakeJson = null;
    receiverSessionKeyFingerprint = null;
    receiverHandshakeReady = false;

    try {
      final result = await _validateScannedInvitationUseCase(scannedJson);

      final sessionId = result.sessionId;

      final senderEphemeralPublicKey = result.senderEphemeralPublicKey;

      if (sessionId.trim().isEmpty) {
        throw StateError('La invitación no contiene sessionId');
      }

      if (senderEphemeralPublicKey.trim().isEmpty) {
        throw StateError(
          'La invitación no contiene '
          'la clave ECDH del emisor',
        );
      }

      final keyAgreement = await _sessionKeyRepository.prepareReceiverSession(
        sessionId: sessionId,
        senderEphemeralPublicKey: senderEphemeralPublicKey,
      );

      final signedHandshake = await _createSignedReceiverHandshakeUseCase(
        sessionId: sessionId,
        receiverEphemeralPublicKey: keyAgreement.receiverEphemeralPublicKey,
      );

      scannedSessionId = sessionId;
      scannedDeviceId = result.senderDeviceId;

      receiverHandshakeJson = signedHandshake.handshakeJson;

      receiverSessionKeyFingerprint = keyAgreement.sessionKeyFingerprint;

      receiverHandshakeReady = true;

      message = 'QR válido, ECDH y handshake preparados';
    } on Object catch (error) {
      scannedSessionId = null;
      scannedDeviceId = null;

      receiverHandshakeJson = null;
      receiverSessionKeyFingerprint = null;
      receiverHandshakeReady = false;

      errorMessage = error.toString();

      message = 'La invitación recibida no es válida';
    } finally {
      isLoading = false;
    }
  }

  @action
  Future<void> searchAndConnectToSender() async {
    if (scannedSessionId == null) {
      errorMessage = 'Primero debes escanear un QR válido';
      return;
    }

    errorMessage = null;

    await _bleCentralUseCase.scanAndConnect();
  }

  @action
  Future<void> confirmBleSession() async {
    final sessionId = scannedSessionId;

    if (sessionId == null || sessionId.trim().isEmpty) {
      errorMessage = 'Primero debes escanear un QR válido';
      return;
    }

    errorMessage = null;

    await _bleCentralUseCase.confirmSession(sessionId);
  }

  @action
  Future<void> exchangeEcdhKeys() async {
    final handshakeJson = receiverHandshakeJson;

    final fingerprint = receiverSessionKeyFingerprint;

    if (handshakeJson == null ||
        handshakeJson.trim().isEmpty ||
        fingerprint == null ||
        fingerprint.trim().isEmpty ||
        !receiverHandshakeReady) {
      errorMessage = 'El handshake ECDH no está preparado';
      return;
    }

    errorMessage = null;

    await _bleCentralUseCase.sendReceiverHandshake(
      handshakeJson: handshakeJson,
      sessionKeyFingerprint: fingerprint,
    );
  }

  @action
  Future<void> stopBleCentral() async {
    await _bleCentralUseCase.disconnect();
  }

  @action
  void _applyBleState(BleCentralState state) {
    bleCentralStatus = state.status;
    bleCentralMessage = state.message;
    blePeripheralId = state.peripheralId;
    bleRssi = state.rssi;
    negotiatedMtu = state.negotiatedMtu;

    receivedMessageId = state.receivedMessageId ?? receivedMessageId;

    if (!_automaticReceiveFlow) {
      return;
    }

    if (state.status == BleCentralStatus.serviceReady &&
        !_sessionConfirmationStarted) {
      _sessionConfirmationStarted = true;

      unawaited(confirmBleSession());
      return;
    }

    if (state.status == BleCentralStatus.sessionVerified &&
        !_handshakeExchangeStarted) {
      _handshakeExchangeStarted = true;

      unawaited(exchangeEcdhKeys());
      return;
    }

    if (state.status == BleCentralStatus.error ||
        state.status == BleCentralStatus.sessionRejected ||
        state.status == BleCentralStatus.disconnected) {
      _automaticReceiveFlow = false;
    }
  }

  @action
  Future<void> startBlePeripheral() async {
    final sessionId = generatedSessionId;

    if (sessionId == null || sessionId.trim().isEmpty) {
      errorMessage = 'Primero debes generar un QR';
      return;
    }

    errorMessage = null;

    await _blePeripheralUseCase.startAdvertising(sessionId);
  }

  @action
  Future<void> stopBlePeripheral() async {
    await _blePeripheralUseCase.stopAdvertising();
  }

  @action
  void _applyPeripheralState(BlePeripheralState state) {
    blePeripheralStatus = state.status;
    blePeripheralMessage = state.message;
    connectedCentralId = state.centralId;

    if (state.status == BlePeripheralStatus.sessionKeyReady &&
        _sendAutomaticallyWhenReady) {
      _sendAutomaticallyWhenReady = false;

      unawaited(sendEncryptedData());
      return;
    }

    if (state.status == BlePeripheralStatus.error ||
        state.status == BlePeripheralStatus.sessionRejected) {
      _sendAutomaticallyWhenReady = false;
    }
  }

  @action
  void updateOutgoingPlainText(String value) {
    outgoingPlainText = value;
  }

  @action
  Future<void> sendEncryptedData() async {
    if (!canSendEncryptedData) {
      errorMessage = 'Primero debe completarse el intercambio ECDH';
      return;
    }

    errorMessage = null;

    try {
      await _secureBleTransfer.sendText(outgoingPlainText);
    } on Object catch (error) {
      errorMessage = 'No se confirmó el envío: $error';
    }
  }

  @action
  Future<void> closeSendFlow() async {

    _sendAutomaticallyWhenReady = false;

    errorMessage = null;

    try {
      await _secureBleTransfer.stopSending();
    } finally {

      invitationJson = null;
      generatedSessionId = null;
      invitationExpiresAtEpochMillis = null;
      connectedCentralId = null;

      blePeripheralStatus = BlePeripheralStatus.idle;

      blePeripheralMessage = 'Periférico BLE detenido';

      message = 'Flujo de envío cerrado';

      activeRole = TransferRole.none;
    }
  }

  @action
  Future<void> closeReceiveFlow() async {

    _automaticReceiveFlow = false;
    _sessionConfirmationStarted = false;
    _handshakeExchangeStarted = false;

    errorMessage = null;

    try {
      await _secureBleTransfer.stopReceiving();
    } finally {

      scannedSessionId = null;
      scannedDeviceId = null;

      receiverHandshakeJson = null;
      receiverSessionKeyFingerprint = null;
      receiverHandshakeReady = false;

      receivedMessageId = null;
      receivedData = null;

      blePeripheralId = null;
      bleRssi = null;
      negotiatedMtu = null;

      bleCentralStatus = BleCentralStatus.idle;
      bleCentralMessage = 'Cliente BLE detenido';

      message = 'Flujo de recepción cerrado';

      activeRole = TransferRole.none;
    }
  }

  void dispose() {
    unawaited(_bleStateSubscription.cancel());
    unawaited(_blePeripheralSubscription.cancel());
    unawaited(_receivedTextSubscription.cancel());
  }
}
