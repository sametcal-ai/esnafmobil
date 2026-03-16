import 'package:flutter_app/core/migration/hive_to_firestore_migrator.dart';
import 'package:flutter_app/core/migration/migration_state_provider.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeFlagStore implements MigrationFlagStore {
  _FakeFlagStore({required this.done});

  bool done;

  @override
  Future<bool> isDone(String companyId) async {
    return done;
  }

  @override
  Future<void> setDone(String companyId, bool value) async {
    done = value;
  }
}

class _FakeRunner implements MigrationRunner {
  int calls = 0;

  @override
  Future<MigrationReport> run({
    required String companyId,
    required bool dryRun,
    MigrationProgressCallback? onProgress,
  }) async {
    calls += 1;
    onProgress?.call(const MigrationProgress(phase: 'x', migrated: 1, total: 1));
    return const MigrationReport(migrated: 1, skipped: 0);
  }
}

void main() {
  test('flag true ise migrasyon çalışmıyor', () async {
    final flags = _FakeFlagStore(done: true);
    final runner = _FakeRunner();

    final controller = MigrationStateController(flagStore: flags, runner: runner);

    await controller.ensureMigrated(isLoggedIn: true, companyId: 'c1');

    expect(runner.calls, 0);
    expect(controller.state.status, MigrationStatus.done);
  });

  test('chunkList doğru parçalıyor', () {
    final items = List<int>.generate(10, (i) => i);
    final chunks = chunkList(items, 4);

    expect(chunks.length, 3);
    expect(chunks[0], [0, 1, 2, 3]);
    expect(chunks[1], [4, 5, 6, 7]);
    expect(chunks[2], [8, 9]);
  });
}
