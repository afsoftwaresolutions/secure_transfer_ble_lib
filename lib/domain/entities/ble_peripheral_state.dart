enum BlePeripheralStatus {
  idle,
  starting,
  advertising,
  connected,
  sessionVerified,
  receivingHandshake,
  sessionKeyReady,
  dataSending,
  waitingAck,
  dataConfirmed,
  sessionRejected,
  error,
}

class BlePeripheralState {
  const BlePeripheralState({
    this.status = BlePeripheralStatus.idle,
    this.message = 'Periférico BLE detenido',
    this.sessionId,
    this.centralId,
    this.sessionKeyFingerprint,
    this.messageId,
  });

  final BlePeripheralStatus status;

  final String message;

  final String? sessionId;

  final String? centralId;

  final String? sessionKeyFingerprint;

  final String? messageId;
}
