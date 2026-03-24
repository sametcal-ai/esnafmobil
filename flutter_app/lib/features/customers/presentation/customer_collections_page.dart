import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/money_formatter.dart';
import '../../../core/firestore/firestore_refs.dart';
import '../../../core/firestore/models/company_member.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../auth/domain/current_user_provider.dart' show currentUserProvider;
import '../../auth/domain/user.dart';
import '../../company/domain/active_company_provider.dart';
import '../data/customer_ledger_repository.dart';
import '../data/customer_repository.dart';
import '../domain/customer.dart';
import '../domain/customer_ledger.dart';

final _companyMembersMapProvider = StreamProvider<Map<String, CompanyMember>>((ref) {
  final companyId = ref.watch(activeCompanyIdProvider);
  if (companyId == null) return const Stream<Map<String, CompanyMember>>.empty();

  final refs = ref.watch(firestoreRefsProvider);
  return refs.members(companyId).snapshots().map((snap) {
    final map = <String, CompanyMember>{};
    for (final d in snap.docs) {
      final m = d.data();
      map[m.uid] = m;
    }
    return map;
  });
});

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

  String _formatDateTime(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}.'
        '${dt.month.toString().padLeft(2, '0')}.'
        '${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }

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

  Future<void> _openEditPaymentDialog(CustomerLedgerEntry entry) async {
    _amountController.text = entry.amount.toStringAsFixed(2).replaceAll('.', ',');
    _noteController.text = entry.note ?? '';

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Tahsilatı Düzenle'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
              onPressed: () async {
                final text = _amountController.text.trim();
                final amount = double.tryParse(text.replaceAll(',', '.'));
                if (amount == null || amount <= 0) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(
                      content: Text('Geçerli bir tutar girin'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  return;
                }

                final companyId = ref.read(activeCompanyIdProvider);
                final customer = _customer;
                if (companyId == null || customer == null) return;

                final note = _noteController.text.trim();
                await ref.read(customerLedgerRepositoryProvider).updatePaymentEntry(
                      companyId: companyId,
                      customerId: customer.id,
                      entry: entry,
                      amount: amount,
                      note: note.isEmpty ? null : note,
                    );

                if (!mounted) return;
                Navigator.of(context).pop();
                await _load();
              },
              child: const Text('Kaydet'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showPaymentDetails(
    CustomerLedgerEntry entry, {
    required String createdByLabel,
    required bool canEdit,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Tahsilat Detayı',
                      style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('Tutar: ${formatMoney(entry.amount)}'),
              const SizedBox(height: 4),
              Text('Açıklama: ${entry.note ?? '-'}'),
              const SizedBox(height: 4),
              Text('Kullanıcı: $createdByLabel'),
              const SizedBox(height: 4),
              Text('Tarih: ${_formatDateTime(entry.createdAt)}'),
              const SizedBox(height: 16),
              if (canEdit) ...[
                FilledButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _openEditPaymentDialog(entry);
                  },
                  child: const Text('Tahsilatı Düzenle'),
                ),
                const SizedBox(height: 8),
                FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    foregroundColor: Colors.red.shade700,
                  ),
                  onPressed: () async {
                    final navigator = Navigator.of(ctx);

                    final confirmed = await showDialog<bool>(
                      context: ctx,
                      builder: (context) {
                        return AlertDialog(
                          title: const Text('Tahsilatı sil'),
                          content: const Text(
                            'Bu tahsilat silinecek. Bu işlem geri alınamaz. Devam edilsin mi?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: const Text('Vazgeç'),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red.shade700,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () => Navigator.of(context).pop(true),
                              child: const Text('Sil'),
                            ),
                          ],
                        );
                      },
                    );

                    if (confirmed != true) return;

                    final companyId = ref.read(activeCompanyIdProvider);
                    final customer = _customer;
                    if (companyId == null || customer == null) return;

                    await ref.read(customerLedgerRepositoryProvider).softDeleteEntry(
                          companyId: companyId,
                          customerId: customer.id,
                          entry: entry,
                        );

                    if (!ctx.mounted) return;
                    navigator.pop();
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      const SnackBar(
                        content: Text('Tahsilat silindi'),
                        behavior: SnackBarBehavior.floating,
                        duration: Duration(seconds: 2),
                      ),
                    );
                    await _load();
                  },
                  child: const Text('Tahsilatı Sil'),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final customer = _customer;
    final currentUser = ref.watch(currentUserProvider);
    final isAdmin = currentUser != null && currentUser.role == UserRole.admin;

    final membersAsync = ref.watch(_companyMembersMapProvider);
    final membersMap = membersAsync.asData?.value ?? const <String, CompanyMember>{};

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
                            final dateString = _formatDateTime(entry.createdAt);

                            final createdByLabel = membersMap[entry.meta.createdBy]?.displayName.trim().isNotEmpty == true
                                ? membersMap[entry.meta.createdBy]!.displayName
                                : entry.meta.createdBy;

                            return Card(
                              child: ListTile(
                                title: Text(formatMoney(entry.amount)),
                                subtitle: Text(
                                  entry.note ?? 'Tahsilat',
                                ),
                                trailing: Text(dateString),
                                onTap: () async {
                                  await _showPaymentDetails(
                                    entry,
                                    createdByLabel: createdByLabel,
                                    canEdit: isAdmin,
                                  );
                                },
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
