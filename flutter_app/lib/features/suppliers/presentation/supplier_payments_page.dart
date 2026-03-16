import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/money_formatter.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../company/domain/active_company_provider.dart';
import '../data/supplier_ledger_repository.dart';
import '../data/supplier_repository.dart';
import '../domain/supplier.dart';
import '../domain/supplier_ledger.dart';


class SupplierPaymentsPage extends ConsumerStatefulWidget {
  final String supplierId;

  const SupplierPaymentsPage({super.key, required this.supplierId});

  @override
  ConsumerState<SupplierPaymentsPage> createState() => _SupplierPaymentsPageState();
}

class _SupplierPaymentsPageState
    extends ConsumerState<SupplierPaymentsPage> {
  Supplier? _supplier;
  List<SupplierLedgerEntry> _payments = const [];
  bool _isLoading = true;

  String _selectedMethod = 'Nakit';
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final companyId = ref.read(activeCompanyIdProvider);
    if (companyId == null) return;

    final supplierRepo = ref.read(supplierRepositoryProvider);
    final ledgerRepo = ref.read(supplierLedgerRepositoryProvider);

    final supplier =
        await supplierRepo.getSupplierById(companyId, widget.supplierId);
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

    final entries = await ledgerRepo.getEntriesForSupplier(companyId, supplier.id);
    final payments = entries
        .where((e) => e.type == SupplierLedgerEntryType.payment)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (!mounted) return;
    setState(() {
      _supplier = supplier;
      _payments = payments;
      _isLoading = false;
    });
  }

  Future<void> _addPayment() async {
    final text = _amountController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen bir tutar girin'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final amount = double.tryParse(text.replaceAll(',', '.'));
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Geçerli bir tutar girin'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final supplier = _supplier;
    if (supplier == null) return;

    final companyId = ref.read(activeCompanyIdProvider);
    if (companyId == null) return;

    final ledgerRepo = ref.read(supplierLedgerRepositoryProvider);

    final note = _noteController.text.trim();
    final fullNote = [
      _selectedMethod.trim(),
      if (note.isNotEmpty) note,
    ].join(' - ');

    await ledgerRepo.addPaymentEntry(
      companyId: companyId,
      supplier: supplier,
      amount: amount,
      note: fullNote.isEmpty ? null : fullNote,
    );

    if (!mounted) return;
    Navigator.of(context).pop();
    await _load();
  }

  Future<void> _openAddPaymentDialog() async {
    _amountController.clear();
    _noteController.clear();
    _selectedMethod = 'Nakit';

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Ödeme Ekle'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Nakit'),
                      selected: _selectedMethod == 'Nakit',
                      onSelected: (_) {
                        setState(() {
                          _selectedMethod = 'Nakit';
                        });
                      },
                    ),
                    ChoiceChip(
                      label: const Text('Havale'),
                      selected: _selectedMethod == 'Havale',
                      onSelected: (_) {
                        setState(() {
                          _selectedMethod = 'Havale';
                        });
                      },
                    ),
                    ChoiceChip(
                      label: const Text('K.Kartı'),
                      selected: _selectedMethod == 'K.Kartı',
                      onSelected: (_) {
                        setState(() {
                          _selectedMethod = 'K.Kartı';
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _amountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Tutar',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _noteController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Açıklama (opsiyonel)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: _addPayment,
              child: const Text('Kaydet'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final supplier = _supplier;

    return AppScaffold(
      title: supplier?.name ?? 'Ödemeler',
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: _payments.isEmpty
                      ? const Center(
                          child: Text('Henüz ödeme yok'),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _payments.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final entry = _payments[index];
                            final dateString =
                                '${entry.createdAt.day.toString().padLeft(2, '0')}.'
                                '${entry.createdAt.month.toString().padLeft(2, '0')}.'
                                '${entry.createdAt.year} '
                                '${entry.createdAt.hour.toString().padLeft(2, '0')}:'
                                '${entry.createdAt.minute.toString().padLeft(2, '0')}';

                            return Card(
                              child: ListTile(
                                title: Text(formatMoney(entry.amount)),
                                subtitle: Text(
                                  entry.note ?? 'Ödeme',
                                ),
                                trailing: Text(dateString),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: _isLoading
          ? null
          : FloatingActionButton(
              onPressed: _openAddPaymentDialog,
              child: const Icon(Icons.add),
            ),
    );
  }
}
