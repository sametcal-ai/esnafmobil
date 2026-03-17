import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_settings.dart';
import '../../../core/config/money_formatter.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../pricing/domain/price_resolver.dart';
import '../../company/domain/active_company_provider.dart';
import '../../suppliers/data/stock_entry_repository.dart';
import '../../suppliers/data/supplier_repository.dart';
import '../../suppliers/domain/stock_entry.dart';
import '../../suppliers/domain/supplier.dart';
import '../../sales/data/sales_repository.dart';
import '../../customers/data/customer_repository.dart';
import '../../customers/domain/customer.dart';
import '../data/product_repository.dart';
import '../domain/product.dart';
import 'products_page.dart';

class ProductDetailPage extends ConsumerStatefulWidget {
  final String productId;

  const ProductDetailPage({super.key, required this.productId});

  @override
  ConsumerState<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends ConsumerState<ProductDetailPage> {
  Product? _product;
  bool _loadingProduct = true;
  String? _errorMessage;

  List<StockEntry> _purchases = const [];
  List<_ProductMovement> _movements = const [];
  bool _loadingPurchases = true;
  bool _loadingMovements = true;

  DateTime? _purchasesStart;
  DateTime? _purchasesEnd;
  DateTime? _movementsStart;
  DateTime? _movementsEnd;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
    final start = end.subtract(const Duration(days: 30));
    _purchasesStart = start;
    _purchasesEnd = end;
    _movementsStart = start;
    _movementsEnd = end;
    _loadProductAndData();
  }

  Future<void> _loadProductAndData() async {
    final companyId = ref.read(activeCompanyIdProvider);
    if (companyId == null) {
      setState(() {
        _loadingProduct = false;
        _loadingPurchases = false;
        _loadingMovements = false;
        _errorMessage = 'Aktif firma seçilmedi';
      });
      return;
    }

    final productRepo = ref.read(productsRepositoryProvider);
    final stockRepo = ref.read(stockEntryRepositoryProvider);
    final supplierRepo = ref.read(supplierRepositoryProvider);
    final salesRepo = ref.read(salesRepositoryProvider);

    try {
      final product = await productRepo.getProductById(companyId, widget.productId);
      if (!mounted) return;
      if (product == null) {
        setState(() {
          _loadingProduct = false;
          _errorMessage = 'Ürün bulunamadı';
        });
        return;
      }

      setState(() {
        _product = product;
        _loadingProduct = false;
      });

      // Alışlar (incoming stock entries)
      final allEntries = await stockRepo.getAllEntries(companyId);
      final purchases = allEntries.where((e) {
        if (e.productId != product.id) return false;
        if (e.type != StockMovementType.incoming) return false;
        if (e.meta.isDeleted || !e.meta.isVisible || !e.meta.isActived) {
          return false;
        }
        return _isInRange(e.createdAt, _purchasesStart, _purchasesEnd);
      }).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      if (!mounted) return;
      setState(() {
        _purchases = purchases;
        _loadingPurchases = false;
      });

      // Hareketler (stok giriş/çıkış + satış satırları)
      final suppliers = await supplierRepo.getAllSuppliers(companyId);
      final suppliersById = <String, Supplier>{
        for (final s in suppliers) s.id: s,
      };

      final customerRepo = ref.read(customerRepositoryProvider);
      final customers = await customerRepo.getAllCustomers(companyId);
      final customersById = <String, Customer>{
        for (final c in customers) c.id: c,
      };

      final allSales = await salesRepo.getAllSales(companyId);

      final movements = <_ProductMovement>[];

      // Stok hareketleri
      for (final entry in allEntries) {
        if (entry.productId != product.id) continue;
        if (entry.meta.isDeleted || !entry.meta.isVisible || !entry.meta.isActived) {
          continue;
        }
        if (!_isInRange(entry.createdAt, _movementsStart, _movementsEnd)) {
          continue;
        }

        final isIncoming = entry.type == StockMovementType.incoming;
        final quantitySigned = isIncoming ? entry.quantity : -entry.quantity;
        final typeText = isIncoming ? 'Alış (Giriş)' : 'Stok Çıkış';

        final supplierName = (entry.supplierName != null && entry.supplierName!.isNotEmpty)
            ? entry.supplierName!
            : entry.supplierId != null
                ? (suppliersById[entry.supplierId!]?.name ?? 'Bilinmeyen tedarikçi')
                : (isIncoming ? 'Tedarikçi yok' : 'Stok');

        final amount =
            isIncoming && entry.unitCost > 0 ? entry.quantity * entry.unitCost : null;

        movements.add(
          _ProductMovement(
            type: typeText,
            occurredAt: entry.createdAt,
            quantitySigned: quantitySigned,
            amount: amount,
            title: supplierName,
            subtitle: isIncoming
                ? 'Birim maliyet: ${entry.unitCost.toStringAsFixed(2)}'
                : 'Stok çıkışı',
            sourceId: entry.id,
          ),
        );
      }

      // Satış satırları
      for (final sale in allSales) {
        if (sale.meta.isDeleted || !sale.meta.isVisible || !sale.meta.isActived) {
          continue;
        }
        if (!_isInRange(sale.createdAt, _movementsStart, _movementsEnd)) {
          continue;
        }

        final customerName = sale.customerId != null
            ? (customersById[sale.customerId!]?.name ?? 'Bilinmeyen müşteri')
            : 'Müşteri yok';

        for (final item in sale.items) {
          if (item.productId != product.id) continue;

          movements.add(
            _ProductMovement(
              type: 'Satış (Çıkış)',
              occurredAt: sale.createdAt,
              quantitySigned: -item.quantity,
              amount: item.lineTotal,
              title: customerName,
              subtitle:
                  '${item.productName} • ${item.quantity} x ${item.unitPrice.toStringAsFixed(2)} = ${item.lineTotal.toStringAsFixed(2)}',
              sourceId: sale.id,
            ),
          );
        }
      }

      movements.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));

      if (!mounted) return;
      setState(() {
        _movements = movements;
        _loadingMovements = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingProduct = false;
        _loadingPurchases = false;
        _loadingMovements = false;
        _errorMessage = 'Veriler yüklenirken bir hata oluştu';
      });
    }
  }

  bool _isInRange(DateTime dt, DateTime? start, DateTime? end) {
    if (start != null && dt.isBefore(start)) return false;
    if (end != null && dt.isAfter(end)) return false;
    return true;
  }

  void _setQuickPurchasesRange(Duration duration) {
    final now = DateTime.now();
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
    final start = end.subtract(duration);
    setState(() {
      _purchasesStart = start;
      _purchasesEnd = end;
      _loadingPurchases = true;
    });
    _loadProductAndData();
  }

  void _setQuickMovementsRange(Duration duration) {
    final now = DateTime.now();
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
    final start = end.subtract(duration);
    setState(() {
      _movementsStart = start;
      _movementsEnd = end;
      _loadingMovements = true;
    });
    _loadProductAndData();
  }

  Future<void> _pickPurchasesStart() async {
    final current = _purchasesStart ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      _purchasesStart = DateTime(picked.year, picked.month, picked.day);
      _loadingPurchases = true;
    });
    _loadProductAndData();
  }

  Future<void> _pickPurchasesEnd() async {
    final current = _purchasesEnd ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      _purchasesEnd =
          DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
      _loadingPurchases = true;
    });
    _loadProductAndData();
  }

  Future<void> _pickMovementsStart() async {
    final current = _movementsStart ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      _movementsStart = DateTime(picked.year, picked.month, picked.day);
      _loadingMovements = true;
    });
    _loadProductAndData();
  }

  Future<void> _pickMovementsEnd() async {
    final current = _movementsEnd ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      _movementsEnd =
          DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
      _loadingMovements = true;
    });
    _loadProductAndData();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final product = _product;

    if (_loadingProduct) {
      return const AppScaffold(
        title: 'Ürün Detayı',
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return AppScaffold(
        title: 'Ürün Detayı',
        body: Center(child: Text(_errorMessage!)),
      );
    }

    if (product == null) {
      return const AppScaffold(
        title: 'Ürün Detayı',
        body: Center(child: Text('Ürün bulunamadı')),
      );
    }

    final resolvedSalePrice = PriceResolver.resolveSellPrice(
      product: product,
      settings: settings,
    );

    final isDeleted = product.meta.isDeleted;
    final movementsPageSize = settings.movementsPageSize;

    return AppScaffold(
      title: 'Ürün Detayı',
      actions: [
        IconButton(
          icon: const Icon(Icons.edit_outlined),
          onPressed: () async {
            final updated = await showDialog<bool>(
              context: context,
              builder: (context) => EditProductDialog(existing: product),
            );
            if (updated == true) {
              await _loadProductAndData();
            }
          },
        ),
      ],
      body: Column(
        children: [
          if (isDeleted)
            Container(
              width: double.infinity,
              color: Colors.red.shade100,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: const Text(
                'Bu ürün silinmiş (soft delete).',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          // Üst bilgi
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
                if (product.brand.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('Marka: ${product.brand}'),
                ],
                if (product.barcode.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('Barkod: ${product.barcode}'),
                ],
                if (product.tags.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('Etiketler: ${product.tags.join(', ')}'),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Özet kartlar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Stok',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text(product.stockQuantity.toString()),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Son alış fiyatı',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text(formatMoney(product.lastPurchasePrice)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Satış fiyatı',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text(formatMoney(resolvedSalePrice)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                _buildPurchasesSection(product, settings.movementsPageSize),
                const SizedBox(height: 8),
                // Ürün ekstresi butonu (müşteri detay sayfasındaki Ekstre kartına benzer)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.receipt_long_outlined),
                    title: const Text(
                      'Ekstre',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text(
                      'Tarih aralığına göre ürün ekstresi',
                    ),
                    trailing: const Icon(Icons.chevron_right_outlined),
                    onTap: () {
                      context.push('/products/${product.id}/movements');
                    },
                  ),
                ),
                const SizedBox(height: 12),
                _buildMovementsSection(movementsPageSize),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showMovementDetails(_ProductMovement movement) async {
    final dateString =
        '${movement.occurredAt.day.toString().padLeft(2, '0')}.'
        '${movement.occurredAt.month.toString().padLeft(2, '0')}.'
        '${movement.occurredAt.year} '
        '${movement.occurredAt.hour.toString().padLeft(2, '0')}:'
        '${movement.occurredAt.minute.toString().padLeft(2, '0')}';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        final isIncoming = movement.quantitySigned > 0;
        final qtyColor =
            isIncoming ? Colors.green.shade700 : Colors.red.shade700;

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Hareket Detayı',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text('Tür: ${movement.type}'),
                const SizedBox(height: 4),
                Text('Tarih: $dateString'),
                const SizedBox(height: 4),
                if (movement.type.startsWith('Alış'))
                  Text('Tedarikçi: ${movement.title}')
                else if (movement.type.startsWith('Satış'))
                  Text('Müşteri: ${movement.title}')
                else
                  Text('Açıklama: ${movement.title}'),
                const SizedBox(height: 4),
                Text('Detay: ${movement.subtitle}'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Miktar: '),
                    Text(
                      '${movement.quantitySigned > 0 ? '+' : ''}${movement.quantitySigned}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: qtyColor,
                      ),
                    ),
                  ],
                ),
                if (movement.amount != null) ...[
                  const SizedBox(height: 4),
                  Text('Tutar: ${formatMoney(movement.amount!)}'),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPurchasesSection(Product product, int pageSize) {
    final totalCount = _purchases.length;
    final visibleCount = totalCount > pageSize ? pageSize : totalCount;

    return Card(
      child: ListTile(
        title: const Text(
          'Alışlar',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: _loadingPurchases
            ? const Text('Yükleniyor...')
            : (totalCount == 0
                ? const Text('Bu ürün için alış kaydı yok')
                : Text('Son $visibleCount kayıt gösteriliyor')),
        trailing: const Icon(Icons.chevron_right_outlined),
        onTap: () {
          context.push('/products/${product.id}/purchases');
        },
      ),
    );
  }

  Widget _buildMovementsSection(int movementsPageSize) {
    final all = _movements;

    if (_loadingMovements) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (all.isEmpty) {
      return const Card(
        child: ListTile(
          title: Text(
            'Hareketler',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text('Bu ürün için hareket yok'),
        ),
      );
    }

    final limited = all.length > movementsPageSize
        ? all.sublist(0, movementsPageSize)
        : all;

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ListTile(
            title: Text(
              'Hareketler',
              style: TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Divider(height: 0),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: limited.length,
            itemBuilder: (context, index) {
              final m = limited[index];
              final dateString =
                  '${m.occurredAt.day.toString().padLeft(2, '0')}.'
                  '${m.occurredAt.month.toString().padLeft(2, '0')}.'
                  '${m.occurredAt.year} '
                  '${m.occurredAt.hour.toString().padLeft(2, '0')}:'
                  '${m.occurredAt.minute.toString().padLeft(2, '0')}';

              final isIncoming = m.quantitySigned > 0;
              final qtyColor =
                  isIncoming ? Colors.green.shade700 : Colors.red.shade700;

              return ListTile(
                leading: Text(
                  dateString,
                  style: const TextStyle(fontSize: 12),
                ),
                title: Text(m.type),
                subtitle: Text(m.subtitle),
                trailing: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${m.quantitySigned > 0 ? '+' : ''}${m.quantitySigned}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: qtyColor,
                      ),
                    ),
                    if (m.amount != null)
                      Text(formatMoney(m.amount!)),
                  ],
                ),
                onTap: () => _showMovementDetails(m),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ProductMovement {
  final String type;
  final DateTime occurredAt;
  final int quantitySigned;
  final double? amount;
  final String title;
  final String subtitle;
  final String sourceId;

  _ProductMovement({
    required this.type,
    required this.occurredAt,
    required this.quantitySigned,
    required this.amount,
    required this.title,
    required this.subtitle,
    required this.sourceId,
  });
}
