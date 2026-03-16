import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/firestore/firestore_refs.dart';
import '../../company/domain/active_company_provider.dart';
import '../../company/domain/company_memberships_provider.dart';
import '../domain/pos_models.dart';

class HeldSale {
  final String id;
  final String name;
  final DateTime createdAt;
  final List<CartItem> items;
  final double total;

  const HeldSale({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.items,
    required this.total,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'createdAt': Timestamp.fromDate(createdAt),
      'total': total,
      'items': items
          .map(
            (i) => {
              'product': {
                'id': i.product.id,
                'name': i.product.name,
                'barcode': i.product.barcode,
                'unitPrice': i.product.unitPrice,
              },
              'quantity': i.quantity,
            },
          )
          .toList(growable: false),
    };
  }

  factory HeldSale.fromMap(Map<dynamic, dynamic> map) {
    final itemsRaw = (map['items'] as List?) ?? const [];
    final items = itemsRaw
        .whereType<Map>()
        .map(
          (raw) {
            final productMap = (raw['product'] as Map?) ?? const {};
            final product = Product(
              id: (productMap['id'] ?? '').toString(),
              name: (productMap['name'] ?? '').toString(),
              barcode: (productMap['barcode'] ?? '').toString(),
              unitPrice: (productMap['unitPrice'] as num?)?.toDouble() ?? 0,
            );
            return CartItem(
              product: product,
              quantity: (raw['quantity'] as num?)?.toInt() ?? 0,
            );
          },
        )
        .where((i) => i.product.id.isNotEmpty && i.quantity > 0)
        .toList(growable: false);

    final createdAtRaw = map['createdAt'];
    final createdAt = createdAtRaw is Timestamp
        ? createdAtRaw.toDate()
        : createdAtRaw is num
            ? DateTime.fromMillisecondsSinceEpoch(createdAtRaw.toInt())
            : DateTime.now();

    return HeldSale(
      id: (map['id'] ?? '').toString(),
      name: (map['name'] ?? '').toString(),
      createdAt: createdAt,
      items: items,
      total: (map['total'] as num?)?.toDouble() ?? 0,
    );
  }
}

class HeldSalesRepository {
  static const _uuid = Uuid();

  HeldSalesRepository([FirestoreRefs? refs]) : _refs = refs ?? FirestoreRefs.instance();

  final FirestoreRefs _refs;

  CollectionReference<Map<String, dynamic>> _col(String companyId) {
    return _refs.company(companyId).collection('heldSales');
  }

  Stream<List<HeldSale>> watchHeldSales(String companyId) {
    return _col(companyId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) {
      return snap.docs
          .map((d) => d.data())
          .whereType<Map<String, dynamic>>()
          .map(HeldSale.fromMap)
          .toList(growable: false);
    });
  }

  Future<void> holdSale({
    required String companyId,
    required String name,
    required List<CartItem> items,
    required double total,
  }) async {
    if (items.isEmpty) return;

    final trimmedName = name.trim();
    final resolvedName = trimmedName.isEmpty ? 'Bekleyen Satış' : trimmedName;

    final heldSale = HeldSale(
      id: _uuid.v4(),
      name: resolvedName,
      createdAt: DateTime.now(),
      items: items,
      total: total,
    );

    await _col(companyId).doc(heldSale.id).set(heldSale.toMap(), SetOptions(merge: true));
  }

  Future<HeldSale?> takeSale(String companyId, String id) async {
    final ref = _col(companyId).doc(id);
    final snap = await ref.get();
    final data = snap.data();
    if (data == null) return null;

    final sale = HeldSale.fromMap(data);
    await ref.delete();
    return sale;
  }

  Future<void> deleteSale(String companyId, String id) async {
    await _col(companyId).doc(id).delete();
  }
}

final heldSalesRepositoryProvider = Provider<HeldSalesRepository>((ref) {
  final refs = ref.watch(firestoreRefsProvider);
  return HeldSalesRepository(refs);
});

final heldSalesProvider = StreamProvider.autoDispose<List<HeldSale>>((ref) {
  final companyId = ref.watch(activeCompanyIdProvider);
  if (companyId == null) {
    return const Stream<List<HeldSale>>.empty();
  }
  final repo = ref.watch(heldSalesRepositoryProvider);
  return repo.watchHeldSales(companyId);
});
