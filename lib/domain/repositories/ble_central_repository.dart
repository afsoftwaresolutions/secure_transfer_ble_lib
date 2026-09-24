import '../entities/ble_central_state.dart';

abstract interface class BleCentralRepository {
  BleCentralState get state;

  Stream<BleCentralState> get states;

  Future<void> scanAndConnect();

  Future<void> confirmSession(String sessionId);

  Future<void> sendReceiverHandshake({
    required String handshakeJson,
    required String sessionKeyFingerprint,
  });

  Future<void> disconnect();

  Future<void> dispose();
}
