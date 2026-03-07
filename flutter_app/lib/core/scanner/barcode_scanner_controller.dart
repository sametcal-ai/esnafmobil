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
      ownerId: ownerId,
      status: status ?? this.status,
      errorMessage: errorMessage,
      controller: controller,
    );
  }
}

class ScannerSessionManager extends StateNotifier<ScannerSessionState> {
  ScannerSessionManager() : super(ScannerSessionState.initial());

  Future<void> acquire(String ownerId) async {
    if (state.ownerId == ownerId &&
        (state.status == ScannerSessionStatus.active ||
            state.status == ScannerSessionStatus.paused) &&
        state.controller != null) {
      if (state.status == ScannerSessionStatus.paused) {
        await resume(ownerId);
      }
      return;
    }

    state = state.copyWith(
      ownerId: ownerId,
      status: ScannerSessionStatus.acquiring,
      errorMessage: null,
      controller: state.controller,
    );

    await _disposeController();

    final controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      autoStart: false,
    );

    try {
      await controller.start();

      // The view that requested this session may have been disposed or another
      // screen may have taken ownership while we were awaiting permission/start.
      if (state.ownerId != ownerId || state.status != ScannerSessionStatus.acquiring) {
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
    if (state.ownerId != ownerId) return;

    await _disposeController();

    state = ScannerSessionState.initial();
  }

  Future<void> pause(String ownerId) async {
    if (state.ownerId != ownerId) return;
    if (state.controller == null) return;
    if (state.status != ScannerSessionStatus.active) return;

    try {
      await state.controller!.stop();
    } finally {
      if (state.ownerId != ownerId) return;
      state = state.copyWith(
        ownerId: ownerId,
        status: ScannerSessionStatus.paused,
        errorMessage: null,
        controller: state.controller,
      );
    }
  }

  Future<void> resume(String ownerId) async {
    if (state.ownerId != ownerId) return;
    if (state.controller == null) return;
    if (state.status != ScannerSessionStatus.paused) return;

    try {
      await state.controller!.start();

      if (state.ownerId != ownerId) return;

      state = state.copyWith(
        ownerId: ownerId,
        status: ScannerSessionStatus.active,
        errorMessage: null,
        controller: state.controller,
      );
    } catch (e) {
      await _disposeController();

      if (state.ownerId != ownerId) return;

      state = state.copyWith(
        ownerId: ownerId,
        status: ScannerSessionStatus.error,
        errorMessage: e.toString(),
        controller: null,
      );
    }
  }

  Future<void> _disposeController() async {
    final controller = state.controller;
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
    StateNotifierProvider<ScannerSessionManager, ScannerSessionState>((ref) {
  return ScannerSessionManager();
});
