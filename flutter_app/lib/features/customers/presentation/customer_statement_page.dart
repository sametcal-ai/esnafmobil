import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/config/money_formatter.dart';
import '../../../core/firestore/firestore_refs.dart';
import '../../../core/firestore/models/company_member.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../auth/domain/current_user_provider.dart' show currentUserProvider;
import '../../auth/domain/user.dart';
import '../../company/domain/active_company_provider.dart';
import '../../sales/data/sales_repository.dart';
import '../../sales/presentation/sale_edit_args.dart';
import '../data/customer_ledger_repository.dart';
import '../data/customer_repository.dart';
import '../data/customer_statement_pdf_service.dart';
import '../domain/customer.dart';
import '../domain/customer_ledger.dart';
import '../domain/customer_controller.dart';

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

class CustomerStatementPage extends ConsumerStatefulWidget {
  final String customerId;

  const CustomerStatementPage({super.key, required this.customerId});

  @override
  ConsumerState<CustomerStatementPage> createState() =>
      _CustomerStat</old_code><new_code>class _CustomerStatementPageState
    extends ConsumerState<CustomerStatementPage> {
  Customer? _customer;
  bool _loading = true;
  bool _sharing = false;

  String _paymentLabel(String method) {
    switch (method) {
      case 'cash':
        return 'Nakit';
      case 'card':
        return 'Kredi Kartı';
      case 'credit':
        return 'Veresiye';
      case 'split':
        return 'Parçalı';
      default:
        return method;
    }
  }

  Future<void> _showSaleDetails(
    Sale sale, {
    required String customerLabel,
    required String createdByLabel,
    required bool canEdit,
    required bool canCancel,
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
                      'Satış Detayı',
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
              Text('Cari: $customerLabel'),
              const SizedBox(height: 4),
              Text('Ödeme: ${_paymentLabel(sale.paymentMethod)}'),
              const SizedBox(height: 4),
              Text('Kullanıcı: $createdByLabel'),
              const SizedBox(height: 4),
              Text('Tarih: ${sale.createdAt}'),
              const SizedBox(height: 12),
              const Divider(height: 0),
              const SizedBox(height: 12),
              Text(
                'Ürünler',
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: sale.items.length,
                  separatorBuilder: (_, __) => const Divider(height: 0),
                  itemBuilder: (context, index) {
                    final item = sale.items[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        item.productName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text('${item.quantity} x ${formatMoney(item.unitPrice)}'),
                      trailing: Text(
                        formatMoney(item.lineTotal),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              const Divider(height: 0),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Expanded(child: Text('Ara Toplam')),
                  Text(formatMoney(sale.subtotal)),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Expanded(child: Text('İndirim')),
                  Text(sale.discount <= 0 ? formatMoney(0) : '- ${formatMoney(sale.discount)}'),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Expanded(child: Text('KDV')),
                  Text(formatMoney(sale.vat)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Toplam',
                      style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  Text(
                    formatMoney(sale.total),
                    style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (canEdit)
                FilledButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    context.goNamed(
                      'sale_edit',
                      extra: SaleEditArgs(sale: sale),
                    );
                  },
                  child: const Text('Satışı Düzenle'),
                ),
              if (canCancel) ...[
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
                          title: const Text('Satışı iptal et'),
                          content: const Text(
                            'Bu satış iptal edilecek. Bu işlem geri alınamaz. Devam edilsin mi?',
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
                              child: const Text('İptal Et'),
                            ),
                          ],
                        );
                      },
                    );

                    if (confirmed != true) return;

                    final companyId = ref.read(activeCompanyIdProvider);
                    if (companyId == null) return;

                    final ok = await ref
                        .read(salesRepositoryProvider)
                        .softDeleteSaleCascade(
                          companyId: companyId,
                          sale: sale,
                        );

                    if (!ctx.mounted) return;

                    if (!ok) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(
                          content: Text('Satış iptal edilemedi'),
                          behavior: SnackBarBehavior.floating,
                          duration: Duration(seconds: 2),
                        ),
                      );
                      return;
                    }

                    navigator.pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Satış iptal edildi'),
                        behavior: SnackBarBehavior.floating,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  child: const Text('Satışı İptal Et'),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _openSaleDetailsFromEntry(
    CustomerLedgerEntry entry, {
    required String customerLabel,
    required String createdByLabel,
    required bool canEdit,
    required bool canCancel,
  }) async {
    final saleId = entry.saleId;
    if (saleId == null) return;

    final companyId = ref.read(activeCompanyIdProvider);
    if (companyId == null) return;

    final sale = await ref.read(salesRepositoryProvider).getSaleById(companyId, saleId);
    if (!mounted) return;

    if (sale == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Satış bulunamadı'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    await _showSaleDetails(
      sale,
      customerLabel: customerLabel,
      createdByLabel: createdByLabel,
      canEdit: canEdit,
      canCancel: canCancel,
    );
  }

  DateTime? _startDate;
  DateTime? _endDate;

  double _previousBalance = 0;
  List<CustomerLedgerEntry> _entries = const [];

  @override
  void initState() {
    super.initState();
    _initCustomer();
  }

  Future<void> _initCustomer() async {
    final companyId = ref.read(activeCompanyIdProvider);
    if (companyId == null) return;

    final repo = ref.read(customerRepositoryProvider);
    final customer = await repo.getCustomerById(companyId, widget.customerId);
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

    setState(() {
      _customer = customer;
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
    final customer = _customer;
    if (customer == null) return;
    final start = _startDate;
    final end = _endDate;
    if (start == null || end == null) return;

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

    final companyId = ref.read(activeCompanyIdProvider);
    if (companyId == null) return;

    final ledgerRepo = ref.read(customerLedgerRepositoryProvider);
    final previousBalance =
        await ledgerRepo.getBalanceForCustomerBefore(companyId, customer.id, start);
    final entries = await ledgerRepo.getEntriesForCustomerInDateRange(
      companyId,
      customer.id,
      start: start,
      end: end,
    )..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (!mounted) return;
    setState(() {
      _previousBalance = previousBalance;
      _entries = entries;
      _loading = false;
    });
  }

  Future<void> _shareStatement() async {
    final customer = _customer;
    final start = _startDate;
    final end = _endDate;

    if (customer == null || start == null || end == null) {
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
      // 1) PDF üretimi
      Uint8List bytes;
      try {
        final companyId = ref.read(activeCompanyIdProvider);
        if (companyId == null) {
          throw Exception('Aktif firma seçili değil');
        }

        final pdfService = CustomerStatementPdfService(
          salesRepository: ref.read(salesRepositoryProvider),
        );
        bytes = await pdfService.generateStatementPdf(
          companyId: companyId,
          customer: customer,
          previousBalance: _previousBalance,
          entries: _entries,
          start: start,
          end: end,
        );
      } catch (e, st) {
        debugPrint('PDF GENERATION ERROR: $e');
        debugPrint('STACKTRACE: $st');
        debugPrint(
          'PDF GENERATION CONTEXT => customerId=${customer.id}, '
          'entries=${_entries.length}, previousBalance=$_previousBalance, '
          'start=$_startDate, end=$_endDate, isWeb=$kIsWeb, '
          'platform=${kIsWeb ? 'web' : Platform.operatingSystem}',
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

      // 2) Dosyaya yazma
      final tempDir = await getTemporaryDirectory();
      final safeName =
          (customer.name.isNotEmpty ? customer.name : 'musteri')
              .replaceAll('/', ' ')
              .replaceAll('\\\\', ' ');
      final file = File(
        '${tempDir.path}/ekstre_${safeName}_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
      await file.writeAsBytes(bytes, flush: true);
      debugPrint(
        'Customer statement PDF created at: ${file.path} '
        '(customerId=${customer.id}, platform=${kIsWeb ? 'web' : Platform.operatingSystem})',
      );

      // 3) Paylaşım
      try {
        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'Müşteri Ekstresi - ${customer.name}',
        );
      } catch (e, st) {
        debugPrint('PDF SHARE ERROR: $e');
        debugPrint('STACKTRACE: $st');
        debugPrint(
          'PDF SHARE CONTEXT => customerId=${customer.id}, '
          'filePath=${file.path}, isWeb=$kIsWeb, '
          'platform=${kIsWeb ? 'web' : Platform.operatingSystem}',
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ekstre dosyası paylaşılırken bir hata oluştu'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e, st) {
      debugPrint('STATEMENT SHARE FLOW ERROR: $e');
      debugPrint('STACKTRACE: $st');
      debugPrint(
        'STATEMENT SHARE FLOW CONTEXT => customerId=${customer?.id}, '
        'entries=${_entries.length}, previousBalance=$_previousBalance, '
        'start=$_startDate, end=$_endDate, isWeb=$kIsWeb, '
        'platform=${kIsWeb ? 'web' : Platform.operatingSystem}',
      );
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
    final customer = _customer;

    final currentUser = ref.watch(currentUserProvider);
    final isAdmin = currentUser != null && currentUser.role == UserRole.admin;

    final membersAsync = ref.watch(_companyMembersMapProvider);
    final membersMap = membersAsync.asData?.value ?? const <String, CompanyMember>{};

    return AppScaffold(
      title: customer == null ? 'Ekstre' : '${customer.name} - Ekstre',
      actions: [
        if (!_loading && customer != null)
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
      body: _loading && customer == null
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
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Önceki Bakiye',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            formatMoney(_previousBalance),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: _previousBalance > 0
                                  ? Colors.red.shade700
                                  : (_previousBalance < 0
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
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _entries.isEmpty
                          ? const Center(
                              child: Text('Seçilen aralıkta hareket yok'),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              itemCount: _entries.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 4),
                              itemBuilder: (context, index) {
                                final entry = _entries[index];
                                final isSale =
                                    entry.type == LedgerEntryType.sale;
                                final sign = isSale ? '+' : '-';
                                final color = isSale
                                    ? Colors.red.shade700
                                    : Colors.green.shade700;
                                final dateString =
                                    '${entry.createdAt.day.toString().padLeft(2, '0')}.'
                                    '${entry.createdAt.month.toString().padLeft(2, '0')}.'
                                    '${entry.createdAt.year} '
                                    '${entry.createdAt.hour.toString().padLeft(2, '0')}:'
                                    '${entry.createdAt.minute.toString().padLeft(2, '0')}';

                                final createdByLabel = membersMap[entry.meta.createdBy]?.displayName.trim().isNotEmpty == true
                                    ? membersMap[entry.meta.createdBy]!.displayName
                                    : entry.meta.createdBy;

                                return Card(
                                  child: ListTile(
                                    leading: Text(
                                      dateString,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    title: Text(
                                      '$sign ${formatMoney(entry.amount)}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: color,
                                      ),
                                    ),
                                    subtitle: Text(
                                      entry.note ??
                                          (isSale
                                              ? 'Veresiye satış'
                                              : 'Tahsilat'),
                                    ),
                                    trailing: Text(
                                      isSale ? 'Satış' : 'Tahsilat',
                                    ),
                                    onTap: !isSale || customer == null
                                        ? null
                                        : () => _openSaleDetailsFromEntry(
                                              entry,
                                              customerLabel: customer.name,
                                              createdByLabel: createdByLabel,
                                              canEdit: isAdmin,
                                              canCancel: isAdmin,
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