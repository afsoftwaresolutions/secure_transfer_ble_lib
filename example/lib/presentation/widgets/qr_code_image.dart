import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class QrCodeImage extends StatelessWidget {
  const QrCodeImage({required this.data, super.key});

  final String data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: QrImageView(
        data: data,
        version: QrVersions.auto,
        size: 280,
        gapless: true,
        backgroundColor: Colors.white,
        errorCorrectionLevel: QrErrorCorrectLevel.M,
      ),
    );
  }
}
