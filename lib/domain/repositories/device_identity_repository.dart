import '../entities/device_identity.dart';

abstract interface class DeviceIdentityRepository {
  Future<DeviceIdentity> getOrCreateIdentity();

  Future<List<int>> sign(List<int> data);

  Future<bool> verify({
    required List<int> data,
    required List<int> signature,
    required String publicKey,
  });
}
