import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

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
      'createdAt': createdAt.millisecondsSinceEpoch,
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

  static HeldSale fromMap(Map<dynamic, dynamic> map) {
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

    final createdAtMs = (map['createdAt'] as num?)?.toInt();

    return HeldSale(
      id: (map['id'] ?? '').toString(),
      name: (map['name'] ?? '').toString(),
      createdAt: createdAtMs != null
          ? DateTime.fromMillisecondsSinceEpoch(createdAtMs)
          : DateTime.now(),
      items: items,
      total: (map['total'] as num?)?.toDouble() ?? 0,
    );
  }
}

class HeldSalesController extends StateNotifier<List<HeldSale>> {
  final Box _box;
  final Uuid _uuid;

  HeldSalesController(this._box, {Uuid? uuid})
      : _uuid = uuid ?? const Uuid(),
        super(const []) {
    _reload();
  }

  void _reload() {
    final values = _box.values.whereType<Map>().toList(growable: false);
    final sales = values.map(HeldSale.fromMap).where((s) => s.id.isNotEmpty);

    state = sales.toList(growable: false)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<void> holdSale({
    required String name,
    required List<CartItem> items,
    required double total,
  }) async {
    final trimmedName = name.trim();
    if (items.isEmpty) return;

    final resolvedName = trimmedName.isEmpty
        ? 'Bekleyen Satış #${_box.length + 1}'
        : trimmedName;

    final heldSale = HeldSale(
      id: _uuid.v4(),
      name: resolvedName,
      createdAt: DateTime.now(),
      items: items,
      total: total,
    );

    await _box.put(heldSale.id, heldSale.toMap());
    _reload();
  }

  HeldSale? getById(String id) {
    final raw = _box.get(id);
    if (raw is! Map) return null;
    return HeldSale.fromMap(raw);
  }

  Future<HeldSale?> takeSale(String id) async {
    final sale = getById(id);
    if (sale == null) return null;
    await _box.delete(id);
    _reload();
    return sale;
  }

  Future<void> deleteSale(String id) async {
    await _box.delete(id);
    _reload();
  }
}

final heldSalesControllerProvider =
    StateNotifierProvider<HeldSalesController, List<HeldSale>>((ref) {
  final box = Hive.box('held_sales');
  return HeldSalesController(box);
});
