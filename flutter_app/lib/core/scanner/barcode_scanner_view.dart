import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

import '../config/app_settings.dart';
import 'barcode_scanner_controller.dart';

class BarcodeScannerView extends ConsumerStatefulWidget {
  final String ownerId;
  final bool enabled;
  final ValueChanged<String> onBarcode;

  const BarcodeScannerView({
    super.key,
    required this.ownerId,
    required this.enabled,
    required this.onBarcode,
  });

  @override
  ConsumerState<BarcodeScannerView> createState() => _BarcodeScannerViewState();
}

class _BarcodeScannerViewState extends ConsumerState<BarcodeScannerView>
    with WidgetsBindingObserver {
  bool _permissionDenied = false;

  String? _lastBarcode;
  DateTime? _lastScanAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    if (widget.enabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _initAndStart();
      });
    }
  }

  @override
  void didUpdateWidget(covariant BarcodeScannerView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!oldWidget.enabled && widget.enabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _initAndStart();
      });
    } else if (oldWidget.enabled && !widget.enabled) {
      ref.read(scannerSessionManagerProvider.notifier).release(widget.ownerId);
    }
  }

  Future<void> _initAndStart() async {
    setState(() {
      _permissionDenied = false;
    });

    final status = await Permission.camera.request();

    if (!mounted) return;

    if (!status.isGranted) {
      setState(() {
        _permissionDenied = true;
      });
      await ref
          .read(scannerSessionManagerProvider.notifier)
          .release(widget.ownerId);
      return;
    }

    await ref.read(scannerSessionManagerProvider.notifier).acquire(widget.ownerId);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!widget.enabled) return;

    final manager = ref.read(scannerSessionManagerProvider.notifier);

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      manager.pause(widget.ownerId);
    }

    if (state == AppLifecycleState.resumed) {
      manager.resume(widget.ownerId);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ref.read(scannerSessionManagerProvider.notifier).release(widget.ownerId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return const SizedBox.shrink();
    }

    final session = ref.watch(scannerSessionManagerProvider);

    if (_permissionDenied) {
      return _ScannerInfoCard(
        message: 'Kamera izni verilmedi. Ayarlardan izin verin.',
        actionLabel: 'Ayarları Aç',
        onAction: openAppSettings,
      );
    }

    if (session.ownerId != widget.ownerId) {
      return const _ScannerInfoCard(
        message: 'Kamera başka bir ekranda kullanılıyor.',
      );
    }

    if (session.status == ScannerSessionStatus.error) {
      return _ScannerInfoCard(
        message: session.errorMessage ?? 'Kamera başlatılamadı',
        actionLabel: 'Tekrar Dene',
        onAction: _initAndStart,
      );
    }

    final controller = session.controller;
    if (controller == null ||
        (session.status != ScannerSessionStatus.active &&
            session.status != ScannerSessionStatus.paused &&
            session.status != ScannerSessionStatus.acquiring)) {
      return const _ScannerInfoCard(message: 'Kamera hazırlanıyor...');
    }

    return MobileScanner(
      controller: controller,
      onDetect: (capture) {
        if (!mounted) return;
        if (!widget.enabled) return;
        if (capture.barcodes.isEmpty) return;

        String? value;
        for (final barcode in capture.barcodes) {
          final candidate = barcode.rawValue ?? barcode.displayValue;
          if (candidate != null && candidate.trim().isNotEmpty) {
            value = candidate.trim();
            break;
          }
        }

        if (value == null) return;

        final settings = ref.read(appSettingsProvider);
        final delayMillis =
            (settings.barcodeScanDelaySeconds * 1000).clamp(500, 10000).toInt();
        final minDiff = Duration(milliseconds: delayMillis);

        final now = DateTime.now();
        if (_lastBarcode == value &&
            _lastScanAt != null &&
            now.difference(_lastScanAt!) < minDiff) {
          return;
        }

        _lastBarcode = value;
        _lastScanAt = now;

        widget.onBarcode(value);
      },
    );
  }
}

class _ScannerInfoCard extends StatelessWidget {
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _ScannerInfoCard({
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      color: theme.colorScheme.surface,
      alignment: Alignment.center,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
