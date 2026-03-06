import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/config/money_formatter.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../suppliers/data/stock_entry_repository.dart';
import '../../suppliers/data/supplier_repository.dart';
import '../../suppliers/domain/stock_entry.dart';
import '../../suppliers/domain/supplier.dart';
import '../../sales/data/sales_repository.dart';
import '../../customers/data/customer_repository.dart';
import '../../customers/domain/customer.dart';
import '../data/product_repository.dart';
import '../data/product_statement_pdf_service.dart';
import '../domain/product.dart';

class ProductMovementsPage extends ConsumerStatefulWidget {
  final String productId;

  const ProductMovementsPage({super.key, required this.productId});

  @override
  ConsumerState<ProductMovementsPage> createState() => _ProductMovementsPageState();
}

class _ProductMovementsPageState extends ConsumerState<ProductMovementsPage> {
  Product? _product;
  bool _loading = true;
  bool _sharing = false;

  DateTime? _startDate;
  DateTime? _endDate;

  int _openingStock = 0;
  int _totalIncoming = 0;
  int _totalOutgoing = 0;
  List<_ProductMovement> _entries = const [];

  @override
  void initState() {
    super.initState();
    _initProduct();
  }

  Future<void> _initProduct() async {
    final productRepo = ProductRepository();
    final product = await productRepo.getProductById(widget.productId);
    if (!mounted) return;
    if (product == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ürün bulunamadı'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop();
      return;
    }

    setState(() {
      _product = product;
      final now = DateTime.now();
      _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
      _startDate = _endDate!.subtract(const Duration(days: 30));
      _loading = false;
    });

    await _loadStatement();
  }

  Future<void> _pickStartDate() async {
    final current = _startDate ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      _startDate = DateTime(picked.year, picked.month, picked.day);
    });
    await _loadStatement();
  }

  Future<void> _pickEndDate() async {
    final current = _endDate ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      _endDate = DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
    });
    await _loadStatement();
  }

  Future<void> _loadStatement() async {
    final product = _product;
    final start = _startDate;
    final end = _endDate;
    if (product == null || start == null || end == null) return;

    if (start.isAfter(end)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Başlangıç tarihi bitiş tarihinden büyük olamaz'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _loading = true;
    });

    final stockRepo = StockEntryRepository(ProductRepository());
    final supplierRepo = SupplierRepository();
    final salesRepo = SalesRepository();
    final customerRepo = CustomerRepository();

    final allEntries = await stockRepo.getAllEntries();
    final suppliers = await supplierRepo.getAllSuppliers();
    final suppliersById = <String, Supplier>{for (final s in suppliers) s.id: s};
    final customers = await customerRepo.getAllCustomers();
    final customersById = <String, Customer>{for (final c in customers) c.id: c};
    final allSales = await salesRepo.getAllSales();

    // Açılış stokunu hesapla (başlangıç tarihinden önceki tüm hareketler)
    int openingStock = 0;
    int totalIncoming = 0;
    int totalOutgoing = 0;

    for (final entry in allEntries) {
      if (entry.productId != product.id) continue;
      if (entry.meta.isDeleted || !entry.meta.isVisible || !entry.meta.isActived) {
        continue;
      }

      final isIncoming = entry.type == StockMovementType.incoming;
      final qtySigned = isIncoming ? entry.quantity : -entry.quantity;

      if (entry.createdAt.isBefore(start)) {
        openingStock += qtySigned;
      }

      if (!entry.createdAt.isBefore(start) && !entry.createdAt.isAfter(end)) {
        if (isIncoming) {
          totalIncoming += entry.quantity;
        } else {
          totalOutgoing += entry.quantity;
        }
      }
    }

    for (final sale in allSales) {
      if (sale.meta.isDeleted || !sale.meta.isVisible || !sale.meta.isActived) {
        continue;
      }
      if (sale.createdAt.isBefore(start)) {
        for (final item in sale.items) {
          if (item.productId != product.id) continue;
          openingStock -= item.quantity;
        }
      }
      if (!sale.createdAt.isBefore(start) && !sale.createdAt.isAfter(end)) {
        for (final item in sale.items) {
          if (item.productId != product.id) continue;
          totalOutgoing += item.quantity;
        }
      }
    }

    final movements = <_ProductMovement>[];

    // Tarih aralığındaki stok giriş/çıkışları
    for (final entry in allEntries) {
      if (entry.productId != product.id) continue;
      if (entry.meta.isDeleted || !entry.meta.isVisible || !entry.meta.isActived) {
        continue;
      }
      if (entry.createdAt.isBefore(start) || entry.createdAt.isAfter(end)) {
        continue;
      }

      final isIncoming = entry.type == StockMovementType.incoming;
      final quantitySigned = isIncoming ? entry.quantity : -entry.quantity;
      final typeText = isIncoming ? 'Alış (Giriş)' : 'Stok Çıkış';

      final supplierName = entry.supplierId != null
          ? (suppliersById[entry.supplierId!]?.name ?? 'Bilinmeyen tedarikçi')
          : (isIncoming ? 'Tedarikçi yok' : 'Stok');

      final amount =
          isIncoming && entry.unitCost > 0 ? entry.quantity * entry.unitCost : null;

      final subtitle = isIncoming
          ? 'Tedarikçi: $supplierName - Birim maliyet: ${entry.unitCost.toStringAsFixed(2)}'
          : 'Stok çıkışı';

      movements.add(
        _ProductMovement(
          type: typeText,
          occurredAt: entry.createdAt,
          quantitySigned: quantitySigned,
          amount: amount,
          title: supplierName,
          subtitle: subtitle,
        ),
      );
    }

    // Tarih aralığındaki satış satırları
    for (final sale in allSales) {
      if (sale.meta.isDeleted || !sale.meta.isVisible || !sale.meta.isActived) {
        continue;
      }
      if (sale.createdAt.isBefore(start) || sale.createdAt.isAfter(end)) {
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
                'Müşteri: $customerName - ${item.productName} • ${item.quantity} x ${item.unitPrice.toStringAsFixed(2)} = ${item.lineTotal.toStringAsFixed(2)}',
          ),
        );
      }
    }

    movements.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));

    if (!mounted) return;
    setState(() {
      _openingStock = openingStock;
      _totalIncoming = totalIncoming;
      _totalOutgoing = totalOutgoing;
      _entries = movements;
      _loading = false;
    });
  }

  Future<void> _shareStatement() async {
    final product = _product;
    final start = _startDate;
    final end = _endDate;

    if (product == null || start == null || end == null) {
      return;
    }
    if (_entries.isEmpty && !_loading) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Seçilen aralıkta hareket yok, ekstre oluşturulamadı'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _sharing = true;
    });

    try {
      Uint8List bytes;
      try {
        final pdfService = ProductStatementPdfService();
        bytes = await pdfService.generateStatementPdf(
          product: product,
          openingStock: _openingStock,
          totalIncoming: _totalIncoming,
          totalOutgoing: _totalOutgoing,
          entries: _entries
              .map(
                (m) => ProductMovementForPdf(
                  type: m.type,
                  occurredAt: m.occurredAt,
                  quantitySigned: m.quantitySigned,
                  amount: m.amount,
                  subtitle: m.subtitle,
                ),
              )
              .toList(growable: false),
          start: start,
          end: end,
        );
      } catch (e, st) {
        debugPrint('PRODUCT PDF GENERATION ERROR: $e');
        debugPrint('STACKTRACE: $st');
        debugPrint(
          'PRODUCT PDF CONTEXT => productId=${product.id}, entries=${_entries.length}, '
          'openingStock=$_openingStock, totalIncoming=$_totalIncoming, totalOutgoing=$_totalOutgoing, '
          'start=$_startDate, end=$_endDate, isWeb=$kIsWeb, platform=${kIsWeb ? 'web' : Platform.operatingSystem}',
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ekstre PDF oluşturulurken bir hata oluştu'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      final tempDir = await getTemporaryDirectory();
      final safeName = (product.name.isNotEmpty ? product.name : 'urun')
          .replaceAll('/', ' ')
          .replaceAll('\\', ' ');
      final file = File(
        '${tempDir.path}/urun_ekstresi_${safeName}_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
      await file.writeAsBytes(bytes, flush: true);

      try {
        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'Ürün Ekstresi - ${product.name}',
        );
      } catch (e, st) {
        debugPrint('PRODUCT STATEMENT SHARE ERROR: $e');
        debugPrint('STACKTRACE: $st');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ekstre dosyası paylaşılırken bir hata oluştu'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e, st) {
      debugPrint('PRODUCT STATEMENT FLOW ERROR: $e');
      debugPrint('STACKTRACE: $st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ekstre PDF oluşturulurken bir hata oluştu'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _sharing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = _product;

    return AppScaffold(
      title: product == null ? 'Ürün Ekstresi' : '${product.name} - Ekstre',
      actions: [
        if (!_loading && product != null)
          IconButton(
            icon: _sharing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.ios_share_outlined),
            tooltip: 'İlet',
            onPressed: _sharing ? null : _shareStatement,
          ),
      ],
      body: _loading && product == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: _DateField(
                          label: 'Başlangıç',
                          date: _startDate,
                          onTap: _pickStartDate,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _DateField(
                          label: 'Bitiş',
                          date: _endDate,
                          onTap: _pickEndDate,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Dönem Özeti',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Expanded(child: Text('Açılış Stok')),
                              Text(
                                _openingStock.toString(),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Expanded(child: Text('Toplam Giriş')),
                              Text(
                                _totalIncoming.toString(),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Expanded(child: Text('Toplam Çıkış')),
                              Text(
                                _totalOutgoing.toString(),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 16),
                          Row(
                            children: [
                              const Expanded(child: Text('Dönem Sonu Stok')), 
                              Text(
                                (_openingStock + _totalIncoming - _totalOutgoing)
                                    .toString(),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _entries.isEmpty
                          ? const Center(
                              child: Text('Seçilen aralıkta hareket yok'),
                            )
                          : ListView.separated(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              itemCount: _entries.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 4),
                              itemBuilder: (context, index) {
                                final m = _entries[index];
                                final isIncoming = m.quantitySigned > 0;
                                final qtyColor = isIncoming
                                    ? Colors.green.shade700
                                    : Colors.red.shade700;
                                final dateString =
                                    '${m.occurredAt.day.toString().padLeft(2, '0')}.'
                                    '${m.occurredAt.month.toString().padLeft(2, '0')}.'
                                    '${m.occurredAt.year} '
                                    '${m.occurredAt.hour.toString().padLeft(2, '0')}:'
                                    '${m.occurredAt.minute.toString().padLeft(2, '0')}';

                                return Card(
                                  child: ListTile(
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
                                            fontWeight: FontWeight.w600,
                                            color: qtyColor,
                                          ),
                                        ),
                                        if (m.amount != null)
                                          Text(formatMoney(m.amount!)),
                                      ],
                                    ),
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

class _ProductMovement {
  final String type;
  final DateTime occurredAt;
  final int quantitySigned;
  final double? amount;
  final String title;
  final String subtitle;

  _ProductMovement({
    required this.type,
    required this.occurredAt,
    required this.quantitySigned,
    required this.amount,
    required this.title,
    required this.subtitle,
  });
}

/// PDF servisinin erişebilmesi için sade bir DTO.
class ProductMovementForPdf {
  final String type;
  final DateTime occurredAt;
  final int quantitySigned;
  final double? amount;
  final String subtitle;

  ProductMovementForPdf({
    required this.type,
    required this.occurredAt,
    required this.quantitySigned,
    required this.amount,
    required this.subtitle,
  });
}

class _DateField extends StatelessWidget {
  final String label;
  final DateTime? date;
  final VoidCallback onTap;

  const _DateField({
    required this.label,
    required this.date,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final text = date == null
        ? '-'
        : '${date!.day.toString().padLeft(2, '0')}.'
          '${date!.month.toString().padLeft(2, '0')}.'
          '${date!.year}';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        child: Text(text),
      ),
    );
  }
}
