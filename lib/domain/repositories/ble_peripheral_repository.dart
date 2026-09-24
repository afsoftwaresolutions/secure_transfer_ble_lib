import '../entities/ble_peripheral_state.dart';

abstract interface class BlePeripheralRepository {
  BlePeripheralState get state;

  Stream<BlePeripheralState> get states;

  Future<void> startAdvertising(String sessionId);

  Future<void> sendEncryptedData(String plainText);

  Future<void> stopAdvertising();

  Future<void> dispose();
}
