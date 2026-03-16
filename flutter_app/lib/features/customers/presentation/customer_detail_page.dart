import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_settings.dart';
import '../../../core/config/money_formatter.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../company/domain/active_company_provider.dart';
import '../data/customer_repository.dart';
import '../data/customer_ledger_repository.dart';
import '../domain/customer.dart';
import '../domain/customer_controller.dart';
import '../domain/customer_ledger.dart';
import '../../sales/data/sales_repository.dart';

class CustomerDetailPage extends ConsumerStatefulWidget {
  final String customerId;

  const CustomerDetailPage({
    super.key,
    required this.customerId,
  });

  @override
  ConsumerState<CustomerDetailPage> createState() =>
      _CustomerDetailPageState();
}

class _CustomerDetailPageState
    extends ConsumerState<CustomerDetailPage> {
  CustomerDetailController? _controller;
  VoidCallback? _removeControllerListener;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _initController();
  }

  @override
  void dispose() {
    _removeControllerListener?.call();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initController() async {
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

    final settings = ref.read(appSettingsProvider);

    setState(() {
      _controller = CustomerDetailController(
        companyId: companyId,
        customer: customer,
        ledgerRepository: ledgerRepo,
        pageSize: settings.movementsPageSize,
      );

      _removeControllerListener?.call();
      _removeControllerListener = _controller!.addListener((_) {
        if (!mounted) return;
        setState(() {});
      });
    });
  }

  void _onScroll() {
    final controller = _controller;
    if (controller == null) return;
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (!position.hasContentDimensions) return;

    final max = position.maxScrollExtent;
    if (max <= 0) return;
    final threshold = max * 0.8;
    if (position.pixels >= threshold) {
      controller.loadMore();
    }
  }

  Future<void> _editCustomer(Customer customer) async {
    final repo = ref.read(customerRepositoryProvider);
    final updated = await showDialog<Customer?>(
      context: context,
      builder: (context) {
        return _EditCustomerDialog(customer: customer);
      },
    );

    if (updated == null) return;

    final companyId = ref.read(activeCompanyIdProvider);
    if (companyId == null) return;

    final saved = await repo.updateCustomer(companyId, updated);
    if (!mounted) return;

    if (saved == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Müşteri güncellenemedi'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      final controller = _controller;
      if (controller != null) {
        final settings = ref.read(appSettingsProvider);
        _controller = CustomerDetailController(
          companyId: companyId,
          customer: saved,
          ledgerRepository: ref.read(customerLedgerRepositoryProvider),
          pageSize: settings.movementsPageSize,
        );

        _removeControllerListener?.call();
        _removeControllerListener = _controller!.addListener((_) {
          if (!mounted) return;
          setState(() {});
        });
      }
    });
  }

  void _openCollections(Customer customer) {
    context.push('/customers/${customer.id}/collections');
  }

  void _openStatement(Customer customer) {
    context.push('/customers/${customer.id}/statement');
  }

  Future<void> _showEntryDetails(CustomerLedgerEntry entry) async {
    final isSale = entry.type == LedgerEntryType.sale;

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

        if (!isSale) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tahsilat Detayı',
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
                        : 'Tahsilat',
                  ),
                ],
              ),
            ),
          );
        }

       
            final saleId = entry.saleId;
        final companyId = ref.read(activeCompanyIdProvider);

        return FutureBuilder(
          future: saleId == null || companyId == null
              ? Future.value(null)
              : SalesRepository().getSaleById(companyId, saleId),
          builder: (context, snapshot) {
            final sale = snapshot.data as dynamic;

            final hasItems =
                sale != null && sale.items is List && sale.items.isNotEmpty;

            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Satış Detayı',
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
                    if (!hasItems)
                      const Text(
                        'Bu satış için ürün kalemleri eski kayıtlar için yok.',
                        style: TextStyle(color: Colors.grey),
                      )
                    else ...[
                      const SizedBox(height: 4),
                      Text(
                        'Ara Toplam: ${formatMoney(sale.subtotal)}',
                      ),
                      Text(
                        'İndirim: -${formatMoney(sale.discount)}',
                      ),
                      Text(
                        'KDV: ${formatMoney(sale.vat)}',
                      ),
                      Text(
                        'Toplam: ${formatMoney(sale.total)}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Ürünler',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: sale.items.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final item = sale.items[index];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(item.productName),
                              subtitle: Text(
                                '${item.quantity} x ${formatMoney(item.unitPrice)}',
                              ),
                              trailing: Text(
                                formatMoney(item.lineTotal),
                              ),
                            );
                          },
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

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) {
      return const AppScaffold(
        title: 'Müşteri',
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final state = controller.state;
    final customer = state.customer;

    return AppScaffold(
      title: 'Müşteri Detayı',
      body: Column(
        children: [
          // Üst bölüm: müşteri bilgileri + Düzenle
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customer.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (customer.code != null &&
                          customer.code!.trim().isNotEmpty)
                        Text('Müşteri Kodu: ${customer.code}'),
                      if (customer.phone != null &&
                          customer.phone!.trim().isNotEmpty)
                        Text('Telefon: ${customer.phone}'),
                      if (customer.email != null &&
                          customer.email!.trim().isNotEmpty)
                        Text('E-posta: ${customer.email}'),
                      if (customer.workplace != null &&
                          customer.workplace!.trim().isNotEmpty)
                        Text('İşyeri: ${customer.workplace}'),
                      if (customer.note != null &&
                          customer.note!.trim().isNotEmpty)
                        Text('Not: ${customer.note}'),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _editCustomer(customer),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Düzenle'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Orta bölüm: bakiye kartı
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
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    children: [
                      // Tahsilatlar kartı (üstte)
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.payments_outlined),
                          title: const Text(
                            'Tahsilatlar',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: const Text(
                            'Tahsilat geçmişini görüntüle ve yeni tahsilat ekle',
                          ),
                          trailing:
                              const Icon(Icons.chevron_right_outlined),
                          onTap: () => _openCollections(customer),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Ekstre butonu
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.receipt_long_outlined),
                          title: const Text(
                            'Ekstre',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: const Text(
                            'Tarih aralığına göre hesap ekstresi',
                          ),
                          trailing:
                              const Icon(Icons.chevron_right_outlined),
                          onTap: () => _openStatement(customer),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Hareketler kartı
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
                                children: [
                                  ListView.builder(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    itemCount: state.entries.length,
                                    itemBuilder: (context, index) {
                                      final entry = state.entries[index];
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
                                              (isSale
                                                  ? 'Veresiye satış'
                                                  : 'Tahsilat'),
                                        ),
                                        trailing: Text(
                                          isSale ? 'Satış' : 'Tahsilat',
                                        ),
                                        leading: Text(
                                          dateString,
                                          style:
                                              const TextStyle(fontSize: 12),
                                        ),
                                        onTap: () =>
                                            _showEntryDetails(entry),
                                      );
                                    },
                                  ),
                                  if (state.isLoadingMore)
                                    const Padding(
                                      padding: EdgeInsets.all(12),
                                      child: Center(
                                        child:
                                            CircularProgressIndicator(),
                                      ),
                                    ),
                                ],
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

class _EditCustomerDialog extends StatefulWidget {
  final Customer customer;

  const _EditCustomerDialog({required this.customer});

  @override
  State<_EditCustomerDialog> createState() => _EditCustomerDialogState();
}

class _EditCustomerDialogState extends State<_EditCustomerDialog> {
  late final TextEditingController _codeController;
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _workplaceController;
  late final TextEditingController _noteController;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final c = widget.customer;
    _codeController = TextEditingController(text: c.code ?? '');
    _nameController = TextEditingController(text: c.name);
    _phoneController = TextEditingController(text: c.phone ?? '');
    _emailController = TextEditingController(text: c.email ?? '');
    _workplaceController =
        TextEditingController(text: c.workplace ?? '');
    _noteController = TextEditingController(text: c.note ?? '');
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _workplaceController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Müşteri adı boş olamaz'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final updated = widget.customer.copyWith(
      code: _codeController.text.trim().isEmpty
          ? null
          : _codeController.text.trim(),
      name: name,
      phone: _phoneController.text.trim().isEmpty
          ? null
          : _phoneController.text.trim(),
      email: _emailController.text.trim().isEmpty
          ? null
          : _emailController.text.trim(),
      workplace: _workplaceController.text.trim().isEmpty
          ? null
          : _workplaceController.text.trim(),
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
      title: const Text('Müşteri Düzenle'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _codeController,
              decoration: const InputDecoration(
                labelText: 'Müşteri kodu',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Müşteri adı',
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
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'E-posta',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _workplaceController,
              decoration: const InputDecoration(
                labelText: 'İşyeri bilgisi',
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