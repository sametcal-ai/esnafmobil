import 'package:flutter_app/core/firestore/firestore_paths.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('FirestorePaths builds company-scoped paths', () {
    expect(FirestorePaths.company('c1'), 'companies/c1');
    expect(FirestorePaths.member('c1', 'u1'), 'companies/c1/members/u1');
    expect(FirestorePaths.store('c1', 's1'), 'companies/c1/stores/s1');

    expect(FirestorePaths.products('c1'), 'companies/c1/products');
    expect(FirestorePaths.product('c1', 'p1'), 'companies/c1/products/p1');

    expect(FirestorePaths.customers('c1'), 'companies/c1/customers');
    expect(
      FirestorePaths.customerLedger('c1', 'cust1'),
      'companies/c1/customers/cust1/ledger',
    );

    expect(FirestorePaths.alert('c1', 'a1'), 'companies/c1/alerts/a1');
  });
}
