import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'identity_key_store.dart';

class FlutterSecureIdentityKeyStore implements IdentityKeyStore {
  const FlutterSecureIdentityKeyStore({required this._storage});

  static const String _storageKey = 'ir_transfer_identity_p256_v1';

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() {
    return _storage.read(key: _storageKey);
  }

  @override
  Future<void> write(String value) {
    return _storage.write(key: _storageKey, value: value);
  }
}
