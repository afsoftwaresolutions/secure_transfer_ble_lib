import 'package:flutter/material.dart';
import 'package:secure_transfer_poc_flutter/di/dependency_injection.dart';
import 'package:secure_transfer_poc_flutter/di/service_locator.dart';
import 'package:secure_transfer_poc_flutter/domain/repositories/session_key_repository.dart';
import 'package:secure_transfer_poc_flutter/domain/use_cases/ble_central_use_case.dart';
import 'package:secure_transfer_poc_flutter/domain/use_cases/ble_peripheral_use_case.dart';
import 'package:secure_transfer_poc_flutter/domain/use_cases/create_signed_invitation_use_case.dart';
import 'package:secure_transfer_poc_flutter/domain/use_cases/create_signed_receiver_handshake_use_case.dart';
import 'package:secure_transfer_poc_flutter/domain/use_cases/validate_scanned_invitation_use_case.dart';

import 'presentation/pages/transfer_page.dart';
import 'presentation/stores/transfer_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  configureDependencies();

  final transferStore = TransferStore(
    createSignedInvitationUseCase: getIt<CreateSignedInvitationUseCase>(),
    validateScannedInvitationUseCase: getIt<ValidateScannedInvitationUseCase>(),
    bleCentralUseCase: getIt<BleCentralUseCase>(),
    sessionKeyRepository: getIt<SessionKeyRepository>(),
    createSignedReceiverHandshakeUseCase:
        getIt<CreateSignedReceiverHandshakeUseCase>(),
    blePeripheralUseCase: getIt<BlePeripheralUseCase>(),
  );

  runApp(MyApp(transferStore: transferStore));
}

class MyApp extends StatelessWidget {
  const MyApp({required this.transferStore, super.key});

  final TransferStore transferStore;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Secure Transfer POC',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: TransferPage(store: transferStore),
    );
  }
}
