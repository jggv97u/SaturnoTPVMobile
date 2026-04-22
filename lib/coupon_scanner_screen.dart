import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class CouponScannerScreen extends StatefulWidget {
  const CouponScannerScreen({super.key});

  @override
  State<CouponScannerScreen> createState() => _CouponScannerScreenState();
}

class _CouponScannerScreenState extends State<CouponScannerScreen> {
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Escanear Cupón'),
      ),
      body: MobileScanner(
        controller: _scannerController,
        onDetect: (capture) {
          final List<Barcode> barcodes = capture.barcodes;
          if (barcodes.isNotEmpty) {
            final String? code = barcodes.first.rawValue;
            if (code != null) {
              Navigator.of(context).pop(code);
            }
          }
        },
      ),
    );
  }
}
