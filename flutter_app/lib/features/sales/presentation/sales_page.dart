import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_beep/flutter_beep.dart';

import '../../../core/scanner/barcode_scanner_view.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/config/app_settings.dart';
import '../../../core/config/money_formatter.dart';
import '../../company/domain/active_company_provider.dart';
import '../../customers/data/customer_repository.dart';
import '../../customers/data/customer_ledger_repository.dart';
import '../../customers/domain/customer.dart';
import '../domain/pos_controller.dart';
import '../domain/pos_models.dart';

enum PaymentType {
  cash,
  credit,
}

class SalesPage extends ConsumerStatefulWidget {
  const SalesPage({super.key});

  @override
  ConsumerState<SalesPage> createState() => _SalesPageState();
}

class _SalesPageState extends ConsumerState<SalesPage> {
  final TextEditingController _barcodeController = TextEditingController();
  final FocusNode _barcodeFocusNode = FocusNode();
  bool _isCameraMode = false;

  

  PaymentType _paymentType = PaymentType.cash;
  List<Customer> _customers = const [];
  bool _customersLoading = false;
  Customer? _selectedCustomer;

  @override
  void initState() {
    super.initState();
    _barcodeFocusNode.addListener(_handleFocusChange);
  }

  void _handleFocusChange() {
    if (!_barcodeFocusNode.hasFocus && !_isCameraMode) {
      // Barkod alanı her zaman aktif kalsın (kamera modu kapalıyken).
      Future.microtask(() {
        if (mounted && !_isCameraMode) {
          FocusScope.of(context).requestFocus(_barcodeFocusNode);
        }
      });
    }
  }

  @override
  void dispose() {
    _barcodeFocusNode.removeListener(_handleFocusChange);
    _barcodeController.dispose();
    _barcodeFocusNode.dispose();
    super.dispose();
  }

  Future<void> _handleBarcode(String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return;
    }

    final posController = ref.read(posControllerProvider.notifier);
    final result = posController.handleBarcode(trimmed);

    _barcodeController.clear();

    if (result == ScanResult.notFound) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ürün bulunamadı'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
      // Başarısız okuma sesi.
      await FlutterBeep.error();
    } else {
      // Başarılı okuma sesi (ürün sepete eklendi veya miktarı artırıldı).
      await FlutterBeep.success();
    }
  }

  Future<void> _loadCustomersIfNeeded() async {
    if (_customers.isNotEmpty || _customersLoading) return;
    setState(() {
      _customersLoading = true;
    });
    final companyId = ref.read(activeCompanyIdProvider);
    if (companyId == null) return;

    final repo = ref.read(customerRepositoryProvider);
    final customers = await repo.getAllCustomers(companyId);
    if (!mounted) return;
    setState(() {
      _customers = customers;
      _customersLoading = false;
      if (_customers.isNotEmpty) {
        _selectedCustomer ??= _customers.first;
      }
    });
  }

  void _onBarcodeSubmitted(String value) {
    // TextField callback'i async olamadığı için, sonuç beklenmeden tetiklenir.
    _handleBarcode(value);
  }

  @override
  Widget build(BuildContext context) {
    final posState = ref.watch(posControllerProvider);
    final posController = ref.read(posControllerProvider.notifier);

    return AppScaffold(
      title: 'Sales',
      body: Column(
        children: [
          if (!_isCameraMode)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _barcodeController,
                      focusNode: _barcodeFocusNode,
                      autofocus: true,
                      onSubmitted: _onBarcodeSubmitted,
                      textInputAction: TextInputAction.done,
                      keyboardType: TextInputType.text,
                      decoration: const InputDecoration(
                        labelText: 'Scan / enter barcode',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AppButton(
                    label: 'Clear',
                    isPrimary: false,
                    onPressed: () {
                      _barcodeController.clear();
                    },
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: _isCameraMode ? 'Kamerayı Kapat' : 'Kameradan Oku',
                    isPrimary: false,
                    isExpanded: true,
                    onPressed: () {
                      setState(() {
                        _isCameraMode = !_isCameraMode;
                      });
                      if (_isCameraMode) {
                        FocusScope.of(context).unfocus();
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                height: 220,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: BarcodeScannerView(
                    ownerId: 'sales_camera',
                    enabled: _isCameraMode,
                    onBarcode: (value) async {
                      if (!_isCameraMode) return;
                      await _handleBarcode(value);
                    },
                  ),
                ),
              ),
            ),
            crossFadeState: _isCameraMode
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                const Text(
                  'Quick discount:',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('None'),
                  selected: posState.discountType == DiscountType.none,
                  onSelected: (_) => posController.setPercentageDiscount(0),
                ),
                const SizedBox(width: 4),
                ChoiceChip(
                  label: const Text('10%'),
                  selected: posState.discountType ==
                          DiscountType.percentage &&
                      posState.discountValue == 10,
                  onSelected: (_) => posController.setPercentageDiscount(10),
                ),
                const SizedBox(width: 4),
                ChoiceChip(
                  label: const Text('20%'),
                  selected: posState.discountType ==
                          DiscountType.percentage &&
                      posState.discountValue == 20,
                  onSelected: (_) => posController.setPercentageDiscount(20),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 0),
          Expanded(
            child: posState.items.isEmpty
                ? const Center(
                    child: Text(
                      'Scan items to start a sale',
                      style: TextStyle(fontSize: 16),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: posState.items.length,
                    itemBuilder: (context, index) {
                      final item = posState.items[index];
                      return Dismissible(
                        key: ValueKey(item.product.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          color: Colors.red.shade400,
                          child: const Icon(
                            Icons.delete_outline,
                            color: Colors.white,
                          ),
                        ),
                        onDismissed: (_) => posController.removeItem(item),
                        child: Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: ListTile(
                            title: Text(
                              item.product.name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              '${item.quantity} x ${formatMoney(item.product.unitPrice)} = ${formatMoney(item.lineTotal)}',
                            ),
                            trailing: SizedBox(
                              width: 170,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                        Icons.remove_circle_outline),
                                    iconSize: 28,
                                    onPressed: () =>
                                        posController.decrementItem(item),
                                  ),
                                  Text(
                                    item.quantity.toString(),
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  IconButton(
                                    icon:
                                        const Icon(Icons.add_circle_outline),
                                    iconSize: 28,
                                    onPressed: () =>
                                        posController.incrementItem(item),
                                  ),
                                ],
                              ),
                            ),
                            onLongPress: () =>
                                posController.removeItem(item),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant,
              border: Border(
                top: BorderSide(
                  color: Theme.of(context).dividerColor,
                ),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _TotalsRow(
                  label: 'Ara Toplam',
                  value: posState.subtotal,
                ),
                if (posState.discountType != DiscountType.none)
                  _TotalsRow(
                    label: 'İndirim',
                    value: -posState.discountAmount,
                  ),
                if (posState.taxRate > 0)
                  _TotalsRow(
                    label: 'KDV (${posState.taxRate.toStringAsFixed(0)}%)',
                    value: posState.taxAmount,
                  ),
                const SizedBox(height: 4),
                _TotalsRow(
                  label: 'Toplam',
                  value: posState.total,
                  isEmphasized: true,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: AppButton(
                        label: 'Clear Cart',
                        isPrimary: false,
                        isExpanded: true,
                        onPressed: posState.hasItems
                            ? posController.clearCart
                            : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: AppButton(
                        label: posState.hasHeldItems
                            ? 'Resume Sale'
                            : 'Hold Sale',
                        isPrimary: false,
                        isExpanded: true,
                        onPressed: posState.hasItems
                            ? posController.holdCurrentSale
                            : (posState.hasHeldItems
                                ? posController.resumeHeldSale
                                : null),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 3,
                      child: AppButton(
                        label: _paymentType == PaymentType.cash
                            ? 'Satışı Tamamla (Nakit)'
                            : 'Satışı Tamamla (Veresiye)',
                        isExpanded: true,
                        onPressed: posState.hasItems
                            ? () async {
                                await _handleCompleteSale(
                                  context,
                                  posState,
                                  posController,
                                );
                              }
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text(
                      'Ödeme yöntemi:',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Nakit'),
                      selected: _paymentType == PaymentType.cash,
                      onSelected: (_) {
                        setState(() {
                          _paymentType = PaymentType.cash;
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Veresiye'),
                      selected: _paymentType == PaymentType.credit,
                      onSelected: (_) async {
                        setState(() {
                          _paymentType = PaymentType.credit;
                        });
                        await _loadCustomersIfNeeded();
                      },
                    ),
                  ],
                ),
                if (_paymentType == PaymentType.credit) ...[
                  const SizedBox(height: 8),
                  if (_customersLoading)
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Cariler yükleniyor...'),
                    )
                  else if (_customers.isEmpty)
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Veresiye için önce müşteri ekleyin'),
                    )
                  else
                    Row(
                      children: [
                        const Text(
                          'Cari seç:',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButton<Customer>(
                            isExpanded: true,
                            value: _selectedCustomer,
                            items: _customers
                                .map(
                                  (c) => DropdownMenuItem<Customer>(
                                    value: c,
                                    child: Text(
                                      c.name,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedCustomer = value;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleCompleteSale(
    BuildContext context,
    PosState posState,
    PosController posController,
  ) async {
    if (!posState.hasItems) return;

    if (_paymentType == PaymentType.cash) {
      final saleId = await posController.completeSale(
        paymentMethod: 'cash',
      );
      if (!mounted) return;

      if (saleId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Yetersiz stok. Lütfen sepeti kontrol edin.'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sale completed (Cash)'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // Veresiye
    await _loadCustomersIfNeeded();
    if (_customers.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veresiye için önce müşteri ekleyin'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (_selectedCustomer == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen bir cari seçin'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final saleId = await posController.completeSale(
      customerId: _selectedCustomer!.id,
      paymentMethod: 'credit',
    );
    if (!mounted) return;

    if (saleId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Yetersiz stok. Veresiye satış gerçekleştirilemedi.'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final companyId = ref.read(activeCompanyIdProvider);
    if (companyId == null) return;

    final ledgerRepo = ref.read(customerLedgerRepositoryProvider);
    await ledgerRepo.addSaleEntry(
      companyId: companyId,
      customer: _selectedCustomer!,
      amount: posState.total,
      note: 'POS veresiye satış',
      saleId: saleId,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Veresiye satış kaydedildi'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }
}

class _TotalsRow extends StatelessWidget {
  final String label;
  final double value;
  final bool isEmphasized;

  const _TotalsRow({
    required this.label,
    required this.value,
    this.isEmphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    final textStyle = isEmphasized
        ? const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          )
        : const TextStyle(
            fontSize: 14,
          );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: textStyle,
            ),
          ),
          Text(
            value < 0
                ? '- ${formatMoney(value.abs())}'
                : formatMoney(value),
            style: textStyle,
          ),
        ],
      ),
    );
  }
}
