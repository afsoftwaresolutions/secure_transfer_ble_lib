import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:secure_transfer_poc_flutter/core/protocol/ir_transfer_protocol.dart';
import 'package:secure_transfer_poc_flutter/core/protocol/session_invitation_codec.dart';
import 'package:secure_transfer_poc_flutter/domain/entities/session_invitation.dart';

void main() {
  const codec = SessionInvitationCodec();

  const invitation = SessionInvitation(
    protocolVersion: 1,
    sessionId: 'e06c8c35-4d1c-4ae1-95ee-a70d1bdf0997',
    sourceApp: IrTransferProtocol.sourceApp,
    sourceDeviceId: 'DEVICE-001',
    createdAtEpochMillis: 1789552800000,
    expiresAtEpochMillis: 1789552920000,
    nonce: 'NONCE_BASE64URL',
    identityPublicKey: 'IDENTITY_PUBLIC_KEY',
    ephemeralPublicKey: 'EPHEMERAL_PUBLIC_KEY',
    signature: 'SIGNATURE_BASE64URL',
  );

  group('SessionInvitationCodec', () {
    test('produce exactamente el contenido canónico de Kotlin', () {
      final canonicalContent = utf8.decode(invitation.signingBytes());

      expect(
        canonicalContent,
        '1:1|'
        '36:e06c8c35-4d1c-4ae1-95ee-a70d1bdf0997|'
        '26:SECURE_TRANSFER_POC_KOTLIN|'
        '10:DEVICE-001|'
        '13:1789552800000|'
        '13:1789552920000|'
        '15:NONCE_BASE64URL|'
        '19:IDENTITY_PUBLIC_KEY|'
        '20:EPHEMERAL_PUBLIC_KEY',
      );
    });

    test('no incluye la firma dentro de signingBytes', () {
      final firstInvitation = invitation.copyWith(signature: 'SIGNATURE_ONE');

      final secondInvitation = invitation.copyWith(signature: 'SIGNATURE_TWO');

      expect(firstInvitation.signingBytes(), secondInvitation.signingBytes());
    });

    test('calcula las longitudes utilizando bytes UTF-8', () {
      final invitationWithUnicode = invitation.copyWith(
        sourceDeviceId: 'MÓVIL-📱',
      );

      final canonicalContent = utf8.decode(
        invitationWithUnicode.signingBytes(),
      );

      /*
        * MÓVIL-📱 contiene:
        *
        * M       = 1 byte
        * Ó       = 2 bytes
        * VIL-    = 4 bytes
        * 📱      = 4 bytes
        *
        * Total   = 11 bytes UTF-8
        */
      expect(canonicalContent, contains('11:MÓVIL-📱'));
    });

    test('cambiar un campo firmado cambia signingBytes', () {
      final modifiedInvitation = invitation.copyWith(
        sourceDeviceId: 'DEVICE-002',
      );

      expect(
        invitation.signingBytes(),
        isNot(modifiedInvitation.signingBytes()),
      );
    });

    test('codifica los campos en el orden de Kotlin', () {
      final result = codec.encode(invitation);

      expect(
        result,
        '{"protocolVersion":1,'
        '"sessionId":'
        '"e06c8c35-4d1c-4ae1-95ee-a70d1bdf0997",'
        '"sourceApp":"SECURE_TRANSFER_POC_KOTLIN",'
        '"sourceDeviceId":"DEVICE-001",'
        '"createdAtEpochMillis":1789552800000,'
        '"expiresAtEpochMillis":1789552920000,'
        '"nonce":"NONCE_BASE64URL",'
        '"identityPublicKey":"IDENTITY_PUBLIC_KEY",'
        '"ephemeralPublicKey":"EPHEMERAL_PUBLIC_KEY",'
        '"signature":"SIGNATURE_BASE64URL"}',
      );
    });

    test('decodifica una invitación completa', () {
      final encoded = codec.encode(invitation);
      final decoded = codec.decode(encoded);

      expect(decoded.protocolVersion, invitation.protocolVersion);
      expect(decoded.sessionId, invitation.sessionId);
      expect(decoded.sourceApp, invitation.sourceApp);
      expect(decoded.sourceDeviceId, invitation.sourceDeviceId);
      expect(decoded.createdAtEpochMillis, invitation.createdAtEpochMillis);
      expect(decoded.expiresAtEpochMillis, invitation.expiresAtEpochMillis);
      expect(decoded.nonce, invitation.nonce);
      expect(decoded.identityPublicKey, invitation.identityPublicKey);
      expect(decoded.ephemeralPublicKey, invitation.ephemeralPublicKey);
      expect(decoded.signature, invitation.signature);
    });

    test('codifica nuevamente el mismo JSON', () {
      final firstJson = codec.encode(invitation);

      final decoded = codec.decode(firstJson);
      final secondJson = codec.encode(decoded);

      expect(secondJson, firstJson);
    });

    test('permite agregar la firma con copyWith', () {
      final unsignedInvitation = invitation.copyWith(signature: '');

      final signedInvitation = unsignedInvitation.copyWith(
        signature: 'NEW_SIGNATURE',
      );

      expect(unsignedInvitation.signature, isEmpty);
      expect(signedInvitation.signature, 'NEW_SIGNATURE');
    });

    test('rechaza contenido vacío', () {
      expect(() => codec.decode(''), throwsFormatException);
    });

    test('rechaza un JSON que no sea objeto', () {
      expect(() => codec.decode('["invalid"]'), throwsFormatException);
    });

    test('rechaza invitación con campos faltantes', () {
      expect(
        () => codec.decode('{"protocolVersion":1}'),
        throwsFormatException,
      );
    });
  });
}
