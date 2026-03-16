import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/core/models/auditable.dart';
import 'package:flutter_app/features/products/domain/product.dart';

void main() {
  test('AuditMeta.fromMap parses Firestore Timestamp fields', () {
    final now = DateTime(2024, 1, 2, 3, 4, 5);

    final meta = AuditMeta.fromMap({
      'createdDate': Timestamp.fromDate(now),
      'createdBy': 'u1',
      'modifiedDate': Timestamp.fromDate(now.add(const Duration(hours: 1))),
      'modifiedBy': 'u2',
      'versionNo': 3,
      'versionDate': Timestamp.fromDate(now.add(const Duration(hours: 2))),
      'isLocked': false,
      'isVisible': true,
      'isActived': true,
      'isDeleted': false,
    });

    expect(meta.createdBy, 'u1');
    expect(meta.modifiedBy, 'u2');
    expect(meta.versionNo, 3);
    expect(meta.createdDate, now);
  });

  test('Product.fromMap parses Timestamp externalDate', () {
    final now = DateTime(2024, 5, 6, 7, 8, 9);
    final metaNow = DateTime(2024, 1, 1);

    final product = Product.fromMap({
      'id': 'p1',
      'name': 'Test',
      'brand': 'B',
      'barcode': '123',
      'tags': const ['t1'],
      'stockQuantity': 1,
      'lastPurchasePrice': 2.5,
      'salePrice': 3.0,
      'marginPercent': 10.0,
      'isManualPrice': false,
      'externalDate': Timestamp.fromDate(now),
      'createdDate': Timestamp.fromDate(metaNow),
      'createdBy': 'u',
      'modifiedDate': Timestamp.fromDate(metaNow),
      'modifiedBy': 'u',
      'versionNo': 1,
      'versionDate': Timestamp.fromDate(metaNow),
      'isLocked': false,
      'isVisible': true,
      'isActived': true,
      'isDeleted': false,
    });

    expect(product.externalDate, now);
  });
}
