import 'dart:typed_data';

import 'package:pointycastle/export.dart';

abstract final class HkdfSha256 {
  static const int _hashLength = 32;
  static const int _hmacBlockSize = 64;

  static Uint8List deriveKey({
    required List<int> inputKeyMaterial,
    required List<int> salt,
    required List<int> info,
  }) {
    final effectiveSalt = salt.isEmpty
        ? Uint8List(_hashLength)
        : Uint8List.fromList(salt);

    // HKDF-Extract
    final pseudoRandomKey = _hmac(key: effectiveSalt, data: inputKeyMaterial);

    // HKDF-Expand.
    // Un bloque SHA-256 produce los 32 bytes de AES-256.
    final outputKey = _hmac(key: pseudoRandomKey, data: <int>[...info, 1]);

    _clear(pseudoRandomKey);

    return outputKey;
  }

  static Uint8List _hmac({required List<int> key, required List<int> data}) {
    final hmac = HMac(SHA256Digest(), _hmacBlockSize);

    hmac.init(KeyParameter(Uint8List.fromList(key)));

    return hmac.process(Uint8List.fromList(data));
  }

  static void _clear(Uint8List bytes) {
    bytes.fillRange(0, bytes.length, 0);
  }
}
