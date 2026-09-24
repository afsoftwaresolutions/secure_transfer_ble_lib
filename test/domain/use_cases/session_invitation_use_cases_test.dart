import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:secure_transfer_poc_flutter/core/protocol/session_invitation_codec.dart';
import 'package:secure_transfer_poc_flutter/data/local/identity_key_store.dart';
import 'package:secure_transfer_poc_flutter/data/repositories/pointy_castle_device_identity_repository.dart';
import 'package:secure_transfer_poc_flutter/data/repositories/pointy_castle_session_invitation_repository.dart';
import 'package:secure_transfer_poc_flutter/domain/use_cases/create_signed_invitation_use_case.dart';
import 'package:secure_transfer_poc_flutter/domain/use_cases/validate_scanned_invitation_use_case.dart';

void main() {
  group('Session invitation use cases', () {
    test('crea JSON y después lo valida correctamente', () async {
      final repository = PointyCastleSessionInvitationRepository(
        identityRepository: PointyCastleDeviceIdentityRepository(
          keyStore: _MemoryIdentityKeyStore(),
        ),
      );

      final createUseCase = CreateSignedInvitationUseCase(
        repository: repository,
        codec: const SessionInvitationCodec(),
      );

      final validateUseCase = ValidateScannedInvitationUseCase(
        repository: repository,
        codec: const SessionInvitationCodec(),
      );

      final created = await createUseCase();

      expect(created.signatureValid, isTrue);
      expect(created.invitationJson, isNotEmpty);

      final decodedJson =
          jsonDecode(created.invitationJson) as Map<String, dynamic>;

      expect(decodedJson['protocolVersion'], 1);
      expect(decodedJson['sessionId'], created.invitation.sessionId);

      final scanned = await validateUseCase(created.invitationJson);

      expect(scanned.signatureValid, isTrue);

      expect(scanned.sessionId, created.invitation.sessionId);

      expect(
        scanned.senderEphemeralPublicKey,
        created.invitation.ephemeralPublicKey,
      );
    });

    test('rechaza un JSON modificado después de firmarlo', () async {
      final repository = PointyCastleSessionInvitationRepository(
        identityRepository: PointyCastleDeviceIdentityRepository(
          keyStore: _MemoryIdentityKeyStore(),
        ),
      );

      final createUseCase = CreateSignedInvitationUseCase(
        repository: repository,
        codec: const SessionInvitationCodec(),
      );

      final validateUseCase = ValidateScannedInvitationUseCase(
        repository: repository,
        codec: const SessionInvitationCodec(),
      );

      final created = await createUseCase();

      final decodedJson =
          jsonDecode(created.invitationJson) as Map<String, dynamic>;

      decodedJson['sessionId'] = '${decodedJson['sessionId']}-alterado';

      final alteredJson = jsonEncode(decodedJson);

      expect(() => validateUseCase(alteredJson), throwsFormatException);
    });

    test('rechaza un QR vacío', () async {
      final repository = PointyCastleSessionInvitationRepository(
        identityRepository: PointyCastleDeviceIdentityRepository(
          keyStore: _MemoryIdentityKeyStore(),
        ),
      );

      final validateUseCase = ValidateScannedInvitationUseCase(
        repository: repository,
        codec: const SessionInvitationCodec(),
      );

      expect(() => validateUseCase(''), throwsFormatException);
    });
  });
}

class _MemoryIdentityKeyStore implements IdentityKeyStore {
  String? value;

  @override
  Future<String?> read() async {
    return value;
  }

  @override
  Future<void> write(String value) async {
    this.value = value;
  }
}
