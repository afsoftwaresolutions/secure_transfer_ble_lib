import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';

import '../stores/transfer_store.dart';
import '../widgets/qr_code_image.dart';

import 'qr_scanner_page.dart';

class TransferPage extends StatelessWidget {
  const TransferPage({required this.store, super.key});

  final TransferStore store;

  Future<void> _scanInvitation(BuildContext context) async {
    final invitationJson = await Navigator.of(context)
        .push<String>(MaterialPageRoute(builder: (_) => const QrScannerPage()));

    if (invitationJson == null || invitationJson.trim().isEmpty) {
      return;
    }

    await store.startReceiveFlow(invitationJson);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('IR Transfer Flutter')),
      body: SafeArea(
        child: Observer(
          builder: (context) {
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'Emisor Flutter',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Genera una invitación firmada que '
                  'puede ser validada por Kotlin o Flutter.',
                ),
                const SizedBox(height: 20),
                const SizedBox(height: 8),
                const SizedBox(height: 8),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Peripheral: '
                          '${store.blePeripheralStatus.name.toUpperCase()}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(store.blePeripheralMessage),
                        if (store.connectedCentralId case final centralId?)
                          SelectableText('Receptor: $centralId'),
                      ],
                    ),
                  ),
                ),

                if (store.canCloseSendFlow) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: store.closeSendFlow,
                    icon: const Icon(Icons.close),
                    label: const Text('Cerrar envío'),
                  ),
                ],

                const SizedBox(height: 16),

                Text(
                  'Contenido para transferir',
                  style: Theme.of(context).textTheme.titleMedium,
                ),

                const SizedBox(height: 8),

                TextFormField(
                  initialValue: store.outgoingPlainText,
                  onChanged: store.updateOutgoingPlainText,
                  minLines: 4,
                  maxLines: 10,
                  keyboardType: TextInputType.multiline,
                  decoration: const InputDecoration(
                    labelText: 'Texto plano o JSON',
                    hintText: 'Escribe el contenido que deseas enviar',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),

                const SizedBox(height: 20),

                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: store.canStartSendFlow
                            ? store.startSendFlow
                            : null,
                        icon: const Icon(Icons.send),
                        label: const Text('Enviar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: store.canStartReceiveFlow
                            ? () => _scanInvitation(context)
                            : null,
                        icon: const Icon(Icons.download),
                        label: const Text('Recibir'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (store.scannedSessionId case final scannedSessionId?) ...[
                  const SizedBox(height: 20),
                  Card(
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Invitación recibida',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Session ID',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          SelectableText(scannedSessionId),
                          const SizedBox(height: 12),
                          const Text(
                            'Dispositivo emisor',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          SelectableText(store.scannedDeviceId ?? ''),
                        ],
                      ),
                    ),
                  ),
                ],
                if (store.scannedSessionId != null) ...[
                  const SizedBox(height: 20),
                  Text(
                    'Conexión Bluetooth',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Cliente BLE: '
                            '${store.bleCentralStatus.name.toUpperCase()}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(store.bleCentralMessage),
                          if (store.blePeripheralId
                              case final peripheralId?) ...[
                            const SizedBox(height: 8),
                            SelectableText('Dispositivo: $peripheralId'),
                          ],
                          if (store.bleRssi case final rssi?)
                            Text('RSSI: $rssi dBm'),
                          if (store.negotiatedMtu case final mtu?)
                            Text('MTU: $mtu'),
                        ],
                      ),
                    ),
                  ),

                  if (store.canCloseReceiveFlow) ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: store.closeReceiveFlow,
                      icon: const Icon(Icons.bluetooth_disabled),
                      label: const Text('Cerrar recepción'),
                    ),
                  ],
                ],
                const SizedBox(height: 16),
                const SizedBox(height: 20),
                if (store.isLoading)
                  const Center(child: CircularProgressIndicator()),
                if (!store.isLoading)
                  _StatusCard(
                    message: store.message,
                    isError: store.errorMessage != null,
                  ),
                if (store.receivedData case final receivedData?) ...[
                  const SizedBox(height: 12),
                  Card(
                    color: Theme.of(context).colorScheme.tertiaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Mensaje recibido y descifrado',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          if (store.receivedMessageId case final messageId?)
                            SelectableText('Message ID: $messageId'),
                          const SizedBox(height: 8),
                          SelectableText(receivedData),
                        ],
                      ),
                    ),
                  ),
                ],
                if (store.errorMessage case final error?)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: SelectableText(
                      error,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                if (store.invitationJson case final invitationJson?) ...[
                  const SizedBox(height: 24),
                  Center(child: QrCodeImage(data: invitationJson)),
                  const Text(
                    'Session ID',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(store.generatedSessionId ?? ''),
                  const SizedBox(height: 12),
                  if (store.invitationExpiresAtEpochMillis
                      case final expiresAt?)
                    Text(
                      'Expira: '
                      '${DateTime.fromMillisecondsSinceEpoch(expiresAt).toLocal()}',
                    ),
                  const SizedBox(height: 12),
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: const Text('Ver JSON de la invitación'),
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: SelectableText(invitationJson),
                      ),
                    ],
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.message, required this.isError});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final color = isError
        ? colorScheme.errorContainer
        : colorScheme.primaryContainer;

    final foregroundColor = isError
        ? colorScheme.onErrorContainer
        : colorScheme.onPrimaryContainer;

    return Card(
      color: color,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(message, style: TextStyle(color: foregroundColor)),
      ),
    );
  }
}
