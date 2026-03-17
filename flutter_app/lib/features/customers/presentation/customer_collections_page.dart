import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/money_formatter.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../company/domain/active_company_provider.dart';
import '../data/customer_ledger_repository.dart';
import '../data/customer_repository.dart';
import '../domain/customer.dart';
import '../domain/customer_ledger.dart';

class CustomerCollectionsPage extends ConsumerStatefulWidget {
  final String customerId;

  const CustomerCollectionsPage({super.key, required this.customerId});

  @override
  ConsumerState<CustomerCollectionsPage> createState() =>
      _CustomerCollectionsPageState();
}

class _CustomerCollectionsPageState
    extends ConsumerState<CustomerCollectionsPage> {
  Customer? _customer;
  List<CustomerLedgerEntry> _payments = const [];
  bool _isLoading = true;

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

    final customerRepo = ref.read(customerRepositoryProvider);
    final ledgerRepo = ref.read(customerLedgerRepositoryProvider);

    final customer = await customerRepo.getCustomerById(companyId, widget.customerId);
    if (!mounted) return;
    if (customer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Müşteri bulunamadı'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop();
      return;
    }

    final entries =
        await ledgerRepo.getEntriesForCustomer(companyId, customer.id);
    final payments = entries
        .where((e) => e.type == LedgerEntryType.payment)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (!mounted) return;
    setState(() {
      _customer = customer;
      _payments = payments;
      _isLoading = false;
    });
  }

  Future<void> _addCollection(
    BuildContext dialogContext, {
    required String selectedMethod,
  }) async {
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

    final customer = _customer;
    if (customer == null) return;

    final ledgerRepo = ref.read(customerLedgerRepositoryProvider);
    final companyId = ref.read(activeCompanyIdProvider);
    if (companyId == null) return;

    final note = _noteController.text.trim();
    final fullNote = [
      selectedMethod.trim(),
      if (note.isNotEmpty) note,
    ].join(' - ');

    await ledgerRepo.addPaymentEntry(
      companyId: companyId,
      customer: customer,
      amount: amount,
      note: fullNote.isEmpty ? null : fullNote,
    );

    if (!mounted) return;
    Navigator.of(dialogContext).pop();
    await _load();
  }

  Future<void> _openAddCollectionDialog() async {
    _amountController.clear();
    _noteController.clear();

    await showDialog<void>(
      context: context,
      builder: (context) {
        var selectedMethod = 'Nakit';

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Tahsilat Ekle'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(
                            value: 'Nakit',
                            label: Text('Nakit'),
                          ),
                          ButtonSegment(
                            value: 'K.Kartı',
                            label: Text('K.Kartı'),
                          ),
                          ButtonSegment(
                            value: 'Havale',
                            label: Text('Havale'),
                          ),
                        ],
                        selected: {selectedMethod},
                        onSelectionChanged: (selection) {
                          setDialogState(() {
                            selectedMethod = selection.first;
                          });
                        },
                      ),
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
                  onPressed: () => _addCollection(
                    context,
                    selectedMethod: selectedMethod,
                  ),
                  child: const Text('Kaydet'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final customer = _customer;

    return AppScaffold(
      title: customer?.name ?? 'Tahsilatlar',
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: _payments.isEmpty
                      ? const Center(
                          child: Text('Henüz tahsilat yok'),
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
                                  entry.note ?? 'Tahsilat',
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
              onPressed: _openAddCollectionDialog,
              child: const Icon(Icons.add),
            ),
    );
  }
}
