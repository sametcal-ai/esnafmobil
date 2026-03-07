import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/scanner/barcode_scanner_view.dart';
import '../../../core/widgets/app_scaffold.dart';

class BarcodeScannerPage extends ConsumerStatefulWidget {
  const BarcodeScannerPage({super.key});

  @override
  ConsumerState<BarcodeScannerPage> createState() => _BarcodeScannerPageState();
}

class _BarcodeScannerPageState extends ConsumerState<BarcodeScannerPage> {
  String? _lastScanned;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Scan Barcode',
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BarcodeScannerView(
                  ownerId: 'scanner_page',
                  enabled: true,
                  onBarcode: (value) {
                    final trimmed = value.trim();
                    if (trimmed.isEmpty) return;

                    setState(() {
                      _lastScanned = trimmed;
                    });

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Scanned: $trimmed')),
                    );
                  },
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Center(
              child: _lastScanned == null
                  ? const Text('Point the camera at a barcode')
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Last scanned value:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            _lastScanned!,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}