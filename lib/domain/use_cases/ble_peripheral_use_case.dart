import '../entities/ble_peripheral_state.dart';
import '../repositories/ble_peripheral_repository.dart';

class BlePeripheralUseCase {
  const BlePeripheralUseCase({required this._repository});

  final BlePeripheralRepository _repository;

  BlePeripheralState get state => _repository.state;

  Stream<BlePeripheralState> get states => _repository.states;

  Stream<String> get receivedTexts => _repository.receivedTexts;

  Future<void> startAdvertising(String sessionId) {
    return _repository.startAdvertising(sessionId);
  }

  Future<void> sendEncryptedData(String plainText) {
    return _repository.sendEncryptedData(plainText);
  }

  Future<void> stopAdvertising() {
    return _repository.stopAdvertising();
  }
}
