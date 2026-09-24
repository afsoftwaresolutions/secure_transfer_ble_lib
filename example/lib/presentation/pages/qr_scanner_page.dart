import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QrScannerPage extends StatefulWidget {
  const QrScannerPage({super.key});

  @override
  State<QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<QrScannerPage> {
  final MobileScannerController _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );

  bool _codeWasProcessed = false;

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_codeWasProcessed) {
      return;
    }

    String? invitationJson;

    for (final barcode in capture.barcodes) {
      final rawValue = barcode.rawValue;

      if (rawValue != null && rawValue.trim().isNotEmpty) {
        invitationJson = rawValue;
        break;
      }
    }

    if (invitationJson == null) {
      return;
    }

    _codeWasProcessed = true;

    await _controller.stop();

    if (!mounted) {
      return;
    }

    Navigator.of(context).pop(invitationJson);
  }

  @override
  void dispose() {
    unawaited(_controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Escanear invitación'),
        actions: [
          IconButton(
            tooltip: 'Linterna',
            onPressed: _controller.toggleTorch,
            icon: const Icon(Icons.flashlight_on),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          IgnorePointer(
            child: Center(
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 3),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),
          const Positioned(
            left: 24,
            right: 24,
            bottom: 40,
            child: Card(
              color: Colors.black87,
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Ubica dentro del recuadro el QR '
                  'generado por Kotlin o Flutter.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
