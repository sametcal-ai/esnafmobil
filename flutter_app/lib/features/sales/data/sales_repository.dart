import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/models/auditable.dart';

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
}

class Sale {
  final String id;
  final String? customerId;
  final DateTime createdAt;
  final double subtotal;
  final double discount;
  final double vat;
  final double total;
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
    required this.items,
    required this.meta,
  });
}

class SalesRepository {
  static const String salesBoxName = 'sales';

  Box get _box => Hive.box(salesBoxName);

  /// Tüm satışları en yeni en üstte döner.
  Future<List<Sale>> getAllSales() async {
    final entries = <Sale>[];

    for (final dynamic raw in _box.values) {
      if (raw is! Map) continue;
      final map = Map<String, dynamic>.from(raw as Map);

      final createdAtMs = map['createdAt'];
      final createdAt = createdAtMs is int
          ? DateTime.fromMillisecondsSinceEpoch(createdAtMs)
          : DateTime.now();

      final itemsRaw = map['items'];
      final items = <SaleItem>[];
      if (itemsRaw is List) {
        for (final dynamic itemRaw in itemsRaw) {
          if (itemRaw is! Map) continue;
          final imap = Map<String, dynamic>.from(itemRaw as Map);
          final quantity = (imap['quantity'] as num?)?.toInt() ?? 0;
          final unitPrice = (imap['unitPrice'] as num?)?.toDouble() ?? 0;
          final lineTotal = (imap['lineTotal'] as num?)?.toDouble() ??
              (quantity * unitPrice).toDouble();
          items.add(
            SaleItem(
              productId: (imap['productId'] as String?) ?? '',
              productName: (imap['productName'] as String?) ?? '',
              barcode: imap['barcode'] as String?,
              quantity: quantity,
              unitPrice: unitPrice,
              lineTotal: lineTotal,
            ),
          );
        }
      }

      final meta = AuditMeta.fromMap(
        map,
        fallbackCreatedAt: createdAt,
      );

      final sale = Sale(
        id: (map['id'] as String?) ?? '',
        customerId: map['customerId'] as String?,
        createdAt: createdAt,
        subtotal: (map['subtotal'] as num?)?.toDouble() ?? 0,
        discount: (map['discount'] as num?)?.toDouble() ?? 0,
        vat: (map['vat'] as num?)?.toDouble() ?? 0,
        total: (map['total'] as num?)?.toDouble() ?? 0,
        items: items,
        meta: meta,
      );

      if (!sale.meta.isDeleted && sale.meta.isVisible && sale.meta.isActived) {
        entries.add(sale);
      }
    }

    entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return entries;
  }

  /// Tek bir satış kaydını ID'ye göre getirir.
  Future<Sale?> getSaleById(String id) async {
    final raw = _box.get(id);
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw as Map);

    final createdAtMs = map['createdAt'];
    final createdAt = createdAtMs is int
        ? DateTime.fromMillisecondsSinceEpoch(createdAtMs)
        : DateTime.now();

    final itemsRaw = map['items'];
    final items = <SaleItem>[];
    if (itemsRaw is List) {
      for (final dynamic itemRaw in itemsRaw) {
        if (itemRaw is! Map) continue;
        final imap = Map<String, dynamic>.from(itemRaw as Map);
        final quantity = (imap['quantity'] as num?)?.toInt() ?? 0;
        final unitPrice = (imap['unitPrice'] as num?)?.toDouble() ?? 0;
        final lineTotal = (imap['lineTotal'] as num?)?.toDouble() ??
            (quantity * unitPrice).toDouble();
        items.add(
          SaleItem(
            productId: (imap['productId'] as String?) ?? '',
            productName: (imap['productName'] as String?) ?? '',
            barcode: imap['barcode'] as String?,
            quantity: quantity,
            unitPrice: unitPrice,
            lineTotal: lineTotal,
          ),
        );
      }
    }

    final meta = AuditMeta.fromMap(
      map,
      fallbackCreatedAt: createdAt,
    );

    return Sale(
      id: (map['id'] as String?) ?? id,
      customerId: map['customerId'] as String?,
      createdAt: createdAt,
      subtotal: (map['subtotal'] as num?)?.toDouble() ?? 0,
      discount: (map['discount'] as num?)?.toDouble() ?? 0,
      vat: (map['vat'] as num?)?.toDouble() ?? 0,
      total: (map['total'] as num?)?.toDouble() ?? 0,
      items: items,
      meta: meta,
    );
  }

  /// Verilen satış ID listesini tek seferde yükler.
  /// Parametrede tekrar eden ID'ler varsa, sonuçta her ID için tek bir sorgu yapılır.
  Future<Map<String, Sale>> getSalesByIds(Iterable<String> ids) async {
    final uniqueIds = ids.toSet();
    final result = <String, Sale>{};

    for (final id in uniqueIds) {
      final sale = await getSaleById(id);
      if (sale != null) {
        result[id] = sale;
      }
    }

    return result;
  }

  Future<String> createSale({
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

    final actor = currentUserId ?? 'system';
    final meta = AuditMeta.create(
      createdBy: actor,
      now: now,
    );

    final map = <String, dynamic>{
      'id': id,
      'customerId': customerId,
      'createdAt': now.millisecondsSinceEpoch,
      'subtotal': subtotal,
      'discount': discount,
      'vat': vat,
      'total': total,
      'paymentMethod': paymentMethod,
      'items': items
          .map(
            (i) => {
              'productId': i.productId,
              'productName': i.productName,
              'barcode': i.barcode,
              'quantity': i.quantity,
              'unitPrice': i.unitPrice,
              'lineTotal': i.lineTotal,
            },
          )
          .toList(),
      ...meta.toMap(),
    };

    await _box.put(id, map);
    return id;
  }
}