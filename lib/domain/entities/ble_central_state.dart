enum BleCentralStatus {
  idle,
  requestingPermissions,
  scanning,
  connecting,
  negotiatingMtu,
  discoveringServices,
  enablingNotifications,
  serviceReady,
  verifyingSession,
  sessionVerified,
  exchangingEcdh,
  sessionKeyReady,
  dataReceiving,
  dataReceived,
  ackSending,
  ackSent,
  reverseAckReceived,
  sessionRejected,
  disconnected,
  error,
}

class BleCentralState {
  const BleCentralState({
    this.status = BleCentralStatus.idle,
    this.message = 'Cliente BLE detenido',
    this.peripheralId,
    this.rssi,
    this.negotiatedMtu,
    this.sessionKeyFingerprint,
    this.receivedMessageId,
    this.receivedData,
  });

  final BleCentralStatus status;
  final String message;
  final String? peripheralId;
  final int? rssi;
  final int? negotiatedMtu;
  final String? sessionKeyFingerprint;
  final String? receivedMessageId;
  final String? receivedData;
}
