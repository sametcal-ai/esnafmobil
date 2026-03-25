import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/money_formatter.dart';
import '../../../core/firestore/firestore_refs.dart';
import '../../../core/firestore/models/company_member.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_loading_dialog.dart';
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

class _SupplierPaymentsPageState extends ConsumerState<SupplierPaymentsPage> {
  String? _companyId;
  Supplier? _supplier;
  List<SupplierLedgerEntry> _payments = const [];
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

  Future<CompanyMember?> _getMember(String companyId, String uid) async {
    final refs = ref.read(firestoreRefsProvider);
    try {
      final doc = await refs.member(companyId, uid).get();
      return doc.data();
    } on FirebaseException {
      return null;
    }
  }

  Future<void> _load() async {
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

    final entries = await ledgerRepo.getEntriesForSupplier(companyId, supplier.id);
    final payments = entries
        .where((e) => e.type == SupplierLedgerEntryType.payment)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (!mounted) return;
    setState(() {
      _companyId = companyId;
      _supplier = supplier;
      _payments = payments;
      _isLoading = false;
    });
  }

  Future<void> _addPayment(
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

    final supplier = _supplier;
    if (supplier == null) return;

    final companyId = ref.read(activeCompanyIdProvider);
    if (companyId == null) return;

    final ledgerRepo = ref.read(supplierLedgerRepositoryProvider);

    final note = _noteController.text.trim();
    final fullNote = [
      selectedMethod.trim(),
      if (note.isNotEmpty) note,
    ].join(' - ');

    await ledgerRepo.addPaymentEntry(
      companyId: companyId,
      supplier: supplier,
      amount: amount,
      note: fullNote.isEmpty ? null : fullNote,
    );

    if (!mounted) return;
    Navigator.of(dialogContext).pop();
    await _load();
  }

  ({String method, String note}) _parseNoteForEdit(String? raw) {
    final value = (raw ?? '').trim();
    if (value.isEmpty) {
      return (method: 'Nakit', note: '');
    }

    final parts = value.split(' - ');
    if (parts.isEmpty) {
      return (method: 'Nakit', note: '');
    }

    final methodCandidate = parts.first.trim();
    const allowed = {'Nakit', 'K.Kartı', 'Havale'};

    final method = allowed.contains(methodCandidate) ? methodCandidate : 'Nakit';
    final note = allowed.contains(methodCandidate)
        ? parts.skip(1).join(' - ').trim()
        : value;

    return (method: method, note: note);
  }

  Future<void> _openAddPaymentDialog() async {
    _amountController.clear();
    _noteController.clear();

    await showDialog<void>(
      context: context,
      builder: (context) {
        var selectedMethod = 'Nakit';
        var isSaving = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Stack(
              children: [
                AlertDialog(
                  title: const Text('Ödeme Ekle'),
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
                            onSelectionChanged: isSaving
                                ? null
                                : (selection) {
                                    setDialogState(() {
                                      selectedMethod = selection.first;
                                    });
                                  },
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _amountController,
                          enabled: !isSaving,
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
                          enabled: !isSaving,
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
                      onPressed:
                          isSaving ? null : () => Navigator.of(context).pop(),
                      child: const Text('İptal'),
                    ),
                    ElevatedButton(
                      onPressed: isSaving
                          ? null
                          : () async {
                              setDialogState(() {
                                isSaving = true;
                              });

                              await _addPayment(
                                context,
                                selectedMethod: selectedMethod,
                              );

                              if (!context.mounted) return;

                              setDialogState(() {
                                isSaving = false;
                              });
                            },
                      child: Text(isSaving ? 'İşleniyor...' : 'Kaydet'),
                    ),
                  ],
                ),
                if (isSaving) ...[
                  const Positioned.fill(
                    child: ModalBarrier(
                      dismissible: false,
                      color: Colors.black26,
                    ),
                  ),
                  const Center(
                    child: CircularProgressIndicator(),
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _updatePayment(
    BuildContext dialogContext,
    SupplierLedgerEntry entry, {
    required String selectedMethod,
  }) async {
    final supplier = _supplier;
    final companyId = _companyId;
    if (supplier == null || companyId == null) return;

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

    final note = _noteController.text.trim();
    final fullNote = [
      selectedMethod.trim(),
      if (note.isNotEmpty) note,
    ].join(' - ');

    final ledgerRepo = ref.read(supplierLedgerRepositoryProvider);

    await ledgerRepo.updatePaymentEntry(
      companyId: companyId,
      supplierId: supplier.id,
      entry: entry,
      amount: amount,
      note: fullNote.isEmpty ? null : fullNote,
    );

    if (!mounted) return;
    Navigator.of(dialogContext).pop();
    await _load();
  }

  Future<void> _openEditPaymentDialog(SupplierLedgerEntry entry) async {
    final parsed = _parseNoteForEdit(entry.note);

    _amountController.text = entry.amount.toStringAsFixed(2);
    _noteController.text = parsed.note;

    await showDialog<void>(
      context: context,
      builder: (context) {
        var selectedMethod = parsed.method;
        var isSaving = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Stack(
              children: [
                AlertDialog(
                  title: const Text('Ödeme Düzenle'),
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
                            onSelectionChanged: isSaving
                                ? null
                                : (selection) {
                                    setDialogState(() {
                                      selectedMethod = selection.first;
                                    });
                                  },
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _amountController,
                          enabled: !isSaving,
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
                          enabled: !isSaving,
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
                      onPressed:
                          isSaving ? null : () => Navigator.of(context).pop(),
                      child: const Text('İptal'),
                    ),
                    ElevatedButton(
                      onPressed: isSaving
                          ? null
                          : () async {
                              setDialogState(() {
                                isSaving = true;
                              });

                              await _updatePayment(
                                context,
                                entry,
                                selectedMethod: selectedMethod,
                              );

                              if (!context.mounted) return;

                              setDialogState(() {
                                isSaving = false;
                              });
                            },
                      child: Text(isSaving ? 'İşleniyor...' : 'Kaydet'),
                    ),
                  ],
                ),
                if (isSaving) ...[
                  const Positioned.fill(
                    child: ModalBarrier(
                      dismissible: false,
                      color: Colors.black26,
                    ),
                  ),
                  const Center(
                    child: CircularProgressIndicator(),
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _confirmAndDeletePayment(SupplierLedgerEntry entry) async {
    final supplier = _supplier;
    final companyId = _companyId;
    if (supplier == null || companyId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        var isDeleting = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Ödeme Sil'),
              content: const Text('Silmek istediğinize emin misiniz?'),
              actions: [
                TextButton(
                  onPressed: isDeleting
                      ? null
                      : () => Navigator.of(context).pop(false),
                  child: const Text('İptal'),
                ),
                ElevatedButton(
                  onPressed: isDeleting
                      ? null
                      : () {
                          setDialogState(() {
                            isDeleting = true;
                          });
                          Navigator.of(context).pop(true);
                        },
                  child: isDeleting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2.25),
                        )
                      : const Text('Evet, Sil'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true) return;

    final ledgerRepo = ref.read(supplierLedgerRepositoryProvider);

    await runWithLoadingDialog<void>(
      context,
      () => ledgerRepo.softDeleteEntry(
        companyId: companyId,
        supplierId: supplier.id,
        entry: entry,
      ),
    );

    if (!mounted) return;
    await _load();
  }

  Future<void> _showPaymentDetails(SupplierLedgerEntry entry) async {
    final companyId = _companyId;

    final dateString =
        '${entry.createdAt.day.toString().padLeft(2, '0')}.${entry.createdAt.month.toString().padLeft(2, '0')}.${entry.createdAt.year} '
        '${entry.createdAt.hour.toString().padLeft(2, '0')}:${entry.createdAt.minute.toString().padLeft(2, '0')}';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
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
                const SizedBox(height: 4),
                Text(entry.note?.isNotEmpty == true ? 'Not: ${entry.note}' : 'Ödeme'),
                const SizedBox(height: 8),
                if (companyId == null)
                  Text('Ödeme Yapan: ${entry.meta.createdBy}')
                else
                  FutureBuilder<CompanyMember?>(
                    future: _getMember(companyId, entry.meta.createdBy),
                    builder: (context, snapshot) {
                      final member = snapshot.data;
                      final label = (member?.displayName.trim().isNotEmpty == true)
                          ? member!.displayName
                          : (member?.email.trim().isNotEmpty == true)
                              ? member!.email
                              : entry.meta.createdBy;
                      return Text('Ödeme Yapan: $label');
                    },
                  ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          Navigator.of(context).pop();
                          await _openEditPaymentDialog(entry);
                        },
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Ödeme Düzenle'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          Navigator.of(context).pop();
                          await _confirmAndDeletePayment(entry);
                        },
                        icon: Icon(
                          Icons.delete_outline,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        label: Text(
                          'Ödeme Sil',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
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
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final entry = _payments[index];
                            final dateString =
                                '${entry.createdAt.day.toString().padLeft(2, '0')}.${entry.createdAt.month.toString().padLeft(2, '0')}.${entry.createdAt.year} '
                                '${entry.createdAt.hour.toString().padLeft(2, '0')}:${entry.createdAt.minute.toString().padLeft(2, '0')}';

                            return Card(
                              child: ListTile(
                                title: Text(formatMoney(entry.amount)),
                                subtitle: Text(entry.note ?? 'Ödeme'),
                                trailing: Text(dateString),
                                onTap: () => _showPaymentDetails(entry),
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
