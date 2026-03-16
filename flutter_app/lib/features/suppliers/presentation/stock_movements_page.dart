import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/money_formatter.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../company/domain/active_company_provider.dart';
import '../../products/data/product_repository.dart';
import '../../products/domain/product.dart';
import '../data/stock_entry_repository.dart';
import '../data/supplier_repository.dart';
import '../domain/stock_entry.dart';
import '../domain/supplier.dart';

final stockMovementsProvider =
    FutureProvider.autoDispose<List<StockEntry>>((ref) async {
  final companyId = ref.watch(activeCompanyIdProvider);
  if (companyId == null) return <StockEntry>[];

  final stockRepo = ref.watch(stockEntryRepositoryProvider);
  return stockRepo.getAllEntries(companyId);
});

class StockMovementsPage extends ConsumerWidget {
  const StockMovementsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final movementsAsync = ref.watch(stockMovementsProvider);

    return AppScaffold(
      title: 'Stok Hareketleri',
      body: movementsAsync.when(
        data: (entries) {
          if (entries.isEmpty) {
            return const Center(
              child: Text('Henüz stok hareketi yok'),
            );
          }

          return FutureBuilder<_StockMovementViewData>(
            future: _buildViewData(entries, ref),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final data = snapshot.data!;
              final productsById = data.productsById;
              final suppliersById = data.suppliersById;

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: entries.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final entry = entries[index];
                  final product = productsById[entry.productId];
                  final supplier = entry.supplierId != null
                      ? suppliersById[entry.supplierId!]
                      : null;

                  final isIncoming =
                      entry.type == StockMovementType.incoming;
                  final quantitySign = isIncoming ? '+' : '-';
                  final quantityColor =
                      isIncoming ? Colors.green.shade700 : Colors.red.shade700;

                  final productName =
                      product?.name ?? 'Ürün: ${entry.productId}';
                  final supplierName =
                      supplier?.name ?? (isIncoming ? 'Tedarikçi yok' : 'Satış');
                  final dateString =
                      '${entry.createdAt.day.toString().padLeft(2, '0')}.'
                      '${entry.createdAt.month.toString().padLeft(2, '0')}.'
                      '${entry.createdAt.year} '
                      '${entry.createdAt.hour.toString().padLeft(2, '0')}:'
                      '${entry.createdAt.minute.toString().padLeft(2, '0')}';

                  return Card(
                    child: ListTile(
                      title: Text(productName),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Tedarikçi / Kaynak: $supplierName'),
                          Text('Tarih: $dateString'),
                          Text(
                            isIncoming ? 'Tür: Giriş' : 'Tür: Çıkış',
                          ),
                          if (entry.unitCost > 0)
                            Text(
                              'Birim alış fiyatı: ${formatMoney(entry.unitCost)}',
                            ),
                        ],
                      ),
                      trailing: Text(
                        '$quantitySign${entry.quantity}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: quantityColor,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(
          child: Text('Stok hareketleri yüklenemedi'),
        ),
      ),
    );
  }

  Future<_StockMovementViewData> _buildViewData(
  List<StockEntry> entries,
  WidgetRef ref,
) async {
  final companyId = ref.read(activeCompanyIdProvider);
  if (companyId == null) {
    return _StockMovementViewData(
      productsById: const <String, Product>{},
      suppliersById: const <String, Supplier>{},
    );
  }

  final productRepo = ref.read(productsRepositoryProvider);
  final supplierRepo = ref.read(supplierRepositoryProvider);

    final productIds = entries.map((e) => e.productId).toSet();
    final supplierIds = entries
        .map((e) => e.supplierId)
        .whereType<String>()
        .toSet();

    final products = await productRepo.getAllProducts(companyId);
    final suppliers = await supplierRepo.getAllSuppliers(companyId);

    final productsById = <String, Product>{
      for (final p in products.where((p) => productIds.contains(p.id)))
        p.id: p,
    };

    final suppliersById = <String, Supplier>{
      for (final s in suppliers.where((s) => supplierIds.contains(s.id)))
        s.id: s,
    };

    return _StockMovementViewData(
      productsById: productsById,
      suppliersById: suppliersById,
    );
  }
}

class _StockMovementViewData {
  final Map<String, Product> productsById;
  final Map<String, Supplier> suppliersById;

  _StockMovementViewData({
    required this.productsById,
    required this.suppliersById,
  });
}