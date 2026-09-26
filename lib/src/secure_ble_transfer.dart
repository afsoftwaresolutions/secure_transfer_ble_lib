import 'dart:async';

import '../domain/entities/ble_central_state.dart';
import '../domain/entities/ble_peripheral_state.dart';
import '../domain/use_cases/ble_central_use_case.dart';
import '../domain/use_cases/ble_peripheral_use_case.dart';

import '../domain/models/signed_invitation_result.dart';

import '../domain/use_cases/create_signed_invitation_use_case.dart';

import '../domain/models/scanned_invitation_result.dart';
import '../domain/repositories/session_key_repository.dart';
import '../domain/use_cases/create_signed_receiver_handshake_use_case.dart';
import '../domain/use_cases/validate_scanned_invitation_use_case.dart';

import '../di/dependency_injection.dart';
import '../di/service_locator.dart';

import '../data/repositories/pointy_castle_session_invitation_repository.dart';

class SecureBleTransfer {
  static SecureBleTransfer? _defaultInstance;
  static String? _defaultAppId;

  factory SecureBleTransfer.create({
    String appId = PointyCastleSessionInvitationRepository.defaultAppId,
  }) {
    if (appId.trim().isEmpty) {
      throw ArgumentError.value(appId, 'appId', 'No puede estar vacío');
    }

    final existing = _defaultInstance;
    if (existing != null) {
      if (_defaultAppId != appId) {
        throw StateError('La librería ya se creó para otra aplicación');
      }
      return existing;
    }

    configureDependencies(appId: appId);

    final instance = SecureBleTransfer(
      central: getIt<BleCentralUseCase>(),
      peripheral: getIt<BlePeripheralUseCase>(),
      createInvitation: getIt<CreateSignedInvitationUseCase>(),
      validateInvitation: getIt<ValidateScannedInvitationUseCase>(),
      sessionKeys: getIt<SessionKeyRepository>(),
      createReceiverHandshake: getIt<CreateSignedReceiverHandshakeUseCase>(),
    );

    _defaultAppId = appId;
    _defaultInstance = instance;
    return instance;
  }

  SecureBleTransfer({
    required BleCentralUseCase central,
    required BlePeripheralUseCase peripheral,
    required CreateSignedInvitationUseCase createInvitation,
    required ValidateScannedInvitationUseCase validateInvitation,
    required SessionKeyRepository sessionKeys,
    required CreateSignedReceiverHandshakeUseCase createReceiverHandshake,
  }) : _central = central,
       _peripheral = peripheral,
       _createInvitation = createInvitation,
       _validateInvitation = validateInvitation,
       _sessionKeys = sessionKeys,
       _createReceiverHandshake = createReceiverHandshake;

  final BleCentralUseCase _central;
  final BlePeripheralUseCase _peripheral;
  final CreateSignedInvitationUseCase _createInvitation;

  final ValidateScannedInvitationUseCase _validateInvitation;
  final SessionKeyRepository _sessionKeys;
  final CreateSignedReceiverHandshakeUseCase _createReceiverHandshake;

  String? _receiverSessionId;
  String? _receiverHandshakeJson;
  String? _receiverFingerprint;
  bool _preparingReceiver = false;

  bool _sending = false;

  bool _sendingReply = false;

  Stream<String> get receivedTexts => _receivedTexts();

  StreamSubscription<BleCentralState>? _receiverFlowSubscription;

  Stream<String> _receivedTexts() async* {
    final processedMessageIds = <String>{};

    await for (final state in _central.states) {
      if (state.status == BleCentralStatus.disconnected ||
          state.status == BleCentralStatus.idle) {
        processedMessageIds.clear();
        continue;
      }

      if (state.status != BleCentralStatus.dataReceived) continue;

      final messageId = state.receivedMessageId;
      final text = state.receivedData;

      if (messageId == null ||
          text == null ||
          !processedMessageIds.add(messageId)) {
        continue;
      }

      yield text;
    }
  }

  BlePeripheralState get senderState => _peripheral.state;
  Stream<BlePeripheralState> get senderStates => _peripheral.states;

  BleCentralState get receiverState => _central.state;
  Stream<BleCentralState> get receiverStates => _central.states;

  /// Textos que B envía al teléfono A, creador del QR.
  Stream<String> get receivedReplies => _peripheral.receivedTexts;

  /// Indica si el teléfono A conectado permite envíos B → A.
  bool get supportsReplies => _central.supportsReverseData;

  /// Envía un texto desde B hacia A y espera su ACK.
  Future<void> sendReply(
    String text, {
    Duration ackTimeout = const Duration(seconds: 5),
  }) async {
    if (_sendingReply) {
      throw StateError('Ya hay una respuesta esperando ACK');
    }

    if (!supportsReplies) {
      throw StateError('El emisor conectado no admite respuestas B → A');
    }

    _sendingReply = true;

    try {
      await _central.sendEncryptedData(
        text,
        ackTimeout: ackTimeout,
      );
    } finally {
      _sendingReply = false;
    }
  }

  /// Completa cuando el receptor confirma este mensaje mediante ACK.
  Future<void> sendText(
    String text, {
    Duration ackTimeout = const Duration(minutes: 2),
  }) async {
    if (text.trim().isEmpty) {
      throw ArgumentError.value(text, 'text', 'El texto está vacío');
    }
    if (_sending) {
      throw StateError('Ya hay un mensaje en proceso de envío');
    }

    final status = _peripheral.state.status;
    if (status != BlePeripheralStatus.sessionKeyReady &&
        status != BlePeripheralStatus.dataConfirmed) {
      throw StateError('La sesión BLE aún no está lista para enviar');
    }

    _sending = true;
    final acknowledgement = Completer<void>();
    String? sendingMessageId;

    final subscription = _peripheral.states.listen((state) {
      if (state.status == BlePeripheralStatus.dataSending ||
          state.status == BlePeripheralStatus.waitingAck) {
        sendingMessageId ??= state.messageId;
      }

      if (state.status == BlePeripheralStatus.dataConfirmed &&
          sendingMessageId != null &&
          state.messageId == sendingMessageId &&
          !acknowledgement.isCompleted) {
        acknowledgement.complete();
      }

      if ((state.status == BlePeripheralStatus.error ||
              state.status == BlePeripheralStatus.sessionRejected ||
              state.status == BlePeripheralStatus.idle) &&
          !acknowledgement.isCompleted) {
        acknowledgement.completeError(StateError(state.message));
      }
    });

    try {
      await Future.wait<void>([
        _peripheral.sendEncryptedData(text),
        acknowledgement.future.timeout(ackTimeout),
      ], eagerError: true);
    } finally {
      await subscription.cancel();
      _sending = false;
    }
  }

  /// Devuelve el texto que la app debe mostrar como código QR.
  Future<SignedInvitationResult> startSending() async {
    final state = _peripheral.state;
    final canStart =
        state.status == BlePeripheralStatus.idle ||
        (state.status == BlePeripheralStatus.error && state.sessionId == null);

    if (!canStart) {
      throw StateError('Ya existe un flujo de envío activo');
    }

    final result = await _createInvitation();
    if (!result.signatureValid) {
      throw StateError('La invitación no superó la verificación local');
    }

    await _peripheral.startAdvertising(result.invitation.sessionId);
    return result;
  }

  Future<void> stopSending() => _peripheral.stopAdvertising();

  Future<ScannedInvitationResult> prepareReceiving(String scannedJson) async {
    if (_receiverSessionId != null || _preparingReceiver) {
      throw StateError('Ya existe un flujo de recepción activo');
    }

    _preparingReceiver = true;
    String? pendingSessionId;

    try {
      final result = await _validateInvitation(scannedJson);
      final sessionId = result.sessionId;
      final senderKey = result.senderEphemeralPublicKey;

      if (sessionId.trim().isEmpty || senderKey.trim().isEmpty) {
        throw const FormatException(
          'La invitación no contiene los datos ECDH necesarios',
        );
      }

      pendingSessionId = sessionId;

      final agreement = await _sessionKeys.prepareReceiverSession(
        sessionId: sessionId,
        senderEphemeralPublicKey: senderKey,
      );

      final handshake = await _createReceiverHandshake(
        sessionId: sessionId,
        receiverEphemeralPublicKey: agreement.receiverEphemeralPublicKey,
      );

      _receiverSessionId = sessionId;
      _receiverHandshakeJson = handshake.handshakeJson;
      _receiverFingerprint = agreement.sessionKeyFingerprint;

      return result;
    } on Object {
      if (pendingSessionId != null) {
        _sessionKeys.removeSession(pendingSessionId);
      }
      rethrow;
    } finally {
      _preparingReceiver = false;
    }
  }

  Future<void> connectReceiver() async {
    final sessionId = _receiverSessionId;
    final handshakeJson = _receiverHandshakeJson;
    final fingerprint = _receiverFingerprint;

    if (sessionId == null || handshakeJson == null || fingerprint == null) {
      throw StateError('Primero debes preparar una invitación válida');
    }
    if (_receiverFlowSubscription != null) {
      throw StateError('La conexión del receptor ya está iniciada');
    }

    var confirmationStarted = false;
    var handshakeStarted = false;

    _receiverFlowSubscription = _central.states.listen((state) {
      if (state.status == BleCentralStatus.serviceReady &&
          !confirmationStarted) {
        confirmationStarted = true;
        unawaited(_central.confirmSession(sessionId));
      }

      if (state.status == BleCentralStatus.sessionVerified &&
          !handshakeStarted) {
        handshakeStarted = true;
        unawaited(
          _central.sendReceiverHandshake(
            handshakeJson: handshakeJson,
            sessionKeyFingerprint: fingerprint,
          ),
        );
      }
    });

    await _central.scanAndConnect();

    if (_central.state.status == BleCentralStatus.error) {
      await _receiverFlowSubscription?.cancel();
      _receiverFlowSubscription = null;
      throw StateError(_central.state.message);
    }
  }

  Future<void> stopReceiving() async {
    final subscription = _receiverFlowSubscription;
    _receiverFlowSubscription = null;
    await subscription?.cancel();

    final sessionId = _receiverSessionId;
    _receiverSessionId = null;
    _receiverHandshakeJson = null;
    _receiverFingerprint = null;

    try {
      await _central.disconnect();
    } finally {
      if (sessionId != null) {
        _sessionKeys.removeSession(sessionId);
      }
    }
  }
}
