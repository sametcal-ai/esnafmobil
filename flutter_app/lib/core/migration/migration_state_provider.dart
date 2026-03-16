import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/auth/domain/firebase_auth_controller.dart';
import '../../features/company/domain/active_company_provider.dart';
import 'hive_to_firestore_migrator.dart';

enum MigrationStatus {
  idle,
  running,
  done,
  error,
}

@immutable
class MigrationState {
  final MigrationStatus status;
  final MigrationProgress? progress;
  final String? errorMessage;
  final MigrationReport? report;

  const MigrationState({
    required this.status,
    required this.progress,
    required this.errorMessage,
    required this.report,
  });

  factory MigrationState.initial() {
    return const MigrationState(
      status: MigrationStatus.idle,
      progress: null,
      errorMessage: null,
      report: null,
    );
  }

  MigrationState copyWith({
    MigrationStatus? status,
    MigrationProgress? progress,
    String? errorMessage,
    MigrationReport? report,
  }) {
    return MigrationState(
      status: status ?? this.status,
      progress: progress ?? this.progress,
      errorMessage: errorMessage,
      report: report ?? this.report,
    );
  }
}

abstract class MigrationFlagStore {
  Future<bool> isDone(String companyId);
  Future<void> setDone(String companyId, bool value);
}

class SharedPreferencesMigrationFlagStore implements MigrationFlagStore {
  static String keyFor(String companyId) => 'migrationDone_$companyId';

  @override
  Future<bool> isDone(String companyId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(keyFor(companyId)) ?? false;
  }

  @override
  Future<void> setDone(String companyId, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyFor(companyId), value);
  }
}

class MigrationStateController extends StateNotifier<MigrationState> {
  MigrationStateController({
    required this.flagStore,
    required this.runner,
  }) : super(MigrationState.initial());

  final MigrationFlagStore flagStore;
  final MigrationRunner runner;

  Future<void> ensureMigrated({
    required bool isLoggedIn,
    required String? companyId,
    bool dryRun = false,
  }) async {
    if (!isLoggedIn || companyId == null) {
      state = MigrationState.initial();
      return;
    }

    if (state.status == MigrationStatus.running) {
      return;
    }

    final done = await flagStore.isDone(companyId);
    if (done) {
      state = state.copyWith(status: MigrationStatus.done, errorMessage: null);
      return;
    }

    state = state.copyWith(
      status: MigrationStatus.running,
      progress: const MigrationProgress(phase: 'starting', migrated: 0, total: 0),
      errorMessage: null,
      report: null,
    );

    try {
      final report = await runner.run(
        companyId: companyId,
        dryRun: dryRun,
        onProgress: (p) {
          state = state.copyWith(progress: p);
        },
      );

      if (!dryRun) {
        await flagStore.setDone(companyId, true);
      }

      state = state.copyWith(
        status: MigrationStatus.done,
        progress: state.progress,
        report: report,
        errorMessage: null,
      );
    } catch (e) {
      debugPrint('[migration] failed: $e');
      state = state.copyWith(
        status: MigrationStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> retry({
    required bool isLoggedIn,
    required String? companyId,
    bool dryRun = false,
  }) async {
    state = MigrationState.initial();
    await ensureMigrated(isLoggedIn: isLoggedIn, companyId: companyId, dryRun: dryRun);
  }
}

final migrationFlagStoreProvider = Provider<MigrationFlagStore>((ref) {
  return SharedPreferencesMigrationFlagStore();
});

final hiveToFirestoreMigratorProvider = Provider<MigrationRunner>((ref) {
  // FirebaseFirestore erişimi migrator içinde FirestoreRefs üzerinden alınıyor.
  // Burada direkt instance veriyoruz.
  return HiveToFirestoreMigrator(FirebaseFirestore.instance);
});

final migrationStateProvider =
    StateNotifierProvider<MigrationStateController, MigrationState>((ref) {
  final flagStore = ref.watch(migrationFlagStoreProvider);
  final runner = ref.watch(hiveToFirestoreMigratorProvider);
  final controller = MigrationStateController(flagStore: flagStore, runner: runner);

  ref.listen(authStateProvider, (_, next) {
    final isLoggedIn = next.value != null;
    final companyId = ref.read(activeCompanyIdProvider);
    controller.ensureMigrated(isLoggedIn: isLoggedIn, companyId: companyId);
  });

  ref.listen(activeCompanyIdProvider, (_, next) {
    final isLoggedIn = ref.read(authStateProvider).value != null;
    controller.ensureMigrated(isLoggedIn: isLoggedIn, companyId: next);
  });

  return controller;
});
