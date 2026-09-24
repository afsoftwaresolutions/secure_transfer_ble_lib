// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transfer_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$TransferStore on TransferStoreBase, Store {
  Computed<bool>? _$hasGeneratedInvitationComputed;

  @override
  bool get hasGeneratedInvitation =>
      (_$hasGeneratedInvitationComputed ??= Computed<bool>(
        () => super.hasGeneratedInvitation,
        name: 'TransferStoreBase.hasGeneratedInvitation',
      )).value;
  Computed<bool>? _$canSearchBleSenderComputed;

  @override
  bool get canSearchBleSender =>
      (_$canSearchBleSenderComputed ??= Computed<bool>(
        () => super.canSearchBleSender,
        name: 'TransferStoreBase.canSearchBleSender',
      )).value;
  Computed<bool>? _$canConfirmBleSessionComputed;

  @override
  bool get canConfirmBleSession =>
      (_$canConfirmBleSessionComputed ??= Computed<bool>(
        () => super.canConfirmBleSession,
        name: 'TransferStoreBase.canConfirmBleSession',
      )).value;
  Computed<bool>? _$canExchangeEcdhComputed;

  @override
  bool get canExchangeEcdh => (_$canExchangeEcdhComputed ??= Computed<bool>(
    () => super.canExchangeEcdh,
    name: 'TransferStoreBase.canExchangeEcdh',
  )).value;
  Computed<bool>? _$canStopBleCentralComputed;

  @override
  bool get canStopBleCentral => (_$canStopBleCentralComputed ??= Computed<bool>(
    () => super.canStopBleCentral,
    name: 'TransferStoreBase.canStopBleCentral',
  )).value;
  Computed<bool>? _$canStartBlePeripheralComputed;

  @override
  bool get canStartBlePeripheral =>
      (_$canStartBlePeripheralComputed ??= Computed<bool>(
        () => super.canStartBlePeripheral,
        name: 'TransferStoreBase.canStartBlePeripheral',
      )).value;
  Computed<bool>? _$canStopBlePeripheralComputed;

  @override
  bool get canStopBlePeripheral =>
      (_$canStopBlePeripheralComputed ??= Computed<bool>(
        () => super.canStopBlePeripheral,
        name: 'TransferStoreBase.canStopBlePeripheral',
      )).value;
  Computed<bool>? _$canSendEncryptedDataComputed;

  @override
  bool get canSendEncryptedData =>
      (_$canSendEncryptedDataComputed ??= Computed<bool>(
        () => super.canSendEncryptedData,
        name: 'TransferStoreBase.canSendEncryptedData',
      )).value;
  Computed<bool>? _$canStartSendFlowComputed;

  @override
  bool get canStartSendFlow => (_$canStartSendFlowComputed ??= Computed<bool>(
    () => super.canStartSendFlow,
    name: 'TransferStoreBase.canStartSendFlow',
  )).value;
  Computed<bool>? _$canStartReceiveFlowComputed;

  @override
  bool get canStartReceiveFlow =>
      (_$canStartReceiveFlowComputed ??= Computed<bool>(
        () => super.canStartReceiveFlow,
        name: 'TransferStoreBase.canStartReceiveFlow',
      )).value;
  Computed<bool>? _$canCloseSendFlowComputed;

  @override
  bool get canCloseSendFlow => (_$canCloseSendFlowComputed ??= Computed<bool>(
    () => super.canCloseSendFlow,
    name: 'TransferStoreBase.canCloseSendFlow',
  )).value;
  Computed<bool>? _$canCloseReceiveFlowComputed;

  @override
  bool get canCloseReceiveFlow =>
      (_$canCloseReceiveFlowComputed ??= Computed<bool>(
        () => super.canCloseReceiveFlow,
        name: 'TransferStoreBase.canCloseReceiveFlow',
      )).value;

  late final _$isLoadingAtom = Atom(
    name: 'TransferStoreBase.isLoading',
    context: context,
  );

  @override
  bool get isLoading {
    _$isLoadingAtom.reportRead();
    return super.isLoading;
  }

  @override
  set isLoading(bool value) {
    _$isLoadingAtom.reportWrite(value, super.isLoading, () {
      super.isLoading = value;
    });
  }

  late final _$messageAtom = Atom(
    name: 'TransferStoreBase.message',
    context: context,
  );

  @override
  String get message {
    _$messageAtom.reportRead();
    return super.message;
  }

  @override
  set message(String value) {
    _$messageAtom.reportWrite(value, super.message, () {
      super.message = value;
    });
  }

  late final _$errorMessageAtom = Atom(
    name: 'TransferStoreBase.errorMessage',
    context: context,
  );

  @override
  String? get errorMessage {
    _$errorMessageAtom.reportRead();
    return super.errorMessage;
  }

  @override
  set errorMessage(String? value) {
    _$errorMessageAtom.reportWrite(value, super.errorMessage, () {
      super.errorMessage = value;
    });
  }

  late final _$invitationJsonAtom = Atom(
    name: 'TransferStoreBase.invitationJson',
    context: context,
  );

  @override
  String? get invitationJson {
    _$invitationJsonAtom.reportRead();
    return super.invitationJson;
  }

  @override
  set invitationJson(String? value) {
    _$invitationJsonAtom.reportWrite(value, super.invitationJson, () {
      super.invitationJson = value;
    });
  }

  late final _$generatedSessionIdAtom = Atom(
    name: 'TransferStoreBase.generatedSessionId',
    context: context,
  );

  @override
  String? get generatedSessionId {
    _$generatedSessionIdAtom.reportRead();
    return super.generatedSessionId;
  }

  @override
  set generatedSessionId(String? value) {
    _$generatedSessionIdAtom.reportWrite(value, super.generatedSessionId, () {
      super.generatedSessionId = value;
    });
  }

  late final _$invitationExpiresAtEpochMillisAtom = Atom(
    name: 'TransferStoreBase.invitationExpiresAtEpochMillis',
    context: context,
  );

  @override
  int? get invitationExpiresAtEpochMillis {
    _$invitationExpiresAtEpochMillisAtom.reportRead();
    return super.invitationExpiresAtEpochMillis;
  }

  @override
  set invitationExpiresAtEpochMillis(int? value) {
    _$invitationExpiresAtEpochMillisAtom.reportWrite(
      value,
      super.invitationExpiresAtEpochMillis,
      () {
        super.invitationExpiresAtEpochMillis = value;
      },
    );
  }

  late final _$scannedSessionIdAtom = Atom(
    name: 'TransferStoreBase.scannedSessionId',
    context: context,
  );

  @override
  String? get scannedSessionId {
    _$scannedSessionIdAtom.reportRead();
    return super.scannedSessionId;
  }

  @override
  set scannedSessionId(String? value) {
    _$scannedSessionIdAtom.reportWrite(value, super.scannedSessionId, () {
      super.scannedSessionId = value;
    });
  }

  late final _$scannedDeviceIdAtom = Atom(
    name: 'TransferStoreBase.scannedDeviceId',
    context: context,
  );

  @override
  String? get scannedDeviceId {
    _$scannedDeviceIdAtom.reportRead();
    return super.scannedDeviceId;
  }

  @override
  set scannedDeviceId(String? value) {
    _$scannedDeviceIdAtom.reportWrite(value, super.scannedDeviceId, () {
      super.scannedDeviceId = value;
    });
  }

  late final _$receiverHandshakeJsonAtom = Atom(
    name: 'TransferStoreBase.receiverHandshakeJson',
    context: context,
  );

  @override
  String? get receiverHandshakeJson {
    _$receiverHandshakeJsonAtom.reportRead();
    return super.receiverHandshakeJson;
  }

  @override
  set receiverHandshakeJson(String? value) {
    _$receiverHandshakeJsonAtom.reportWrite(
      value,
      super.receiverHandshakeJson,
      () {
        super.receiverHandshakeJson = value;
      },
    );
  }

  late final _$receiverSessionKeyFingerprintAtom = Atom(
    name: 'TransferStoreBase.receiverSessionKeyFingerprint',
    context: context,
  );

  @override
  String? get receiverSessionKeyFingerprint {
    _$receiverSessionKeyFingerprintAtom.reportRead();
    return super.receiverSessionKeyFingerprint;
  }

  @override
  set receiverSessionKeyFingerprint(String? value) {
    _$receiverSessionKeyFingerprintAtom.reportWrite(
      value,
      super.receiverSessionKeyFingerprint,
      () {
        super.receiverSessionKeyFingerprint = value;
      },
    );
  }

  late final _$receiverHandshakeReadyAtom = Atom(
    name: 'TransferStoreBase.receiverHandshakeReady',
    context: context,
  );

  @override
  bool get receiverHandshakeReady {
    _$receiverHandshakeReadyAtom.reportRead();
    return super.receiverHandshakeReady;
  }

  @override
  set receiverHandshakeReady(bool value) {
    _$receiverHandshakeReadyAtom.reportWrite(
      value,
      super.receiverHandshakeReady,
      () {
        super.receiverHandshakeReady = value;
      },
    );
  }

  late final _$bleCentralStatusAtom = Atom(
    name: 'TransferStoreBase.bleCentralStatus',
    context: context,
  );

  @override
  BleCentralStatus get bleCentralStatus {
    _$bleCentralStatusAtom.reportRead();
    return super.bleCentralStatus;
  }

  @override
  set bleCentralStatus(BleCentralStatus value) {
    _$bleCentralStatusAtom.reportWrite(value, super.bleCentralStatus, () {
      super.bleCentralStatus = value;
    });
  }

  late final _$bleCentralMessageAtom = Atom(
    name: 'TransferStoreBase.bleCentralMessage',
    context: context,
  );

  @override
  String get bleCentralMessage {
    _$bleCentralMessageAtom.reportRead();
    return super.bleCentralMessage;
  }

  @override
  set bleCentralMessage(String value) {
    _$bleCentralMessageAtom.reportWrite(value, super.bleCentralMessage, () {
      super.bleCentralMessage = value;
    });
  }

  late final _$blePeripheralIdAtom = Atom(
    name: 'TransferStoreBase.blePeripheralId',
    context: context,
  );

  @override
  String? get blePeripheralId {
    _$blePeripheralIdAtom.reportRead();
    return super.blePeripheralId;
  }

  @override
  set blePeripheralId(String? value) {
    _$blePeripheralIdAtom.reportWrite(value, super.blePeripheralId, () {
      super.blePeripheralId = value;
    });
  }

  late final _$bleRssiAtom = Atom(
    name: 'TransferStoreBase.bleRssi',
    context: context,
  );

  @override
  int? get bleRssi {
    _$bleRssiAtom.reportRead();
    return super.bleRssi;
  }

  @override
  set bleRssi(int? value) {
    _$bleRssiAtom.reportWrite(value, super.bleRssi, () {
      super.bleRssi = value;
    });
  }

  late final _$negotiatedMtuAtom = Atom(
    name: 'TransferStoreBase.negotiatedMtu',
    context: context,
  );

  @override
  int? get negotiatedMtu {
    _$negotiatedMtuAtom.reportRead();
    return super.negotiatedMtu;
  }

  @override
  set negotiatedMtu(int? value) {
    _$negotiatedMtuAtom.reportWrite(value, super.negotiatedMtu, () {
      super.negotiatedMtu = value;
    });
  }

  late final _$receivedMessageIdAtom = Atom(
    name: 'TransferStoreBase.receivedMessageId',
    context: context,
  );

  @override
  String? get receivedMessageId {
    _$receivedMessageIdAtom.reportRead();
    return super.receivedMessageId;
  }

  @override
  set receivedMessageId(String? value) {
    _$receivedMessageIdAtom.reportWrite(value, super.receivedMessageId, () {
      super.receivedMessageId = value;
    });
  }

  late final _$receivedDataAtom = Atom(
    name: 'TransferStoreBase.receivedData',
    context: context,
  );

  @override
  String? get receivedData {
    _$receivedDataAtom.reportRead();
    return super.receivedData;
  }

  @override
  set receivedData(String? value) {
    _$receivedDataAtom.reportWrite(value, super.receivedData, () {
      super.receivedData = value;
    });
  }

  late final _$blePeripheralStatusAtom = Atom(
    name: 'TransferStoreBase.blePeripheralStatus',
    context: context,
  );

  @override
  BlePeripheralStatus get blePeripheralStatus {
    _$blePeripheralStatusAtom.reportRead();
    return super.blePeripheralStatus;
  }

  @override
  set blePeripheralStatus(BlePeripheralStatus value) {
    _$blePeripheralStatusAtom.reportWrite(value, super.blePeripheralStatus, () {
      super.blePeripheralStatus = value;
    });
  }

  late final _$blePeripheralMessageAtom = Atom(
    name: 'TransferStoreBase.blePeripheralMessage',
    context: context,
  );

  @override
  String get blePeripheralMessage {
    _$blePeripheralMessageAtom.reportRead();
    return super.blePeripheralMessage;
  }

  @override
  set blePeripheralMessage(String value) {
    _$blePeripheralMessageAtom.reportWrite(
      value,
      super.blePeripheralMessage,
      () {
        super.blePeripheralMessage = value;
      },
    );
  }

  late final _$connectedCentralIdAtom = Atom(
    name: 'TransferStoreBase.connectedCentralId',
    context: context,
  );

  @override
  String? get connectedCentralId {
    _$connectedCentralIdAtom.reportRead();
    return super.connectedCentralId;
  }

  @override
  set connectedCentralId(String? value) {
    _$connectedCentralIdAtom.reportWrite(value, super.connectedCentralId, () {
      super.connectedCentralId = value;
    });
  }

  late final _$outgoingPlainTextAtom = Atom(
    name: 'TransferStoreBase.outgoingPlainText',
    context: context,
  );

  @override
  String get outgoingPlainText {
    _$outgoingPlainTextAtom.reportRead();
    return super.outgoingPlainText;
  }

  @override
  set outgoingPlainText(String value) {
    _$outgoingPlainTextAtom.reportWrite(value, super.outgoingPlainText, () {
      super.outgoingPlainText = value;
    });
  }

  late final _$activeRoleAtom = Atom(
    name: 'TransferStoreBase.activeRole',
    context: context,
  );

  @override
  TransferRole get activeRole {
    _$activeRoleAtom.reportRead();
    return super.activeRole;
  }

  @override
  set activeRole(TransferRole value) {
    _$activeRoleAtom.reportWrite(value, super.activeRole, () {
      super.activeRole = value;
    });
  }

  late final _$startSendFlowAsyncAction = AsyncAction(
    'TransferStoreBase.startSendFlow',
    context: context,
  );

  @override
  Future<void> startSendFlow() {
    return _$startSendFlowAsyncAction.run(() => super.startSendFlow());
  }

  late final _$createSignedInvitationAsyncAction = AsyncAction(
    'TransferStoreBase.createSignedInvitation',
    context: context,
  );

  @override
  Future<void> createSignedInvitation() {
    return _$createSignedInvitationAsyncAction.run(
      () => super.createSignedInvitation(),
    );
  }

  late final _$startReceiveFlowAsyncAction = AsyncAction(
    'TransferStoreBase.startReceiveFlow',
    context: context,
  );

  @override
  Future<void> startReceiveFlow(String scannedJson) {
    return _$startReceiveFlowAsyncAction.run(
      () => super.startReceiveFlow(scannedJson),
    );
  }

  late final _$validateScannedInvitationAsyncAction = AsyncAction(
    'TransferStoreBase.validateScannedInvitation',
    context: context,
  );

  @override
  Future<void> validateScannedInvitation(String scannedJson) {
    return _$validateScannedInvitationAsyncAction.run(
      () => super.validateScannedInvitation(scannedJson),
    );
  }

  late final _$searchAndConnectToSenderAsyncAction = AsyncAction(
    'TransferStoreBase.searchAndConnectToSender',
    context: context,
  );

  @override
  Future<void> searchAndConnectToSender() {
    return _$searchAndConnectToSenderAsyncAction.run(
      () => super.searchAndConnectToSender(),
    );
  }

  late final _$confirmBleSessionAsyncAction = AsyncAction(
    'TransferStoreBase.confirmBleSession',
    context: context,
  );

  @override
  Future<void> confirmBleSession() {
    return _$confirmBleSessionAsyncAction.run(() => super.confirmBleSession());
  }

  late final _$exchangeEcdhKeysAsyncAction = AsyncAction(
    'TransferStoreBase.exchangeEcdhKeys',
    context: context,
  );

  @override
  Future<void> exchangeEcdhKeys() {
    return _$exchangeEcdhKeysAsyncAction.run(() => super.exchangeEcdhKeys());
  }

  late final _$stopBleCentralAsyncAction = AsyncAction(
    'TransferStoreBase.stopBleCentral',
    context: context,
  );

  @override
  Future<void> stopBleCentral() {
    return _$stopBleCentralAsyncAction.run(() => super.stopBleCentral());
  }

  late final _$startBlePeripheralAsyncAction = AsyncAction(
    'TransferStoreBase.startBlePeripheral',
    context: context,
  );

  @override
  Future<void> startBlePeripheral() {
    return _$startBlePeripheralAsyncAction.run(
      () => super.startBlePeripheral(),
    );
  }

  late final _$stopBlePeripheralAsyncAction = AsyncAction(
    'TransferStoreBase.stopBlePeripheral',
    context: context,
  );

  @override
  Future<void> stopBlePeripheral() {
    return _$stopBlePeripheralAsyncAction.run(() => super.stopBlePeripheral());
  }

  late final _$sendEncryptedDataAsyncAction = AsyncAction(
    'TransferStoreBase.sendEncryptedData',
    context: context,
  );

  @override
  Future<void> sendEncryptedData() {
    return _$sendEncryptedDataAsyncAction.run(() => super.sendEncryptedData());
  }

  late final _$closeSendFlowAsyncAction = AsyncAction(
    'TransferStoreBase.closeSendFlow',
    context: context,
  );

  @override
  Future<void> closeSendFlow() {
    return _$closeSendFlowAsyncAction.run(() => super.closeSendFlow());
  }

  late final _$closeReceiveFlowAsyncAction = AsyncAction(
    'TransferStoreBase.closeReceiveFlow',
    context: context,
  );

  @override
  Future<void> closeReceiveFlow() {
    return _$closeReceiveFlowAsyncAction.run(() => super.closeReceiveFlow());
  }

  late final _$TransferStoreBaseActionController = ActionController(
    name: 'TransferStoreBase',
    context: context,
  );

  @override
  void _applyBleState(BleCentralState state) {
    final _$actionInfo = _$TransferStoreBaseActionController.startAction(
      name: 'TransferStoreBase._applyBleState',
    );
    try {
      return super._applyBleState(state);
    } finally {
      _$TransferStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void _applyPeripheralState(BlePeripheralState state) {
    final _$actionInfo = _$TransferStoreBaseActionController.startAction(
      name: 'TransferStoreBase._applyPeripheralState',
    );
    try {
      return super._applyPeripheralState(state);
    } finally {
      _$TransferStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void updateOutgoingPlainText(String value) {
    final _$actionInfo = _$TransferStoreBaseActionController.startAction(
      name: 'TransferStoreBase.updateOutgoingPlainText',
    );
    try {
      return super.updateOutgoingPlainText(value);
    } finally {
      _$TransferStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
isLoading: ${isLoading},
message: ${message},
errorMessage: ${errorMessage},
invitationJson: ${invitationJson},
generatedSessionId: ${generatedSessionId},
invitationExpiresAtEpochMillis: ${invitationExpiresAtEpochMillis},
scannedSessionId: ${scannedSessionId},
scannedDeviceId: ${scannedDeviceId},
receiverHandshakeJson: ${receiverHandshakeJson},
receiverSessionKeyFingerprint: ${receiverSessionKeyFingerprint},
receiverHandshakeReady: ${receiverHandshakeReady},
bleCentralStatus: ${bleCentralStatus},
bleCentralMessage: ${bleCentralMessage},
blePeripheralId: ${blePeripheralId},
bleRssi: ${bleRssi},
negotiatedMtu: ${negotiatedMtu},
receivedMessageId: ${receivedMessageId},
receivedData: ${receivedData},
blePeripheralStatus: ${blePeripheralStatus},
blePeripheralMessage: ${blePeripheralMessage},
connectedCentralId: ${connectedCentralId},
outgoingPlainText: ${outgoingPlainText},
activeRole: ${activeRole},
hasGeneratedInvitation: ${hasGeneratedInvitation},
canSearchBleSender: ${canSearchBleSender},
canConfirmBleSession: ${canConfirmBleSession},
canExchangeEcdh: ${canExchangeEcdh},
canStopBleCentral: ${canStopBleCentral},
canStartBlePeripheral: ${canStartBlePeripheral},
canStopBlePeripheral: ${canStopBlePeripheral},
canSendEncryptedData: ${canSendEncryptedData},
canStartSendFlow: ${canStartSendFlow},
canStartReceiveFlow: ${canStartReceiveFlow},
canCloseSendFlow: ${canCloseSendFlow},
canCloseReceiveFlow: ${canCloseReceiveFlow}
    ''';
  }
}
