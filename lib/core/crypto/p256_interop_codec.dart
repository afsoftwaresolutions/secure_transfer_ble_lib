import 'dart:convert';
import 'dart:typed_data';

class P256PublicCoordinates {
  P256PublicCoordinates({required List<int> x, required List<int> y})
    : x = Uint8List.fromList(x),
      y = Uint8List.fromList(y);

  final Uint8List x;
  final Uint8List y;
}

abstract final class P256InteropCodec {
  static const int coordinateLength = 32;
  static const int rawSignatureLength = 64;

  static const List<int> _x509Prefix = <int>[
    0x30,
    0x59,
    0x30,
    0x13,
    0x06,
    0x07,
    0x2A,
    0x86,
    0x48,
    0xCE,
    0x3D,
    0x02,
    0x01,
    0x06,
    0x08,
    0x2A,
    0x86,
    0x48,
    0xCE,
    0x3D,
    0x03,
    0x01,
    0x07,
    0x03,
    0x42,
    0x00,
    0x04,
  ];

  static Uint8List encodeX509PublicKey({
    required List<int> x,
    required List<int> y,
  }) {
    final normalizedX = _normalizeCoordinate(x);
    final normalizedY = _normalizeCoordinate(y);

    return Uint8List.fromList([..._x509Prefix, ...normalizedX, ...normalizedY]);
  }

  static P256PublicCoordinates decodeX509PublicKey(List<int> encoded) {
    final expectedLength = _x509Prefix.length + (coordinateLength * 2);

    if (encoded.length != expectedLength) {
      throw const FormatException(
        'La clave pública P-256 X.509 tiene longitud inválida',
      );
    }

    for (var index = 0; index < _x509Prefix.length; index++) {
      if (encoded[index] != _x509Prefix[index]) {
        throw const FormatException(
          'La clave pública no usa el formato P-256 esperado',
        );
      }
    }

    final xStart = _x509Prefix.length;
    final yStart = xStart + coordinateLength;

    return P256PublicCoordinates(
      x: encoded.sublist(xStart, yStart),
      y: encoded.sublist(yStart, yStart + coordinateLength),
    );
  }

  static String encodePublicKeyBase64Url({
    required List<int> x,
    required List<int> y,
  }) {
    final encoded = encodeX509PublicKey(x: x, y: y);

    return base64Url.encode(encoded).replaceAll('=', '');
  }

  static P256PublicCoordinates decodePublicKeyBase64Url(String publicKey) {
    final normalized = _normalizeBase64Url(publicKey);
    final encoded = base64Url.decode(normalized);

    return decodeX509PublicKey(encoded);
  }

  static Uint8List rawSignatureToDer(List<int> rawSignature) {
    if (rawSignature.length != rawSignatureLength) {
      throw const FormatException('La firma ECDSA raw debe contener 64 bytes');
    }

    final r = _encodeDerInteger(rawSignature.sublist(0, coordinateLength));

    final s = _encodeDerInteger(
      rawSignature.sublist(coordinateLength, rawSignatureLength),
    );

    final sequenceLength = 2 + r.length + 2 + s.length;

    return Uint8List.fromList([
      0x30,
      sequenceLength,
      0x02,
      r.length,
      ...r,
      0x02,
      s.length,
      ...s,
    ]);
  }

  static Uint8List derSignatureToRaw(List<int> derSignature) {
    if (derSignature.length < 8) {
      throw const FormatException('La firma DER es demasiado corta');
    }

    var index = 0;

    int readByte() {
      if (index >= derSignature.length) {
        throw const FormatException('La firma DER está incompleta');
      }

      return derSignature[index++];
    }

    List<int> readInteger() {
      if (readByte() != 0x02) {
        throw const FormatException('Se esperaba un INTEGER DER');
      }

      final length = readByte();

      if (length == 0 || index + length > derSignature.length) {
        throw const FormatException('INTEGER DER con longitud inválida');
      }

      final integer = derSignature.sublist(index, index + length);

      index += length;

      if ((integer.first & 0x80) != 0) {
        throw const FormatException('ECDSA DER contiene un INTEGER negativo');
      }

      var firstSignificantByte = 0;

      while (firstSignificantByte < integer.length - 1 &&
          integer[firstSignificantByte] == 0) {
        firstSignificantByte++;
      }

      final unsigned = integer.sublist(firstSignificantByte);

      if (unsigned.length > coordinateLength) {
        throw const FormatException('INTEGER ECDSA supera los 32 bytes');
      }

      return [
        ...List<int>.filled(coordinateLength - unsigned.length, 0),
        ...unsigned,
      ];
    }

    if (readByte() != 0x30) {
      throw const FormatException('La firma no es una secuencia DER');
    }

    final sequenceLength = readByte();

    if (sequenceLength != derSignature.length - 2) {
      throw const FormatException(
        'La longitud de la secuencia DER es inválida',
      );
    }

    final r = readInteger();
    final s = readInteger();

    if (index != derSignature.length) {
      throw const FormatException('La firma DER contiene datos adicionales');
    }

    return Uint8List.fromList([...r, ...s]);
  }

  static Uint8List _normalizeCoordinate(List<int> coordinate) {
    var firstSignificantByte = 0;

    while (coordinate.length - firstSignificantByte > coordinateLength &&
        coordinate[firstSignificantByte] == 0) {
      firstSignificantByte++;
    }

    final normalized = coordinate.sublist(firstSignificantByte);

    if (normalized.length > coordinateLength) {
      throw const FormatException('La coordenada P-256 supera los 32 bytes');
    }

    return Uint8List.fromList([
      ...List<int>.filled(coordinateLength - normalized.length, 0),
      ...normalized,
    ]);
  }

  static List<int> _encodeDerInteger(List<int> integer) {
    var firstSignificantByte = 0;

    while (firstSignificantByte < integer.length - 1 &&
        integer[firstSignificantByte] == 0) {
      firstSignificantByte++;
    }

    final unsigned = integer.sublist(firstSignificantByte);

    if ((unsigned.first & 0x80) != 0) {
      return [0, ...unsigned];
    }

    return unsigned;
  }

  static String _normalizeBase64Url(String value) {
    final remainder = value.length % 4;

    return switch (remainder) {
      0 => value,
      2 => '$value==',
      3 => '$value=',
      _ => throw const FormatException('Base64 URL-safe inválido'),
    };
  }
}
