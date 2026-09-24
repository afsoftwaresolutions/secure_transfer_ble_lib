import 'package:flutter_test/flutter_test.dart';
import 'package:secure_transfer_poc_flutter/core/crypto/p256_interop_codec.dart';

void main() {
  group('P256InteropCodec', () {
    test('codifica y recupera una clave pública P-256 X.509', () {
      final x = List<int>.generate(32, (index) => index + 1);

      final y = List<int>.generate(32, (index) => index + 33);

      final encoded = P256InteropCodec.encodeX509PublicKey(x: x, y: y);

      expect(encoded.length, 91);

      final decoded = P256InteropCodec.decodeX509PublicKey(encoded);

      expect(decoded.x, x);
      expect(decoded.y, y);
    });

    test('Base64 URL-safe no contiene padding', () {
      final x = List<int>.filled(32, 1);
      final y = List<int>.filled(32, 2);

      final encoded = P256InteropCodec.encodePublicKeyBase64Url(x: x, y: y);

      expect(encoded.contains('='), isFalse);

      final decoded = P256InteropCodec.decodePublicKeyBase64Url(encoded);

      expect(decoded.x, x);
      expect(decoded.y, y);
    });

    test('convierte una firma ECDSA raw a DER y regresa', () {
      final rawSignature = List<int>.filled(64, 0);

      // Obliga a DER a agregar un 00 para evitar
      // interpretar R como un número negativo.
      rawSignature[0] = 0x80;
      rawSignature[31] = 0x01;

      // S tendrá ceros iniciales que DER puede eliminar.
      rawSignature[63] = 0x02;

      final derSignature = P256InteropCodec.rawSignatureToDer(rawSignature);

      expect(derSignature.first, 0x30);

      final recoveredRaw = P256InteropCodec.derSignatureToRaw(derSignature);

      expect(recoveredRaw, rawSignature);
    });

    test('rechaza una firma raw con longitud incorrecta', () {
      expect(
        () => P256InteropCodec.rawSignatureToDer(List<int>.filled(63, 0)),
        throwsFormatException,
      );
    });

    test('rechaza una clave pública X.509 inválida', () {
      expect(
        () => P256InteropCodec.decodeX509PublicKey(List<int>.filled(91, 0)),
        throwsFormatException,
      );
    });
  });
}
