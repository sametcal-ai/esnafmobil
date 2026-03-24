import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/core/config/app_settings.dart';
import 'package:flutter_app/core/firestore/firestore_refs.dart';
import 'package:flutter_app/features/auth/domain/current_user_provider.dart';
import 'package:flutter_app/features/company/domain/active_company_provider.dart';
import 'package:flutter_app/features/pricing/domain/price_list_providers.dart';
import 'package:flutter_app/features/products/data/product_repository.dart';
import 'package:flutter_app/features/sales/domain/pos_controller.dart';
import 'package:flutter_app/features/sales/domain/pos_models.dart';

class _TestActiveCompanyController extends Notifier<String?> {
  @override
  String? build() => 'company_1';
}

class _TestAppSettingsController extends Notifier<AppSettings> {
  @override
  AppSettings build() => AppSettings.initial();
}

void main() {
  test('PosController does not clear cart when dependencies update', () {
    final db = FakeFirebaseFirestore();
    final refs = FirestoreRefs(db);

    final testPriceMapProvider = StateProvider<Map<String, double>>((ref) {
      return const <String, double>{};
    });

    final container = ProviderContainer(
      overrides: [
        activeCompanyIdProvider.overrideWith(_TestActiveCompanyController.new),
        currentUserIdProvider.overrideWithValue('user_1'),
        firestoreRefsProvider.overrideWithValue(refs),
        productsRepositoryProvider.overrideWithValue(
          ProductRepository(refs, currentUserId: 'user_1'),
        ),
        appSettingsProvider.overrideWith(_TestAppSettingsController.new),
        activePriceListPriceMapProvider.overrideWith((ref) {
          return ref.watch(testPriceMapProvider);
        }),
      ],
    );

    addTearDown(container.dispose);

    final controller = container.read(posControllerProvider.notifier);

    controller.loadCartItems(
      const [
        CartItem(
          product: Product(
            id: 'p1',
            name: 'Test',
            barcode: '123',
            unitPrice: 10,
          ),
          quantity: 2,
        ),
      ],
    );

    expect(container.read(posControllerProvider).items, hasLength(1));

    // Dependency update that would previously trigger build() and clear the cart.
    container.read(testPriceMapProvider.notifier).state = const {'p1': 10};

    expect(container.read(posControllerProvider).items, hasLength(1));
  });
}
