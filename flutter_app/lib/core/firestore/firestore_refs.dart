import 'package:cloud_firestore/cloud_firestore.dart';

import 'models/company.dart';
import 'models/company_member.dart';
import 'models/store.dart';
import 'models/product.dart';

class FirestoreRefs {
  FirestoreRefs(this._db);

  final FirebaseFirestore _db;

  static FirestoreRefs instance() => FirestoreRefs(FirebaseFirestore.instance);

  CollectionReference<Company> companies() {
    return _db.collection('companies').withConverter<Company>(
          fromFirestore: (snap, _) => Company.fromDoc(snap),
          toFirestore: (company, _) => company.toMap(),
        );
  }

  DocumentReference<Company> company(String companyId) {
    return companies().doc(companyId);
  }

  CollectionReference<CompanyMember> members(String companyId) {
    return company(companyId).collection('members').withConverter<CompanyMember>(
          fromFirestore: (snap, _) => CompanyMember.fromDoc(snap),
          toFirestore: (m, _) => m.toMap(),
        );
  }

  Query<CompanyMember> membersGroupByUid(String uid) {
    // NOTE:
    // Firestore collectionGroup queries cannot filter by FieldPath.documentId()
    // using a bare document id. The native SDK expects a document *path*.
    // To keep queries simple, we store `uid` inside the member document as well.
    return _db
        .collectionGroup('members')
        .where('uid', isEqualTo: uid)
        .withConverter<CompanyMember>(
          fromFirestore: (snap, _) => CompanyMember.fromDoc(snap),
          toFirestore: (m, _) => m.toMap(),
        );
  }

  DocumentReference<CompanyMember> member(String companyId, String uid) {
    return members(companyId).doc(uid);
  }

  CollectionReference<Store> stores(String companyId) {
    return company(companyId).collection('stores').withConverter<Store>(
          fromFirestore: (snap, _) => Store.fromDoc(snap),
          toFirestore: (s, _) => s.toMap(),
        );
  }

  DocumentReference<Store> store(String companyId, String storeId) {
    return stores(companyId).doc(storeId);
  }

  CollectionReference<Product> productsRef(String companyId) {
    return company(companyId).collection('products').withConverter<Product>(
          fromFirestore: (snap, _) => Product.fromDoc(snap),
          toFirestore: (p, _) => p.toFirestoreMap(),
        );
  }

  /// İş verileri (şimdilik Map tabanlı) — tümü company altında.
  /// Products için typed ref: [productsRef]
  CollectionReference<Map<String, dynamic>> products(String companyId) =>
      company(companyId).collection('products');

  CollectionReference<Map<String, dynamic>> customers(String companyId) =>
      company(companyId).collection('customers');

  CollectionReference<Map<String, dynamic>> suppliers(String companyId) =>
      company(companyId).collection('suppliers');

  CollectionReference<Map<String, dynamic>> sales(String companyId) =>
      company(companyId).collection('sales');

  CollectionReference<Map<String, dynamic>> stockEntries(String companyId) =>
      company(companyId).collection('stockEntries');

  CollectionReference<Map<String, dynamic>> alerts(String companyId) =>
      company(companyId).collection('alerts');

  /// Ledger alt koleksiyonları için önerilen ref.
  CollectionReference<Map<String, dynamic>> customerLedger(
    String companyId,
    String customerId,
  ) =>
      company(companyId).collection('customers').doc(customerId).collection('ledger');

  CollectionReference<Map<String, dynamic>> supplierLedger(
    String companyId,
    String supplierId,
  ) =>
      company(companyId).collection('suppliers').doc(supplierId).collection('ledger');
}
