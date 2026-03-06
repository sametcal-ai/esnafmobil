import 'package:flutter/foundation.dart';

@immutable
class Product {
  final String id;
  final String name;
  final String barcode;
  final double unitPrice;

  const Product({
    required this.id,
    required this.name,
    required this.barcode,
    required this.unitPrice,
  });
}

@immutable
class CartItem {
  final Product product;
  final int quantity;

  const CartItem({
    required this.product,
    required this.quantity,
  });

  double get lineTotal => product.unitPrice * quantity;

  CartItem copyWith({
    Product? product,
    int? quantity,
  }) {
    return CartItem(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
    );
  }
}

enum DiscountType {
  none,
  percentage,
  fixed,
}

@immutable
class PosState {
  final List<CartItem> items;
  final DiscountType discountType;
  /// For [DiscountType.percentage], e.g. 10.0 for 10%
  final double discountValue;
  /// A single held cart (simple initial implementation).
  final List<CartItem>? heldItems;
  /// Toplam KDV / vergi tutarı (ör. %20 KDV için).
  final double taxRate;

  const PosState({
    required this.items,
    required this.discountType,
    required this.discountValue,
    required this.heldItems,
    required this.taxRate,
  });

  factory PosState.initial() {
    return const PosState(
      items: <CartItem>[],
      discountType: DiscountType.none,
      discountValue: 0,
      heldItems: null,
      taxRate: 0,
    );
  }

  double get subtotal {
    return items.fold(0, (sum, item) => sum + item.lineTotal);
  }

  double get discountAmount {
    switch (discountType) {
      case DiscountType.none:
        return 0;
      case DiscountType.percentage:
        return subtotal * (discountValue / 100);
      case DiscountType.fixed:
        return discountValue.clamp(0, subtotal);
    }
  }

  /// İndirim sonrası ara toplam (vergi hariç).
  double get netTotal {
    final result = subtotal - discountAmount;
    if (result < 0) return 0;
    return result;
  }

  /// Vergi tutarı. Örneğin taxRate = 20 ise %20 KDV.
  double get taxAmount {
    if (taxRate <= 0) return 0;
    return netTotal * (taxRate / 100);
  }

  /// Vergi dahil toplam.
  double get total {
    final result = netTotal + taxAmount;
    if (result < 0) return 0;
    return result;
  }

  bool get hasItems => items.isNotEmpty;

  bool get hasHeldItems => heldItems != null && heldItems!.isNotEmpty;

  PosState copyWith({
    List<CartItem>? items,
    DiscountType? discountType,
    double? discountValue,
    List<CartItem>? heldItems,
    double? taxRate,
  }) {
    return PosState(
      items: items ?? this.items,
      discountType: discountType ?? this.discountType,
      discountValue: discountValue ?? this.discountValue,
      heldItems: heldItems ?? this.heldItems,
      taxRate: taxRate ?? this.taxRate,
    );
  }
}