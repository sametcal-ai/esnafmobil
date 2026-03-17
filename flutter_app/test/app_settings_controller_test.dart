import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_app/core/config/app_settings.dart';
import 'package:flutter_app/core/firestore/firestore_refs.dart';
import 'package:flutter_app/features/auth/domain/current_user_provider.dart';
import 'package:flutter_app/features/auth/domain/user.dart';
import 'package:flutter_app/features/company/domain/active_company_provider.dart';
import 'package:flutter_app/features/company/domain/company_memberships_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class TestActiveCompanyController extends ActiveCompanyController {
  @override
  String? build() => null;

  @override
  Future<void> setActiveCompanyId(String companyId) async {
    state = companyId;
  }

  @override
  Future<void> clear() async {
    state = null;
  }
}

Future<void> _flush() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

void main() {
  test('settings doc missing: non-admin uses defaults and does not create doc',
      () async {
    final fakeDb = FakeFirebaseFirestore();

    final container = ProviderContainer(
      overrides: [
        firestoreRefsProvider.overrideWithValue(FirestoreRefs(fakeDb)),
        currentUserProvider.overrideWith((ref) {
          return const User(id: 'u1', email: 'u1', role: UserRole.cashier);
        }),
        activeCompanyIdProvider.overrideWith(TestActiveCompanyController.new),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(appSettingsProvider), AppSettings.initial());

    await (container.read(activeCompanyIdProvider.notifier)
            as TestActiveCompanyController)
        .setActiveCompanyId('c1');

    await _flush();

    final doc = await fakeDb.doc('companies/c1/settings/system').get();
    expect(doc.exists, false);
    expect(container.read(appSettingsProvider), AppSettings.initial());
  });

  test('settings doc missing: admin auto-creates defaults', () async {
    final fakeDb = FakeFirebaseFirestore();

    final container = ProviderContainer(
      overrides: [
        firestoreRefsProvider.overrideWithValue(FirestoreRefs(fakeDb)),
        currentUserProvider.overrideWith((ref) {
          return const User(id: 'u1', email: 'u1', role: UserRole.admin);
        }),
        activeCompanyIdProvider.overrideWith(TestActiveCompanyController.new),
      ],
    );
    addTearDown(container.dispose);

    // Ensure the settings controller is instantiated.
    container.read(appSettingsProvider);

    await (container.read(activeCompanyIdProvider.notifier)
            as TestActiveCompanyController)
        .setActiveCompanyId('c1');

    await _flush();

    final doc = await fakeDb.doc('companies/c1/settings/system').get();
    expect(doc.exists, true);
    expect(doc.data(), AppSettings.initial().toMap());
  });

  test('company change updates settings per-company (stream)', () async {
    final fakeDb = FakeFirebaseFirestore();

    await fakeDb.doc('companies/c1/settings/system').set({
      'barcodeScanDelaySeconds': 1.0,
      'defaultMarginPercent': 10.0,
      'productDefaultMarginPercent': 11.0,
      'searchFilterMinChars': 3,
      'movementsPageSize': 50,
    });

    await fakeDb.doc('companies/c2/settings/system').set({
      'barcodeScanDelaySeconds': 2.5,
      'defaultMarginPercent': 20.0,
      'productDefaultMarginPercent': 21.0,
      'searchFilterMinChars': 4,
      'movementsPageSize': 25,
    });

    final container = ProviderContainer(
      overrides: [
        firestoreRefsProvider.overrideWithValue(FirestoreRefs(fakeDb)),
        currentUserProvider.overrideWith((ref) {
          return const User(id: 'u1', email: 'u1', role: UserRole.admin);
        }),
        activeCompanyIdProvider.overrideWith(TestActiveCompanyController.new),
      ],
    );
    addTearDown(container.dispose);

    // Ensure the settings controller is instantiated and listening to company changes.
    container.read(appSettingsProvider);

    final active =
        container.read(activeCompanyIdProvider.notifier) as TestActiveCompanyController;

    await active.setActiveCompanyId('c1');
    await _flush();

    expect(
      container.read(appSettingsProvider),
      AppSettings.fromMap(
        (await fakeDb.doc('companies/c1/settings/system').get()).data()!,
      ),
    );

    await active.setActiveCompanyId('c2');
    await _flush();

    expect(
      container.read(appSettingsProvider),
      AppSettings.fromMap(
        (await fakeDb.doc('companies/c2/settings/system').get()).data()!,
      ),
    );
  });
}
