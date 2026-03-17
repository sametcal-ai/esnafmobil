import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/core/firestore/firestore_refs.dart';
import 'package:flutter_app/features/customers/data/customer_repository.dart';
import 'package:flutter_app/features/sales/data/sales_repository.dart';

void main() {
  group('AuditMeta actor fields', () {
    test('CustomerRepository writes createdBy/modifiedBy from current user', () async {
      final db = FakeFirebaseFirestore();
      final refs = FirestoreRefs(db);

      final repo = CustomerRepository(refs, currentUserId: 'u1');

      final created = await repo.createCustomer(
        companyId: 'c1',
        name: 'Alice',
      );

      final createdSnap = await db
          .collection('companies')
          .doc('c1')
          .collection('customers')
          .doc(created.id)
          .get();

      final createdData = createdSnap.data()!;
      expect(createdData['createdBy'], 'u1');
      expect(createdData['modifiedBy'], 'u1');

      final updated = await repo.updateCustomer(
        'c1',
        created.copyWith(name: 'Alice Updated'),
        currentUserId: 'u2',
      );

      expect(updated, isNotNull);

      final updatedSnap = await db
          .collection('companies')
          .doc('c1')
          .collection('customers')
          .doc(created.id)
          .get();

      final updatedData = updatedSnap.data()!;
      expect(updatedData['createdBy'], 'u1');
      expect(updatedData['modifiedBy'], 'u2');
      expect(updatedData['versionNo'], 2);

      await repo.deleteCustomer(
        'c1',
        created.id,
        currentUserId: 'u3',
      );

      final deletedSnap = await db
          .collection('companies')
          .doc('c1')
          .collection('customers')
          .doc(created.id)
          .get();

      final deletedData = deletedSnap.data()!;
      expect(deletedData['isDeleted'], true);
      expect(deletedData['modifiedBy'], 'u3');
    });

    test('SalesRepository writes createdBy from current user', () async {
      final db = FakeFirebaseFirestore();
      final refs = FirestoreRefs(db);

      final repo = SalesRepository(refs, currentUserId: 'u9');

      final saleId = await repo.createSale(
        companyId: 'c1',
        customerId: null,
        subtotal: 10,
        discount: 0,
        vat: 0,
        total: 10,
        paymentMethod: 'cash',
        items: const [],
      );

      final snap = await db
          .collection('companies')
          .doc('c1')
          .collection('sales')
          .doc(saleId)
          .get();

      final data = snap.data()!;
      expect(data['createdBy'], 'u9');
      expect(data['modifiedBy'], 'u9');
    });
  });
}
