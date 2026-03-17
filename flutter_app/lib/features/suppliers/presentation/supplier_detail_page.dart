import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_settings.dart';
import '../../../core/config/money_formatter.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../company/domain/active_company_provider.dart';
import '../../products/data/product_repository.dart';
import '../data/stock_entry_repository.dart';
import '../data/supplier_repository.dart';
import '../data/supplier_ledger_repository.dart';
import '../domain/stock_entry.dart';
import '../domain/supplier.dart';
import '../domain/supplier_controller.dart';
import '../domain/supplier_ledger.dart';

class SupplierDetailPage extends ConsumerStatefulWidget {
  final String supplierId;

  const SupplierDetailPage({super.key, required this.supplierId});

  @override
  ConsumerState<SupplierDetailPage> createState() => _SupplierDetailPageState();
}

class _SupplierDetailPageState extends ConsumerState<SupplierDetailPage> {
  SupplierDetailController? _controller;
  VoidCallback? _removeControllerListener;

  void _handleControllerChanged() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _initController();
  }

  @override
  void dispose() {
    _removeControllerListener?.call();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _initController() async {
    final companyId = ref.read(activeCompanyIdProvider);
    if (companyId == null) return;

    final supplierRepo = ref.read(supplierRepositoryProvider);
    final ledgerRepo = ref.read(supplierLedgerRepositoryProvider);

    final supplier = await supplierRepo.getSupplierById(companyId, widget.supplierId);
    if (!mounted) return;
    if (supplier == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tedarikçi bulunamadı'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop();
      return;
    }

    setState(() {
      _removeControllerListener?.call();
      _controller?.dispose();

      _controller = SupplierDetailController(
        companyId: companyId,
        supplier: supplier,
        ledgerRepository: ledgerRepo,
      );

      _controller!.addListener(_handleControllerChanged);
      _removeControllerListener = () {
        _controller?.removeListener(_handleControllerChanged);
      };
    });
  }

  Future<void> _editSupplier(Supplier supplier) async {
    final repo = ref.read(supplierRepositoryProvider);
    final updated = await showDialog<Supplier?>(
      context: context,
      builder: (context) {
        return _EditSupplierDialog(supplier: supplier);
      },
    );

    if (updated == null) return;

    final companyId = ref.read(activeCompanyIdProvider);
    if (companyId == null) return;

    final saved = await repo.updateSupplier(companyId, updated);
    if (!mounted) return;

    if (saved == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tedarikçi güncellenemedi'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _removeControllerListener?.call();
      _controller?.dispose();

      _controller = SupplierDetailController(
        companyId: companyId,
        supplier: saved,
        ledgerRepository: ref.read(supplierLedgerRepositoryProvider),
      );

      _controller!.addListener(_handleControllerChanged);
      _removeControllerListener = () {
        _controller?.removeListener(_handleControllerChanged);
      };
    });
  }

  Future<void> _openPayments(Supplier supplier) async {
    await context.push('/suppliers/${supplier.id}/payments');
    await _controller?.refresh();
  }

  Future<void> _openStatement(Supplier supplier) async {
    await context.push('/suppliers/${supplier.id}/statement');
    await _controller?.refresh();
  }

  Future<void> _showEntryDetails(
    SupplierLedgerEntry entry,
    Supplier supplier,
  ) async {
    final isPurchase =
        entry.type == SupplierLedgerEntryType.purchase;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        final dateString =
            '${entry.createdAt.day.toString().padLeft(2, '0')}.'
            '${entry.createdAt.month.toString().padLeft(2, '0')}.'
            '${entry.createdAt.year} '
            '${entry.createdAt.hour.toString().padLeft(2, '0')}:'
            '${entry.createdAt.minute.toString().padLeft(2, '0')}';

        if (!isPurchase) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ödeme Detayı',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('Tarih: $dateString'),
                  const SizedBox(height: 4),
                  Text('Tutar: ${formatMoney(entry.amount)}'),
                  const SizedBox(height: 8),
                  Text(
                    entry.note?.isNotEmpty == true
                        ? 'Not: ${entry.note}'
                        : 'Ödeme',
                  ),
                ],
              ),
            ),
          );
        }

        return FutureBuilder<_SupplierPurchaseViewData?>(
          future: _findPurchaseViewData(entry, supplier),
          builder: (context, snapshot) {
            final data = snapshot.data;

            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Alış Detayı',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('Tarih: $dateString'),
                    const SizedBox(height: 4),
                    Text('Tutar: ${formatMoney(entry.amount)}'),
                    const SizedBox(height: 8),
                    if (snapshot.connectionState ==
                        ConnectionState.waiting)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (data == null)
                      const Text(
                        'Bu alış için stok girişi detayı bulunamadı.',
                        style: TextStyle(color: Colors.grey),
                      )
                    else ...[
                      const Text(
                        'Ürünler',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(data.productName),
                        subtitle: Text(
                          '${data.quantity} x ${formatMoney(data.unitCost)}',
                        ),
                        trailing: Text(
                          formatMoney(data.lineTotal),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<_SupplierPurchaseViewData?> _findPurchaseViewData(
    SupplierLedgerEntry entry,
    Supplier supplier,
  ) async {
    final companyId = ref.read(activeCompanyIdProvider);
    if (companyId == null) return null;

    final stockRepo = ref.read(stockEntryRepositoryProvider);
    final productRepo = ref.read(productsRepositoryProvider);

    final allEntries = await stockRepo.getAllEntries(companyId);
    final relevant = allEntries.where(
      (e) =>
          e.type == StockMovementType.incoming &&
          e.supplierId == supplier.id,
    );

    StockEntry? bestMatch;
    int? bestDiff;

    for (final e in relevant) {
      final amount = e.quantity * e.unitCost;
      if ((amount - entry.amount).abs() > 0.01) continue;

      final diff = (e.createdAt.millisecondsSinceEpoch -
              entry.createdAt.millisecondsSinceEpoch)
          .abs();
      // 1 dakikadan fazla fark varsa eşleştirme yapma.
      if (diff > const Duration(minutes: 1).inMilliseconds) continue;

      if (bestMatch == null || diff < bestDiff!) {
        bestMatch = e;
        bestDiff = diff;
      }
    }

    if (bestMatch == null) return null;

    final product = await productRepo.getProductById(companyId, bestMatch.productId);

    return _SupplierPurchaseViewData(
      stockEntry: bestMatch,
      productName:
          product?.name ?? 'Ürün: ${bestMatch.productId}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) {
      return const AppScaffold(
        title: 'Tedarikçi',
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final state = controller.value;
    final supplier = state.supplier;

    return AppScaffold(
      title: 'Tedarikçi Detayı',
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color:
                Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        supplier.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (supplier.phone != null &&
                          supplier.phone!.trim().isNotEmpty)
                        Text('Telefon: ${supplier.phone}'),
                      if (supplier.address != null &&
                          supplier.address!.trim().isNotEmpty)
                        Text('Adres: ${supplier.address}'),
                      if (supplier.note != null &&
                          supplier.note!.trim().isNotEmpty)
                        Text('Not: ${supplier.note}'),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _editSupplier(supplier),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Düzenle'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Bakiye',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      formatMoney(state.balance),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: state.balance > 0
                            ? Colors.red.shade700
                            : (state.balance < 0
                                ? Colors.green.shade700
                                : Colors.grey.shade800),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await context.push('/stock-entry');
                  await _controller?.refresh();
                },
                icon: const Icon(Icons.add_shopping_cart_outlined),
                label: const Text('Ürün Alış'),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    children: [
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.payments_outlined),
                          title: const Text(
                            'Ödemeler',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: const Text(
                            'Ödeme geçmişini görüntüle ve yeni ödeme ekle',
                          ),
                          trailing:
                              const Icon(Icons.chevron_right_outlined),
                          onTap: () => _openPayments(supplier),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Card(
                        child: ListTile(
                          leading:
                              const Icon(Icons.receipt_long_outlined),
                          title: const Text(
                            'Ekstre',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: const Text(
                            'Tarih aralığına göre hesap ekstresi',
                          ),
                          trailing:
                              const Icon(Icons.chevron_right_outlined),
                          onTap: () => _openStatement(supplier),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Card(
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
                            if (state.entries.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(16),
                                child: Text('Henüz hareket yok'),
                              )
                            else
                              Column(
                                children: state.entries.map((entry) {
                                  final isPurchase =
                                      entry.type ==
                                          SupplierLedgerEntryType.purchase;
                                  final sign = isPurchase ? '+' : '-';
                                  final color = isPurchase
                                      ? Colors.red.shade700
                                      : Colors.green.shade700;
                                  final dateString =
                                      '${entry.createdAt.day.toString().padLeft(2, '0')}.'
                                      '${entry.createdAt.month.toString().padLeft(2, '0')}.'
                                      '${entry.createdAt.year} '
                                      '${entry.createdAt.hour.toString().padLeft(2, '0')}:'
                                      '${entry.createdAt.minute.toString().padLeft(2, '0')}';

                                  return ListTile(
                                    title: Text(
                                      '$sign ${formatMoney(entry.amount)}',
                                      style: TextStyle(
                                        color: color,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    subtitle: Text(
                                      entry.note ??
                                          (isPurchase ? 'Alış' : 'Ödeme'),
                                    ),
                                    trailing: Text(
                                      isPurchase ? 'Alış' : 'Ödeme',
                                    ),
                                    leading: Text(
                                      dateString,
                                      style:
                                          const TextStyle(fontSize: 12),
                                    ),
                                    onTap: () =>
                                        _showEntryDetails(entry, supplier),
                                  );
                                }).toList(),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _SupplierPurchaseViewData {
  final StockEntry stockEntry;
  final String productName;

  int get quantity => stockEntry.quantity;
  double get unitCost => stockEntry.unitCost;
  double get lineTotal => quantity * unitCost;

  _SupplierPurchaseViewData({
    required this.stockEntry,
    required this.productName,
  });
}

class _EditSupplierDialog extends StatefulWidget {
  final Supplier supplier;

  const _EditSupplierDialog({required this.supplier});

  @override
  State<_EditSupplierDialog> createState() => _EditSupplierDialogState();
}

class _EditSupplierDialogState extends State<_EditSupplierDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;
  late final TextEditingController _noteController;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final s = widget.supplier;
    _nameController = TextEditingController(text: s.name);
    _phoneController = TextEditingController(text: s.phone ?? '');
    _addressController = TextEditingController(text: s.address ?? '');
    _noteController = TextEditingController(text: s.note ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tedarikçi adı boş olamaz'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final updated = widget.supplier.copyWith(
      name: name,
      phone: _phoneController.text.trim().isEmpty
          ? null
          : _phoneController.text.trim(),
      address: _addressController.text.trim().isEmpty
          ? null
          : _addressController.text.trim(),
      note: _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim(),
    );

    if (!mounted) return;
    setState(() {
      _isSaving = false;
    });
    Navigator.of(context).pop(updated);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Tedarikçi Düzenle'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Tedarikçi adı',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Telefon',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'Adres',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: 'Not',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed:
              _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('İptal'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _save,
          child: Text(_isSaving ? 'Kaydediliyor...' : 'Kaydet'),
        ),
      ],
    );
  }
}
