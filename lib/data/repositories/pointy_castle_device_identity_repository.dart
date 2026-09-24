import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

import '../../core/crypto/p256_interop_codec.dart';
import '../../domain/entities/device_identity.dart';
import '../../domain/repositories/device_identity_repository.dart';
import '../local/identity_key_store.dart';

class PointyCastleDeviceIdentityRepository implements DeviceIdentityRepository {
  PointyCastleDeviceIdentityRepository({required this._keyStore});

  final IdentityKeyStore _keyStore;

  final ECDomainParameters _domain = ECDomainParameters('prime256v1');

  _IdentityMaterial? _cachedMaterial;

  @override
  Future<DeviceIdentity> getOrCreateIdentity() async {
    final result = await _loadOrCreateMaterial();

    return DeviceIdentity(
      publicKey: P256InteropCodec.encodePublicKeyBase64Url(
        x: result.material.x,
        y: result.material.y,
      ),
      wasCreated: result.wasCreated,
    );
  }

  @override
  Future<List<int>> sign(List<int> data) async {
    final result = await _loadOrCreateMaterial();
    final material = result.material;

    final privateKey = ECPrivateKey(_bytesToBigInt(material.d), _domain);

    final signer = Signer('SHA-256/DET-ECDSA');

    signer.init(true, PrivateKeyParameter<ECPrivateKey>(privateKey));

    final signature =
        signer.generateSignature(Uint8List.fromList(data)) as ECSignature;

    final rawSignature = Uint8List.fromList([
      ..._bigIntToFixedBytes(signature.r, P256InteropCodec.coordinateLength),
      ..._bigIntToFixedBytes(signature.s, P256InteropCodec.coordinateLength),
    ]);

    // Kotlin SHA256withECDSA utiliza una firma ASN.1 DER.
    return P256InteropCodec.rawSignatureToDer(rawSignature);
  }

  @override
  Future<bool> verify({
    required List<int> data,
    required List<int> signature,
    required String publicKey,
  }) async {
    try {
      final coordinates = P256InteropCodec.decodePublicKeyBase64Url(publicKey);

      final point = _domain.curve.createPoint(
        _bytesToBigInt(coordinates.x),
        _bytesToBigInt(coordinates.y),
      );

      final ecPublicKey = ECPublicKey(point, _domain);

      final rawSignature = P256InteropCodec.derSignatureToRaw(signature);

      final r = _bytesToBigInt(
        rawSignature.sublist(0, P256InteropCodec.coordinateLength),
      );

      final s = _bytesToBigInt(
        rawSignature.sublist(P256InteropCodec.coordinateLength),
      );

      final signer = Signer('SHA-256/DET-ECDSA');

      signer.init(false, PublicKeyParameter<ECPublicKey>(ecPublicKey));

      return signer.verifySignature(
        Uint8List.fromList(data),
        ECSignature(r, s),
      );
    } on Object {
      return false;
    }
  }

  Future<_MaterialLoadResult> _loadOrCreateMaterial() async {
    final cached = _cachedMaterial;

    if (cached != null) {
      return _MaterialLoadResult(material: cached, wasCreated: false);
    }

    final storedValue = await _keyStore.read();

    if (storedValue != null && storedValue.isNotEmpty) {
      final material = _decodeStoredMaterial(storedValue);

      _validateMaterial(material);
      _cachedMaterial = material;

      return _MaterialLoadResult(material: material, wasCreated: false);
    }

    final material = _generateMaterial();

    await _keyStore.write(_encodeStoredMaterial(material));

    _cachedMaterial = material;

    return _MaterialLoadResult(material: material, wasCreated: true);
  }

  _IdentityMaterial _generateMaterial() {
    final secureRandom = FortunaRandom();

    secureRandom.seed(KeyParameter(_generateSecureBytes(32)));

    final generator = ECKeyGenerator();

    generator.init(
      ParametersWithRandom(ECKeyGeneratorParameters(_domain), secureRandom),
    );

    final keyPair = generator.generateKeyPair();

    final privateKey = keyPair.privateKey;

    final publicKey = keyPair.publicKey;

    final privateValue = privateKey.d;
    final publicPoint = publicKey.Q;

    if (privateValue == null || publicPoint == null) {
      throw StateError('No fue posible generar la identidad P-256');
    }

    final x = publicPoint.x?.toBigInteger();
    final y = publicPoint.y?.toBigInteger();

    if (x == null || y == null) {
      throw StateError('La clave pública P-256 no contiene coordenadas');
    }

    return _IdentityMaterial(
      d: _bigIntToFixedBytes(privateValue, P256InteropCodec.coordinateLength),
      x: _bigIntToFixedBytes(x, P256InteropCodec.coordinateLength),
      y: _bigIntToFixedBytes(y, P256InteropCodec.coordinateLength),
    );
  }

  void _validateMaterial(_IdentityMaterial material) {
    if (material.d.length != P256InteropCodec.coordinateLength ||
        material.x.length != P256InteropCodec.coordinateLength ||
        material.y.length != P256InteropCodec.coordinateLength) {
      throw const FormatException('La identidad P-256 guardada es inválida');
    }

    // createPoint también valida que las coordenadas
    // puedan ser utilizadas por la curva.
    _domain.curve.createPoint(
      _bytesToBigInt(material.x),
      _bytesToBigInt(material.y),
    );
  }

  String _encodeStoredMaterial(_IdentityMaterial material) {
    return jsonEncode({
      'd': _encodeBase64Url(material.d),
      'x': _encodeBase64Url(material.x),
      'y': _encodeBase64Url(material.y),
    });
  }

  _IdentityMaterial _decodeStoredMaterial(String value) {
    final decoded = jsonDecode(value);

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('La identidad guardada no es un JSON válido');
    }

    final d = decoded['d'];
    final x = decoded['x'];
    final y = decoded['y'];

    if (d is! String || x is! String || y is! String) {
      throw const FormatException('La identidad guardada está incompleta');
    }

    return _IdentityMaterial(
      d: _decodeBase64Url(d),
      x: _decodeBase64Url(x),
      y: _decodeBase64Url(y),
    );
  }

  Uint8List _generateSecureBytes(int length) {
    final random = Random.secure();

    return Uint8List.fromList(
      List<int>.generate(length, (_) => random.nextInt(256)),
    );
  }

  String _encodeBase64Url(List<int> bytes) {
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  Uint8List _decodeBase64Url(String value) {
    final remainder = value.length % 4;

    final normalized = switch (remainder) {
      0 => value,
      2 => '$value==',
      3 => '$value=',
      _ => throw const FormatException('Base64 URL-safe inválido'),
    };

    return Uint8List.fromList(base64Url.decode(normalized));
  }

  static BigInt _bytesToBigInt(List<int> bytes) {
    var result = BigInt.zero;

    for (final byte in bytes) {
      result = (result << 8) | BigInt.from(byte);
    }

    return result;
  }

  static Uint8List _bigIntToFixedBytes(BigInt value, int length) {
    if (value.isNegative) {
      throw const FormatException('No se admiten números negativos');
    }

    final output = Uint8List(length);
    var remaining = value;

    for (var index = length - 1; index >= 0; index--) {
      output[index] = (remaining & BigInt.from(0xFF)).toInt();

      remaining >>= 8;
    }

    if (remaining != BigInt.zero) {
      throw const FormatException('El número no cabe en la longitud indicada');
    }

    return output;
  }
}

class _IdentityMaterial {
  _IdentityMaterial({
    required List<int> d,
    required List<int> x,
    required List<int> y,
  }) : d = Uint8List.fromList(d),
       x = Uint8List.fromList(x),
       y = Uint8List.fromList(y);

  final Uint8List d;
  final Uint8List x;
  final Uint8List y;
}

class _MaterialLoadResult {
  const _MaterialLoadResult({required this.material, required this.wasCreated});

  final _IdentityMaterial material;
  final bool wasCreated;
}
