import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

enum ScannerSessionStatus {
  inactive,
  acquiring,
  active,
  paused,
  error,
}

@immutable
class ScannerSessionState {
  final String? ownerId;
  final ScannerSessionStatus status;
  final String? errorMessage;
  final MobileScannerController? controller;

  const ScannerSessionState({
    required this.ownerId,
    required this.status,
    required this.errorMessage,
    required this.controller,
  });

  factory ScannerSessionState.initial() {
    return const ScannerSessionState(
      ownerId: null,
      status: ScannerSessionStatus.inactive,
      errorMessage: null,
      controller: null,
    );
  }

  ScannerSessionState copyWith({
    String? ownerId,
    ScannerSessionStatus? status,
    String? errorMessage,
    MobileScannerController? controller,
  }) {
    return ScannerSessionState(
      ownerId: ownerId ?? this.ownerId,
      status: status ?? this.status,
      errorMessage: errorMessage,
      controller: controller ?? this.controller,
    );
  }
}

class ScannerSessionManager extends Notifier<ScannerSessionState> {
  @override
  ScannerSessionState build() {
    ref.onDispose(() {
      state.controller?.dispose();
    });

    return ScannerSessionState.initial();
  }

  Future<void> acquire(String ownerId) async {
    if (!ref.mounted) return;

    if (state.ownerId == ownerId &&
        (state.status == ScannerSessionStatus.active ||
            state.status == ScannerSessionStatus.paused) &&
        state.controller != null) {
      if (state.status == ScannerSessionStatus.paused) {
        await resume(ownerId);
      }
      return;
    }

    final previousController = state.controller;

    state = state.copyWith(
      ownerId: ownerId,
      status: ScannerSessionStatus.acquiring,
      errorMessage: null,
      controller: null,
    );

    await _disposeController(previousController);
    if (!ref.mounted) return;

    final controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      autoStart: false,
    );

    try {
      await controller.start();

      if (!ref.mounted) {
        controller.dispose();
        return;
      }

      // Another view may have taken ownership while we were awaiting permission.
      if (state.ownerId != ownerId ||
          state.status != ScannerSessionStatus.acquiring) {
        controller.dispose();
        return;
      }

      state = state.copyWith(
        ownerId: ownerId,
        status: ScannerSessionStatus.active,
        errorMessage: null,
        controller: controller,
      );
    } catch (e) {
      controller.dispose();

      if (!ref.mounted) return;
      if (state.ownerId != ownerId) return;

      state = state.copyWith(
        ownerId: ownerId,
        status: ScannerSessionStatus.error,
        errorMessage: e.toString(),
        controller: null,
      );
    }
  }

  Future<void> release(String ownerId) async {
    if (!ref.mounted) return;
    if (state.ownerId != ownerId) return;

    final controller = state.controller;
    state = ScannerSessionState.initial();

    await _disposeController(controller);
  }

  Future<void> pause(String ownerId) async {
    if (!ref.mounted) return;
    if (state.ownerId != ownerId) return;
    if (state.controller == null) return;
    if (state.status != ScannerSessionStatus.active) return;

    try {
      await state.controller!.stop();
    } finally {
      if (!ref.mounted) return;
      if (state.ownerId != ownerId) return;

      state = state.copyWith(
        ownerId: ownerId,
        status: ScannerSessionStatus.paused,
        errorMessage: null,
      );
    }
  }

  Future<void> resume(String ownerId) async {
    if (!ref.mounted) return;
    if (state.ownerId != ownerId) return;
    if (state.controller == null) return;
    if (state.status != ScannerSessionStatus.paused) return;

    try {
      await state.controller!.start();

      if (!ref.mounted) return;
      if (state.ownerId != ownerId) return;

      state = state.copyWith(
        ownerId: ownerId,
        status: ScannerSessionStatus.active,
        errorMessage: null,
      );
    } catch (e) {
      final controller = state.controller;
      state = state.copyWith(controller: null);

      await _disposeController(controller);

      if (!ref.mounted) return;
      if (state.ownerId != ownerId) return;

      state = state.copyWith(
        ownerId: ownerId,
        status: ScannerSessionStatus.error,
        errorMessage: e.toString(),
        controller: null,
      );
    }
  }

  Future<void> _disposeController(MobileScannerController? controller) async {
    if (controller == null) return;

    try {
      await controller.stop();
    } catch (_) {
      // ignore stop errors; dispose below
    }
    controller.dispose();
  }
}

final scannerSessionManagerProvider =
    NotifierProvider<ScannerSessionManager, ScannerSessionState>(
  ScannerSessionManager.new,
);
