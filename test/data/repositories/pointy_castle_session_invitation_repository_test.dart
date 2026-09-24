import 'package:flutter_test/flutter_test.dart';
import 'package:secure_transfer_poc_flutter/data/local/identity_key_store.dart';
import 'package:secure_transfer_poc_flutter/data/repositories/pointy_castle_device_identity_repository.dart';
import 'package:secure_transfer_poc_flutter/data/repositories/pointy_castle_session_invitation_repository.dart';
import 'package:secure_transfer_poc_flutter/domain/entities/session_invitation.dart';

void main() {
  group('PointyCastleSessionInvitationRepository', () {
    test('crea una invitación firmada y válida', () async {
      final repository = _createRepository();

      final invitation = await repository.createSenderInvitation();

      expect(invitation.protocolVersion, 1);

      expect(invitation.sourceApp, 'SECURE_TRANSFER_POC_KOTLIN');

      expect(invitation.sessionId, isNotEmpty);
      expect(invitation.nonce, isNotEmpty);
      expect(invitation.identityPublicKey, isNotEmpty);
      expect(invitation.ephemeralPublicKey, isNotEmpty);
      expect(invitation.signature, isNotEmpty);

      expect(repository.isActiveSession(invitation.sessionId), isTrue);

      expect(await repository.verifyInvitation(invitation), isTrue);
    });

    test('rechaza una invitación modificada', () async {
      final repository = _createRepository();

      final original = await repository.createSenderInvitation();

      final modified = SessionInvitation(
        protocolVersion: original.protocolVersion,
        sessionId: '${original.sessionId}-modificado',
        sourceApp: original.sourceApp,
        sourceDeviceId: original.sourceDeviceId,
        createdAtEpochMillis: original.createdAtEpochMillis,
        expiresAtEpochMillis: original.expiresAtEpochMillis,
        nonce: original.nonce,
        identityPublicKey: original.identityPublicKey,
        ephemeralPublicKey: original.ephemeralPublicKey,
        signature: original.signature,
      );

      expect(await repository.verifyInvitation(modified), isFalse);
    });

    test('marca como inactiva una sesión expirada', () async {
      var currentTime = 1000000;

      final repository = _createRepository(
        currentTimeMillis: () => currentTime,
      );

      final invitation = await repository.createSenderInvitation();

      expect(repository.isActiveSession(invitation.sessionId), isTrue);

      currentTime += (2 * 60 * 1000) + 1;

      expect(repository.isActiveSession(invitation.sessionId), isFalse);
    });

    test('rechaza una invitación firmada de otra aplicación', () async {
      final interapp = _createRepository(appId: 'INTERAPP');
      final appController = _createRepository(appId: 'APP_CONTROLLER');

      final invitation = await interapp.createSenderInvitation();

      expect(await interapp.verifyInvitation(invitation), isTrue);
      expect(await appController.verifyInvitation(invitation), isFalse);
    });

  });
}

PointyCastleSessionInvitationRepository _createRepository({
  String appId = PointyCastleSessionInvitationRepository.defaultAppId,
  int Function()? currentTimeMillis,
}) {
  final identityRepository = PointyCastleDeviceIdentityRepository(
    keyStore: _MemoryIdentityKeyStore(),
  );

  return PointyCastleSessionInvitationRepository(
    identityRepository: identityRepository,
    appId: appId,
    currentTimeMillis: currentTimeMillis,
  );
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
