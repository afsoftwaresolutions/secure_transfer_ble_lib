import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:secure_transfer_poc_flutter/core/protocol/session_invitation_codec.dart';
import 'package:secure_transfer_poc_flutter/data/repositories/pointy_castle_session_invitation_repository.dart';
import 'package:secure_transfer_poc_flutter/domain/repositories/session_invitation_repository.dart';
import 'package:secure_transfer_poc_flutter/domain/use_cases/ble_central_use_case.dart';

import '../data/local/flutter_secure_identity_key_store.dart';
import '../data/local/identity_key_store.dart';
import '../data/repositories/pointy_castle_device_identity_repository.dart';
import '../domain/repositories/device_identity_repository.dart';

import '../domain/use_cases/create_signed_invitation_use_case.dart';
import '../domain/use_cases/validate_scanned_invitation_use_case.dart';

import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';

import '../data/repositories/flutter_ble_central_repository.dart';
import '../domain/repositories/ble_central_repository.dart';

import '../data/repositories/pointy_castle_session_key_repository.dart';
import '../domain/repositories/session_key_repository.dart';

import '../core/protocol/receiver_handshake_codec.dart';
import '../domain/use_cases/create_signed_receiver_handshake_use_case.dart';

import '../core/protocol/ble_frame_codec.dart';

import '../core/protocol/encrypted_transfer_envelope_codec.dart';
import '../core/protocol/transfer_acknowledgement_codec.dart';

import '../data/repositories/flutter_ble_peripheral_repository.dart';
import '../domain/repositories/ble_peripheral_repository.dart';
import '../domain/use_cases/ble_peripheral_use_case.dart';

import '../domain/use_cases/verify_receiver_handshake_use_case.dart';

import 'service_locator.dart';

void configureDependencies({
  String appId = PointyCastleSessionInvitationRepository.defaultAppId,
}) {
  if (appId.trim().isEmpty) {
    throw ArgumentError.value(appId, 'appId', 'No puede estar vacío');
  }

  if (getIt.isRegistered<_AppIdentity>()) {
    if (getIt<_AppIdentity>().value != appId) {
      throw StateError('La librería ya se configuró para otra aplicación');
    }
  } else {
    getIt.registerSingleton<_AppIdentity>(_AppIdentity(appId));
  }

  if (!getIt.isRegistered<FlutterSecureStorage>()) {
    getIt.registerLazySingleton<FlutterSecureStorage>(FlutterSecureStorage.new);
  }

  if (!getIt.isRegistered<IdentityKeyStore>()) {
    getIt.registerLazySingleton<IdentityKeyStore>(
      () =>
          FlutterSecureIdentityKeyStore(storage: getIt<FlutterSecureStorage>()),
    );
  }

  if (!getIt.isRegistered<DeviceIdentityRepository>()) {
    getIt.registerLazySingleton<DeviceIdentityRepository>(
      () => PointyCastleDeviceIdentityRepository(
        keyStore: getIt<IdentityKeyStore>(),
      ),
    );
  }

  if (!getIt.isRegistered<SessionInvitationRepository>()) {
    getIt.registerLazySingleton<SessionInvitationRepository>(
      () => PointyCastleSessionInvitationRepository(
        identityRepository: getIt<DeviceIdentityRepository>(),
        appId: getIt<_AppIdentity>().value,
      ),
    );
  }

  if (!getIt.isRegistered<SessionKeyRepository>()) {
    getIt.registerLazySingleton<SessionKeyRepository>(
      () => PointyCastleSessionKeyRepository(
        sessionInvitationRepository: getIt<SessionInvitationRepository>(),
      ),
    );
  }

  if (!getIt.isRegistered<ReceiverHandshakeCodec>()) {
    getIt.registerLazySingleton<ReceiverHandshakeCodec>(
      ReceiverHandshakeCodec.new,
    );
  }

  if (!getIt.isRegistered<CreateSignedReceiverHandshakeUseCase>()) {
    getIt.registerFactory<CreateSignedReceiverHandshakeUseCase>(
      () => CreateSignedReceiverHandshakeUseCase(
        identityRepository: getIt<DeviceIdentityRepository>(),
        codec: getIt<ReceiverHandshakeCodec>(),
        appId: getIt<_AppIdentity>().value,
      ),
    );
  }

  if (!getIt.isRegistered<VerifyReceiverHandshakeUseCase>()) {
    getIt.registerFactory<VerifyReceiverHandshakeUseCase>(
      () => VerifyReceiverHandshakeUseCase(
        identityRepository: getIt<DeviceIdentityRepository>(),
        codec: getIt<ReceiverHandshakeCodec>(),
        expectedAppId: getIt<_AppIdentity>().value,
      ),
    );
  }

  if (!getIt.isRegistered<SessionInvitationCodec>()) {
    getIt.registerLazySingleton<SessionInvitationCodec>(
      SessionInvitationCodec.new,
    );
  }

  if (!getIt.isRegistered<CreateSignedInvitationUseCase>()) {
    getIt.registerFactory<CreateSignedInvitationUseCase>(
      () => CreateSignedInvitationUseCase(
        repository: getIt<SessionInvitationRepository>(),
        codec: getIt<SessionInvitationCodec>(),
      ),
    );
  }

  if (!getIt.isRegistered<ValidateScannedInvitationUseCase>()) {
    getIt.registerFactory<ValidateScannedInvitationUseCase>(
      () => ValidateScannedInvitationUseCase(
        repository: getIt<SessionInvitationRepository>(),
        codec: getIt<SessionInvitationCodec>(),
      ),
    );
  }

  if (!getIt.isRegistered<PeripheralManager>()) {
    getIt.registerLazySingleton<PeripheralManager>(PeripheralManager.new);
  }

  if (!getIt.isRegistered<BlePeripheralRepository>()) {
    getIt.registerLazySingleton<BlePeripheralRepository>(
      () => FlutterBlePeripheralRepository(
        manager: getIt<PeripheralManager>(),
        frameCodec: getIt<BleFrameCodec>(),
        sessionKeyRepository: getIt<SessionKeyRepository>(),
        verifyReceiverHandshakeUseCase: getIt<VerifyReceiverHandshakeUseCase>(),
        envelopeCodec: getIt<EncryptedTransferEnvelopeCodec>(),
        acknowledgementCodec: getIt<TransferAcknowledgementCodec>(),
      ),
      dispose: (repository) => repository.dispose(),
    );
  }

  if (!getIt.isRegistered<BlePeripheralUseCase>()) {
    getIt.registerLazySingleton<BlePeripheralUseCase>(
      () => BlePeripheralUseCase(repository: getIt<BlePeripheralRepository>()),
    );
  }

  if (!getIt.isRegistered<CentralManager>()) {
    getIt.registerLazySingleton<CentralManager>(CentralManager.new);
  }

  if (!getIt.isRegistered<BleFrameCodec>()) {
    getIt.registerLazySingleton<BleFrameCodec>(BleFrameCodec.new);
  }

  if (!getIt.isRegistered<EncryptedTransferEnvelopeCodec>()) {
    getIt.registerLazySingleton<EncryptedTransferEnvelopeCodec>(
      EncryptedTransferEnvelopeCodec.new,
    );
  }

  if (!getIt.isRegistered<TransferAcknowledgementCodec>()) {
    getIt.registerLazySingleton<TransferAcknowledgementCodec>(
      TransferAcknowledgementCodec.new,
    );
  }

  if (!getIt.isRegistered<BleCentralRepository>()) {
    getIt.registerLazySingleton<BleCentralRepository>(
      () => FlutterBleCentralRepository(
        manager: getIt<CentralManager>(),
        frameCodec: getIt<BleFrameCodec>(),
        sessionKeyRepository: getIt<SessionKeyRepository>(),
        envelopeCodec: getIt<EncryptedTransferEnvelopeCodec>(),
        acknowledgementCodec: getIt<TransferAcknowledgementCodec>(),
      ),
      dispose: (repository) => repository.dispose(),
    );
  }

  if (!getIt.isRegistered<BleCentralUseCase>()) {
    getIt.registerLazySingleton<BleCentralUseCase>(
      () => BleCentralUseCase(repository: getIt<BleCentralRepository>()),
    );
  }
}

class _AppIdentity {
  const _AppIdentity(this.value);

  final String value;
}
