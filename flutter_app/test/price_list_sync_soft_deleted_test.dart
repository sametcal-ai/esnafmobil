import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/core/firestore/firestore_refs.dart';
import 'package:flutter_app/core/models/auditable.dart';
import 'package:flutter_app/features/pricing/data/price_list_repository.dart';
import 'package:flutter_app/features/products/data/product_repository.dart';

void main() {
  test('syncMissingItemsFromProductsWithMargin recreates soft-deleted items', () async {
    final db = FakeFirebaseFirestore();
    final refs = FirestoreRefs(db);

    final productRepo = ProductRepository(refs, currentUserId: 'u1');
    final priceListRepo = PriceListRepository(refs, productRepo, currentUserId: 'u1');

    final product = await productRepo.createProduct(
      companyId: 'c1',
      name: 'P1',
      brand: '',
      barcode: '111',
      tags: const <String>[],
      lastPurchasePrice: 100,
      marginPercent: 20,
      salePrice: 999,
      currentUserId: 'u1',
    );

    // Ürün daha önce fiyat listesine eklenmiş ve soft delete edilmiş.
    await db
        .collection('companies')
        .doc('c1')
        .collection('priceLists')
        .doc('pl1')
        .collection('items')
        .doc(product.id)
        .set({
      'id': product.id,
      'productId': product.id,
      'purchasePrice': 1,
      'salePrice': 1,
      'isInherited': false,
      ...AuditMeta.create(createdBy: 'u0', now: DateTime(2024)).softDelete(modifiedBy: 'u0').toFirestoreMap(),
    });

    await priceListRepo.syncMissingItemsFromProductsWithMargin(
      companyId: 'c1',
      priceListId: 'pl1',
      currentUserId: 'u1',
    );

    final snap = await db
        .collection('companies')
        .doc('c1')
        .collection('priceLists')
        .doc('pl1')
        .collection('items')
        .doc(product.id)
        .get();

    final data = snap.data()!;
    expect(data['isDeleted'], false);
    expect(data['isVisible'], true);
    expect(data['isActived'], true);
    expect((data['salePrice'] as num).toDouble(), closeTo(120, 0.0001));
    expect((data['purchasePrice'] as num).toDouble(), closeTo(100, 0.0001));
  });
}
