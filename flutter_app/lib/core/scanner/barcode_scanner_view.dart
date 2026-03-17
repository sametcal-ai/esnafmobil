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

  late final ScannerSessionManager _sessionManager;
  bool _effectiveEnabled = false;

  MobileScannerController? _startPendingController;

  String? _lastBarcode;
  DateTime? _lastScanAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _sessionManager = ref.read(scannerSessionManagerProvider.notifier);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncEffectiveEnabled(force: true);
    });
  }

  @override
  void didUpdateWidget(covariant BarcodeScannerView oldWidget) {
    super.didUpdateWidget(oldWidget);

    // enabled/ownerId changes can affect whether we should hold the camera.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncEffectiveEnabled();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // ModalRoute/TickerMode changes don't always trigger didUpdateWidget.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncEffectiveEnabled();
    });
  }

  bool _computeEffectiveEnabled() {
    if (!widget.enabled) return false;

    final isTicking = TickerMode.of(context);
    if (!isTicking) return false;

    final isCurrentRoute = ModalRoute.of(context)?.isCurrent ?? true;
    if (!isCurrentRoute) return false;

    return true;
  }

  void _syncEffectiveEnabled({bool force = false}) {
    final next = _computeEffectiveEnabled();
    if (!force && next == _effectiveEnabled) return;

    final previous = _effectiveEnabled;
    _effectiveEnabled = next;

    if (!previous && next) {
      _initAndStart();
    } else if (previous && !next) {
      _startPendingController = null;
      _sessionManager.release(widget.ownerId);
    }

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _initAndStart() async {
    setState(() {
      _permissionDenied = false;
    });

    final status = await Permission.camera.request();

    if (!mounted) return;

    // While waiting for permission, this view may have become non-current.
    if (!_computeEffectiveEnabled()) {
      await _sessionManager.release(widget.ownerId);
      return;
    }

    if (!status.isGranted) {
      setState(() {
        _permissionDenied = true;
      });
      await _sessionManager.release(widget.ownerId);
      return;
    }

    await _sessionManager.acquire(widget.ownerId);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_effectiveEnabled) return;

    final manager = _sessionManager;

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
    _startPendingController = null;

    // Avoid async notifier state updates while the widget tree is being unmounted.
    Future.microtask(() {
      _sessionManager.release(widget.ownerId);
    });

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_effectiveEnabled) {
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

    if (session.status == ScannerSessionStatus.acquiring &&
        _startPendingController != controller) {
      _startPendingController = controller;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        if (!_effectiveEnabled) return;

        final current = ref.read(scannerSessionManagerProvider);
        if (current.ownerId != widget.ownerId || current.controller != controller) {
          return;
        }

        try {
          await controller.start();
          if (!mounted) return;
          _sessionManager.markActive(widget.ownerId, controller);
        } catch (e) {
          if (!mounted) return;
          await _sessionManager.fail(widget.ownerId, controller, e);
        }
      });
    }

    return MobileScanner(
      controller: controller,
      onDetect: (capture) {
        if (!mounted) return;
        if (!_effectiveEnabled) return;
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
