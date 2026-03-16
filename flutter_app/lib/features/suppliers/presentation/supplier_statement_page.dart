import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/config/money_formatter.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../company/domain/active_company_provider.dart';
import '../data/supplier_ledger_repository.dart';
import '../data/supplier_repository.dart';
import '../data/supplier_statement_pdf_service.dart';
import '../domain/supplier.dart';
import '../domain/supplier_ledger.dart';
import '../domain/supplier_controller.dart';

class SupplierStatementPage extends ConsumerStatefulWidget {
  final String supplierId;

  const SupplierStatementPage({super.key, required this.supplierId});

  @override
  ConsumerState<SupplierStatementPage> createState() =>
      _SupplierStatementPageState();
}

class _SupplierStatementPageState
    extends ConsumerState<SupplierStatementPage> {
  Supplier? _supplier;
  bool _loading = true;
  bool _sharing = false;

  DateTime? _startDate;
  DateTime? _endDate;

  double _previousBalance = 0;
  List<SupplierLedgerEntry> _entries = const [];

  @override
  void initState() {
    super.initState();
    _initSupplier();
  }

  Future<void> _initSupplier() async {
    final repo = ref.read(supplierRepositoryProvider);
    final supplier = await repo.getSupplierById(widget.supplierId);
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
      _supplier = supplier;
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
    final supplier = _supplier;
    final start = _startDate;
    final end = _endDate;
    if (supplier == null || start == null || end == null) return;

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

    final ledgerRepo = ref.read(supplierLedgerRepositoryProvider);
    final previousBalance = await ledgerRepo.getBalanceForSupplierBefore(
      supplier.id,
      start,
    );
    final entries = await ledgerRepo.getEntriesForSupplierInDateRange(
      supplier.id,
      start: start,
      end: end,
    )
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (!mounted) return;
    setState(() {
      _previousBalance = previousBalance;
      _entries = entries;
      _loading = false;
    });
  }

  Future<void> _shareStatement() async {
    final supplier = _supplier;
    final start = _startDate;
    final end = _endDate;

    if (supplier == null || start == null || end == null) {
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
        final companyId = ref.read(activeCompanyIdProvider);
        if (companyId == null) {
          throw Exception('Aktif firma seçili değil');
        }

        final pdfService = SupplierStatementPdfService();
        bytes = await pdfService.generateStatementPdf(
          companyId: companyId,
          supplier: supplier,
          previousBalance: _previousBalance,
          entries: _entries,
          start: start,
          end: end,
        );
      } catch (e, st) {
        debugPrint('SUPPLIER PDF GENERATION ERROR: $e');
        debugPrint('STACKTRACE: $st');
        debugPrint(
          'SUPPLIER PDF CONTEXT => supplierId=${supplier.id}, '
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

      final tempDir = await getTemporaryDirectory();
      final safeName =
          (supplier.name.isNotEmpty ? supplier.name : 'tedarikci')
              .replaceAll('/', ' ')
              .replaceAll('\\', ' ');
      final file = File(
        '${tempDir.path}/tedarikci_ekstre_${safeName}_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
      await file.writeAsBytes(bytes, flush: true);
      debugPrint(
        'Supplier statement PDF created at: ${file.path} '
        '(supplierId=${supplier.id}, platform=${kIsWeb ? 'web' : Platform.operatingSystem})',
      );

      try {
        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'Tedarikçi Ekstresi - ${supplier.name}',
        );
      } catch (e, st) {
        debugPrint('SUPPLIER PDF SHARE ERROR: $e');
        debugPrint('STACKTRACE: $st');
        debugPrint(
          'SUPPLIER PDF SHARE CONTEXT => supplierId=${supplier.id}, '
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
      debugPrint('SUPPLIER STATEMENT SHARE FLOW ERROR: $e');
      debugPrint('STACKTRACE: $st');
      debugPrint(
        'SUPPLIER STATEMENT FLOW CONTEXT => supplierId=${_supplier?.id}, '
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
    final supplier = _supplier;

    return AppScaffold(
      title:
          supplier == null ? 'Ekstre' : '${supplier.name} - Tedarikçi Ekstresi',
      actions: [
        if (!_loading && supplier != null)
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
      body: _loading && supplier == null
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
                              padding:
                                  const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              itemCount: _entries.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 4),
                              itemBuilder: (context, index) {
                                final entry = _entries[index];
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

                                return Card(
                                  child: ListTile(
                                    leading: Text(
                                      dateString,
                                      style:
                                          const TextStyle(fontSize: 12),
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
                                          (isPurchase ? 'Alış' : 'Ödeme'),
                                    ),
                                    trailing: Text(
                                      isPurchase ? 'Alış' : 'Ödeme',
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
