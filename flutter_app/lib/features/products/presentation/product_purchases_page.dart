import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/money_formatter.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../suppliers/data/stock_entry_repository.dart';
import '../../suppliers/domain/stock_entry.dart';
import '../../company/domain/active_company_provider.dart';
import '../data/product_repository.dart';
import '../domain/product.dart';

class ProductPurchasesPage extends ConsumerStatefulWidget {
  final String productId;

  const ProductPurchasesPage({super.key, required this.productId});

  @override
  ConsumerState<ProductPurchasesPage> createState() => _ProductPurchasesPageState();
}

class _ProductPurchasesPageState extends ConsumerState<ProductPurchasesPage> {
  Product? _product;
  List<StockEntry> _purchases = const [];
  bool _loading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final companyId = ref.read(activeCompanyIdProvider);
    if (companyId == null) {
      setState(() {
        _loading = false;
        _errorMessage = 'Aktif firma seçilmedi';
      });
      return;
    }

    final productRepo = ref.read(productsRepositoryProvider);
    final stockRepo = ref.read(stockEntryRepositoryProvider);

    try {
      final product = await productRepo.getProductById(companyId, widget.productId);
      if (!mounted) return;
      if (product == null) {
        setState(() {
          _loading = false;
          _errorMessage = 'Ürün bulunamadı';
        });
        return;
      }

      final allEntries = await stockRepo.getAllEntries(companyId);
      final purchases = allEntries.where((e) {
        if (e.productId != product.id) return false;
        if (e.type != StockMovementType.incoming) return false;
        if (e.meta.isDeleted || !e.meta.isVisible || !e.meta.isActived) {
          return false;
        }
        return true;
      }).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      if (!mounted) return;
      setState(() {
        _product = product;
        _purchases = purchases;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = 'Veriler yüklenirken bir hata oluştu';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = _product;

    if (_loading) {
      return const AppScaffold(
        title: 'Ürün Alışları',
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return AppScaffold(
        title: 'Ürün Alışları',
        body: Center(child: Text(_errorMessage!)),
      );
    }

    if (product == null) {
      return const AppScaffold(
        title: 'Ürün Alışları',
        body: Center(child: Text('Ürün bulunamadı')), 
      );
    }

    return AppScaffold(
      title: 'Ürün Alışları',
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Theme.of(context).colorScheme.surfaceVariant,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (product.barcode.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('Barkod: ${product.barcode}'),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _purchases.isEmpty
                ? const Center(child: Text('Bu ürün için alış kaydı yok'))
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: _purchases.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final e = _purchases[index];
                      final dateString =
                          '${e.createdAt.day.toString().padLeft(2, '0')}.'
                          '${e.createdAt.month.toString().padLeft(2, '0')}.'
                          '${e.createdAt.year} '
                          '${e.createdAt.hour.toString().padLeft(2, '0')}:'
                          '${e.createdAt.minute.toString().padLeft(2, '0')}';
                      final totalCost =
                          e.unitCost > 0 ? e.unitCost * e.quantity : null;
                      return ListTile(
                        title: Text('Miktar: ${e.quantity}'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Tarih: $dateString'),
                            Text('Birim maliyet: ${formatMoney(e.unitCost)}'),
                            if (totalCost != null)
                              Text('Toplam maliyet: ${formatMoney(totalCost)}'),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
