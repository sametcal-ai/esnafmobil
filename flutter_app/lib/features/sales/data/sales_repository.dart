import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firestore/firestore_refs.dart';
import '../../../core/models/auditable.dart';
import '../../auth/domain/current_user_provider.dart';

class SaleItem {
  final String productId;
  final String productName;
  final String? barcode;
  final int quantity;
  final double unitPrice;
  final double lineTotal;

  const SaleItem({
    required this.productId,
    required this.productName,
    required this.barcode,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
  });

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'barcode': barcode,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'lineTotal': lineTotal,
    };
  }

  factory SaleItem.fromMap(Map map) {
    final m = Map<String, dynamic>.from(map);
    final quantity = (m['quantity'] as num?)?.toInt() ?? 0;
    final unitPrice = (m['unitPrice'] as num?)?.toDouble() ?? 0;
    final lineTotal = (m['lineTotal'] as num?)?.toDouble() ?? (quantity * unitPrice).toDouble();

    return SaleItem(
      productId: (m['productId'] as String?) ?? '',
      productName: (m['productName'] as String?) ?? '',
      barcode: m['barcode'] as String?,
      quantity: quantity,
      unitPrice: unitPrice,
      lineTotal: lineTotal,
    );
  }
}

class Sale {
  final String id;
  final String? customerId;
  final DateTime createdAt;
  final double subtotal;
  final double discount;
  final double vat;
  final double total;
  final String paymentMethod;
  final List<SaleItem> items;
  final AuditMeta meta;

  const Sale({
    required this.id,
    required this.customerId,
    required this.createdAt,
    required this.subtotal,
    required this.discount,
    required this.vat,
    required this.total,
    required this.paymentMethod,
    required this.items,
    required this.meta,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customerId': customerId,
      'createdAt': Timestamp.fromDate(createdAt),
      'subtotal': subtotal,
      'discount': discount,
      'vat': vat,
      'total': total,
      'paymentMethod': paymentMethod,
      'items': items.map((i) => i.toMap()).toList(growable: false),
      ...meta.toMap(),
    };
  }

  factory Sale.fromMap(Map dynamicMap) {
    final map = Map<String, dynamic>.from(dynamicMap as Map);

    final createdAtRaw = map['createdAt'];
    final createdAt = createdAtRaw is Timestamp
        ? createdAtRaw.toDate()
        : createdAtRaw is int
            ? DateTime.fromMillisecondsSinceEpoch(createdAtRaw)
            : DateTime.now();

    final itemsRaw = map['items'];
    final items = <SaleItem>[];
    if (itemsRaw is List) {
      for (final item in itemsRaw.whereType<Map>()) {
        items.add(SaleItem.fromMap(item));
      }
    }

    final meta = AuditMeta.fromMap(map, fallbackCreatedAt: createdAt);

    return Sale(
      id: (map['id'] as String?) ?? '',
      customerId: map['customerId'] as String?,
      createdAt: createdAt,
      subtotal: (map['subtotal'] as num?)?.toDouble() ?? 0,
      discount: (map['discount'] as num?)?.toDouble() ?? 0,
      vat: (map['vat'] as num?)?.toDouble() ?? 0,
      total: (map['total'] as num?)?.toDouble() ?? 0,
      paymentMethod: (map['paymentMethod'] as String?) ?? 'cash',
      items: items,
      meta: meta,
    );
  }
}

class SalesRepository {
  SalesRepository(
    this._refs, {
    String? currentUserId,
  }) : _currentUserId = currentUserId;

  final FirestoreRefs _refs;
  final String? _currentUserId;

  String _requireActor([String? overrideUserId]) {
    final actor = (overrideUserId ?? _currentUserId) ?? '';
    if (actor.isEmpty) {
      throw StateError('currentUserId is required for this operation');
    }
    return actor;
  }

  Stream<List<Sale>> watchSales(String companyId) {
    return _refs
        .sales(companyId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) {
      final entries = snap.docs
          .map((d) => d.data())
          .whereType<Map<String, dynamic>>()
          .map(Sale.fromMap)
          .where((s) => !s.meta.isDeleted && s.meta.isVisible && s.meta.isActived)
          .toList(growable: false);
      return entries;
    });
  }

  Future<List<Sale>> getAllSales(String companyId) async {
    final snap = await _refs.sales(companyId).orderBy('createdAt', descending: true).get();
    return snap.docs
        .map((d) => d.data())
        .whereType<Map<String, dynamic>>()
        .map(Sale.fromMap)
        .where((s) => !s.meta.isDeleted && s.meta.isVisible && s.meta.isActived)
        .toList(growable: false);
  }

  Future<Sale?> getSaleById(
    String companyId,
    String id,
  ) async {
    final snap = await _refs.sales(companyId).doc(id).get();
    final data = snap.data();
    if (data == null) return null;
    final sale = Sale.fromMap(data);
    if (sale.meta.isDeleted || !sale.meta.isVisible || !sale.meta.isActived) return null;
    return sale;
  }

  Future<Map<String, Sale>> getSalesByIds(
    String companyId,
    List<String> ids,
  ) async {
    if (ids.isEmpty) return <String, Sale>{};

    final uniqueIds = ids.toSet().toList(growable: false);
    final sales = await Future.wait(
      uniqueIds.map((id) => getSaleById(companyId, id)),
    );

    final map = <String, Sale>{};
    for (final sale in sales.whereType<Sale>()) {
      map[sale.id] = sale;
    }
    return map;
  }

  Future<String> createSale({
    required String companyId,
    String? customerId,
    required double subtotal,
    required double discount,
    required double vat,
    required double total,
    required String paymentMethod,
    required List<SaleItem> items,
    String? currentUserId,
  }) async {
    final now = DateTime.now();
    final id = now.microsecondsSinceEpoch.toString();

    final actor = _requireActor(currentUserId);
    final meta = AuditMeta.create(createdBy: actor, now: now);

    final sale = Sale(
      id: id,
      customerId: customerId,
      createdAt: now,
      subtotal: subtotal,
      discount: discount,
      vat: vat,
      total: total,
      paymentMethod: paymentMethod,
      items: items,
      meta: meta,
    );

    await _refs.sales(companyId).doc(id).set(sale.toMap(), SetOptions(merge: true));
    return id;
  }

  Future<bool> softDeleteSaleCascade({
    required String companyId,
    required Sale sale,
    String? currentUserId,
  }) async {
    final actor = _requireActor(currentUserId);
    final now = DateTime.now();

    final deletedSaleMeta = sale.meta.softDelete(modifiedBy: actor, now: now);

    try {
      // Transaction API'si Query okumayı desteklemediği için ilgili kayıtları önce okuyoruz.
      final customerId = sale.customerId;
      final ledgerDocs = (customerId != null && customerId.trim().isNotEmpty)
          ? await _refs
              .customerLedger(companyId, customerId)
              .where('saleId', isEqualTo: sale.id)
              .get()
          : null;

      final stockDocs = await _refs.stockEntries(companyId).where('saleId', isEqualTo: sale.id).get();

      await FirebaseFirestore.instance.runTransaction((tx) async {
        tx.set(
          _refs.sales(companyId).doc(sale.id),
          {
            ...sale.toMap(),
            ...deletedSaleMeta.toMap(),
            'createdAt': Timestamp.fromDate(sale.createdAt),
          },
          SetOptions(merge: true),
        );

        // Eğer veresiye satış ise (customer ledger'a yazıldıysa) ledger kayıtlarını soft delete.
        if (ledgerDocs != null) {
          for (final d in ledgerDocs.docs) {
            final data = d.data();
            final meta = AuditMeta.fromMap(data);
            if (meta.isDeleted) continue;
            final deleted = meta.softDelete(modifiedBy: actor, now: now);
            tx.set(
              d.reference,
              {
                ...data,
                ...deleted.toMap(),
              },
              SetOptions(merge: true),
            );
          }
        }

        // İlgili satıştan oluşan stok çıkış (ve/veya düzeltme) kayıtlarını soft delete.
        for (final d in stockDocs.docs) {
          final data = d.data();
          final meta = AuditMeta.fromMap(data);
          if (meta.isDeleted) continue;
          final deleted = meta.softDelete(modifiedBy: actor, now: now);
          tx.set(
            d.reference,
            {
              ...data,
              ...deleted.toMap(),
            },
            SetOptions(merge: true),
          );
        }
      });
    } catch (_) {
      return false;
    }

    return true;
  }
}

final salesRepositoryProvider = Provider<SalesRepository>((ref) {
  final refs = ref.watch(firestoreRefsProvider);
  final currentUserId = ref.watch(currentUserIdProvider);
  return SalesRepository(refs, currentUserId: currentUserId);
});
