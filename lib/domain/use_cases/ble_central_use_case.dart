import '../entities/ble_central_state.dart';
import '../repositories/ble_central_repository.dart';

class BleCentralUseCase {
  const BleCentralUseCase({required this._repository});

  final BleCentralRepository _repository;

  BleCentralState get state => _repository.state;

  Stream<BleCentralState> get states => _repository.states;

  Future<void> scanAndConnect() {
    return _repository.scanAndConnect();
  }

  Future<void> confirmSession(String sessionId) {
    return _repository.confirmSession(sessionId);
  }

  Future<void> sendReceiverHandshake({
    required String handshakeJson,
    required String sessionKeyFingerprint,
  }) {
    return _repository.sendReceiverHandshake(
      handshakeJson: handshakeJson,
      sessionKeyFingerprint: sessionKeyFingerprint,
    );
  }

  Future<void> disconnect() {
    return _repository.disconnect();
  }
}
