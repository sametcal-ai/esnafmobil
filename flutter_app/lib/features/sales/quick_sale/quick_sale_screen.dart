import 'package:flutter/material.dart';
import 'package:flutter_beep/flutter_beep.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/config/app_settings.dart';
import '../../../core/config/money_formatter.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../customers/data/customer_repository.dart';
import '../../customers/data/customer_ledger_repository.dart';
import '../../customers/domain/customer.dart';
import '../domain/pos_controller.dart';
import '../domain/pos_models.dart';
import '../held_sales/held_sales_provider.dart';

enum QuickSalePaymentType {
  cash,
  card,
  credit,
}

class QuickSalePaymentState {
  final QuickSalePaymentType type;
  final Customer? selectedCustomer;

  const QuickSalePaymentState({
    required this.type,
    required this.selectedCustomer,
  });

  factory QuickSalePaymentState.initial() {
    return const QuickSalePaymentState(
      type: QuickSalePaymentType.cash,
      selectedCustomer: null,
    );
  }

  QuickSalePaymentState copyWith({
    QuickSalePaymentType? type,
    Customer? selectedCustomer,
  }) {
    return QuickSalePaymentState(
      type: type ?? this.type,
      selectedCustomer: selectedCustomer,
    );
  }
}

class QuickSalePaymentController
    extends StateNotifier<QuickSalePaymentState> {
  QuickSalePaymentController() : super(QuickSalePaymentState.initial());

  void setType(QuickSalePaymentType type) {
    state = state.copyWith(
      type: type,
      selectedCustomer: type == QuickSalePaymentType.credit
          ? state.selectedCustomer
          : null,
    );
  }

  void setCustomer(Customer? customer) {
    state = state.copyWith(selectedCustomer: customer);
  }

  void reset() {
    state = QuickSalePaymentState.initial();
  }
}

final quickSalePaymentProvider =
    StateNotifierProvider<QuickSalePaymentController, QuickSalePaymentState>(
        (ref) {
  return QuickSalePaymentController();
});

final quickSaleCustomersProvider = FutureProvider<List<Customer>>((ref) async {
  final repo = CustomerRepository();
  return repo.getAllCustomers();
});

class QuickSaleScreen extends ConsumerStatefulWidget {
  const QuickSaleScreen({super.key});

  @override
  ConsumerState<QuickSaleScreen> createState() => _QuickSaleScreenState();
}

class _QuickSaleScreenState extends ConsumerState<QuickSaleScreen> {
  final TextEditingController _barcodeController = TextEditingController();
  final FocusNode _barcodeFocusNode = FocusNode();
  final MobileScannerController _mobileScannerController =
      MobileScannerController();

  bool _isCameraMode = false;

  String? _lastCameraBarcode;
  DateTime? _lastCameraScanAt;

  String? _lastManualBarcode;
  DateTime? _lastManualScanAt;

  @override
  void initState() {
    super.initState();
    _barcodeFocusNode.addListener(_handleFocusChange);
  }

  void _handleFocusChange() {
    if (!_barcodeFocusNode.hasFocus && !_isCameraMode) {
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
    _mobileScannerController.dispose();
    super.dispose();
  }

  Future<void> _handleBarcode(String value, {required bool fromCamera}) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return;
    }

    final settings = ref.read(appSettingsProvider);
    final delayMillis =
        (settings.barcodeScanDelaySeconds * 1000).clamp(500, 10000).toInt();
    final minDiff = Duration(milliseconds: delayMillis);

    final now = DateTime.now();

    if (fromCamera) {
      if (_lastCameraBarcode == trimmed &&
          _lastCameraScanAt != null &&
          now.difference(_lastCameraScanAt!) < minDiff) {
        return;
      }
      _lastCameraBarcode = trimmed;
      _lastCameraScanAt = now;
    } else {
      if (_lastManualBarcode == trimmed &&
          _lastManualScanAt != null &&
          now.difference(_lastManualScanAt!) < minDiff) {
        return;
      }
      _lastManualBarcode = trimmed;
      _lastManualScanAt = now;
    }

    final posController = ref.read(posControllerProvider.notifier);
    final result = posController.handleBarcode(trimmed);

    _barcodeController.clear();

    if (result == ScanResult.notFound) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ürün bulunamadı'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
      await FlutterBeep.error();
    } else {
      await FlutterBeep.success();
    }
  }

  void _onBarcodeSubmitted(String value) {
    _handleBarcode(value, fromCamera: false);
  }

  @override
  Widget build(BuildContext context) {
    final posState = ref.watch(posControllerProvider);
    final posController = ref.read(posControllerProvider.notifier);

    return AppScaffold(
      title: 'Hızlı Satış',
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
                        labelText: 'Barkod okut / yaz',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _barcodeController.clear,
                    icon: const Icon(Icons.clear),
                    tooltip: 'Temizle',
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
                  child: MobileScanner(
                    controller: _mobileScannerController,
                    onDetect: (capture) async {
                      if (!_isCameraMode) return;
                      if (capture.barcodes.isEmpty) return;

                      String? value;
                      for (final barcode in capture.barcodes) {
                        final candidate =
                            barcode.rawValue ?? barcode.displayValue;
                        if (candidate != null && candidate.trim().isNotEmpty) {
                          value = candidate;
                          break;
                        }
                      }

                      if (value == null) {
                        return;
                      }

                      await _handleBarcode(value, fromCamera: true);
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
          const Divider(height: 0),
          Expanded(
            child: posState.items.isEmpty
                ? const Center(
                    child: Text(
                      'Ürün okutun',
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
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
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
                                    icon: const Icon(Icons.add_circle_outline),
                                    iconSize: 28,
                                    onPressed: () =>
                                        posController.incrementItem(item),
                                  ),
                                ],
                              ),
                            ),
                            onLongPress: () => posController.removeItem(item),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          _BottomTotalsBar(
            total: posState.total,
            canHold: posState.hasItems,
            canComplete: posState.hasItems,
            onHold: () async {
              final saved =
                  await _showHoldSaleDialog(context, ref, posState);
              if (!mounted) return;
              if (saved) {
                posController.clearCart();
              }
            },
            onClear: posState.hasItems ? posController.clearCart : null,
            onComplete: () async {
              await _showPaymentModal(context, ref, posState, posController);
            },
          ),
        ],
      ),
    );
  }

  Future<bool> _showHoldSaleDialog(
    BuildContext context,
    WidgetRef ref,
    PosState posState,
  ) async {
    if (!posState.hasItems) return false;

    final controller = TextEditingController();

    final confirmed = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Satışı Beklet'),
          content: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: TextField(
                controller: controller,
                autofocus: true,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Satış adı',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: const Text('Kaydet'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (confirmed == null) return false;

    final name = confirmed.trim();
    if (name.isEmpty) {
      if (!context.mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Satış adı boş olamaz'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
      return false;
    }

    await ref.read(heldSalesControllerProvider.notifier).holdSale(
          name: name,
          items: posState.items,
          total: posState.total,
        );

    if (!context.mounted) return true;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Satış beklemeye alındı'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
    return true;
  }

  Future<void> _showPaymentModal(
    BuildContext context,
    WidgetRef ref,
    PosState posState,
    PosController posController,
  ) async {
    if (!posState.hasItems) return;

    ref.read(quickSalePaymentProvider.notifier).reset();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return Consumer(
          builder: (context, ref, _) {
            final paymentState = ref.watch(quickSalePaymentProvider);
            final customersAsync = ref.watch(quickSaleCustomersProvider);

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Ödeme Seç',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 12),
                    RadioListTile<QuickSalePaymentType>(
                      value: QuickSalePaymentType.cash,
                      groupValue: paymentState.type,
                      title: const Text('Nakit'),
                      onChanged: (value) {
                        if (value == null) return;
                        ref
                            .read(quickSalePaymentProvider.notifier)
                            .setType(value);
                      },
                    ),
                    RadioListTile<QuickSalePaymentType>(
                      value: QuickSalePaymentType.card,
                      groupValue: paymentState.type,
                      title: const Text('Kredi Kartı'),
                      onChanged: (value) {
                        if (value == null) return;
                        ref
                            .read(quickSalePaymentProvider.notifier)
                            .setType(value);
                      },
                    ),
                    RadioListTile<QuickSalePaymentType>(
                      value: QuickSalePaymentType.credit,
                      groupValue: paymentState.type,
                      title: const Text('Veresiye'),
                      onChanged: (value) {
                        if (value == null) return;
                        ref
                            .read(quickSalePaymentProvider.notifier)
                            .setType(value);
                      },
                    ),
                    if (paymentState.type == QuickSalePaymentType.credit) ...[
                      const SizedBox(height: 8),
                      customersAsync.when(
                        data: (customers) {
                          if (customers.isEmpty) {
                            return const Text(
                                'Veresiye için önce müşteri ekleyin');
                          }

                          return Autocomplete<Customer>(
                            displayStringForOption: (c) => c.name,
                            optionsBuilder: (value) {
                              final query = value.text.trim().toLowerCase();
                              if (query.isEmpty) {
                                return const Iterable<Customer>.empty();
                              }
                              return customers.where((c) {
                                final name = c.name.toLowerCase();
                                final phone = (c.phone ?? '').toLowerCase();
                                return name.contains(query) ||
                                    phone.contains(query);
                              });
                            },
                            onSelected: (customer) {
                              ref
                                  .read(quickSalePaymentProvider.notifier)
                                  .setCustomer(customer);
                            },
                            fieldViewBuilder:
                                (context, textController, focusNode, onSubmit) {
                              return TextField(
                                controller: textController,
                                focusNode: focusNode,
                                textInputAction: TextInputAction.done,
                                decoration: const InputDecoration(
                                  labelText: 'Müşteri ara / seç',
                                  border: OutlineInputBorder(),
                                ),
                              );
                            },
                          );
                        },
                        loading: () => const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: LinearProgressIndicator(),
                        ),
                        error: (_, __) =>
                            const Text('Müşteriler yüklenemedi'),
                      ),
                    ],
                    const SizedBox(height: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () async {
                        final ok = await _completeSaleFromModal(
                          context,
                          ref,
                          posState,
                          posController,
                        );
                        if (ok && context.mounted) {
                          Navigator.of(context).pop();
                        }
                      },
                      child: const Text('Satışı Tamamla'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Vazgeç'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<bool> _completeSaleFromModal(
    BuildContext context,
    WidgetRef ref,
    PosState posState,
    PosController posController,
  ) async {
    if (!posState.hasItems) return false;

    final paymentState = ref.read(quickSalePaymentProvider);

    if (paymentState.type == QuickSalePaymentType.cash) {
      final saleId = await posController.completeSale(
        paymentMethod: 'cash',
      );

      if (!context.mounted) return false;

      if (saleId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Yetersiz stok. Lütfen sepeti kontrol edin.'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
        return false;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Satış tamamlandı (Nakit)'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
      return true;
    }

    if (paymentState.type == QuickSalePaymentType.card) {
      final saleId = await posController.completeSale(
        paymentMethod: 'card',
      );

      if (!context.mounted) return false;

      if (saleId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Yetersiz stok. Lütfen sepeti kontrol edin.'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
        return false;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Satış tamamlandı (Kredi Kartı)'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
      return true;
    }

    final customers = await ref.read(quickSaleCustomersProvider.future);
    if (customers.isEmpty) {
      if (!context.mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veresiye için önce müşteri ekleyin'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
      return false;
    }

    final customer = paymentState.selectedCustomer;
    if (customer == null) {
      if (!context.mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen bir müşteri seçin'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
      return false;
    }

    final saleId = await posController.completeSale(
      customerId: customer.id,
      paymentMethod: 'credit',
    );

    if (!context.mounted) return false;

    if (saleId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Yetersiz stok. Veresiye satış gerçekleştirilemedi.'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
      return false;
    }

    final ledgerRepo = CustomerLedgerRepository(CustomerRepository());
    await ledgerRepo.addSaleEntry(
      customer: customer,
      amount: posState.total,
      note: 'POS veresiye satış',
      saleId: saleId,
    );

    if (!context.mounted) return false;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Veresiye satış kaydedildi'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
    return true;
  }
}

class _BottomTotalsBar extends StatelessWidget {
  final double total;
  final bool canHold;
  final bool canComplete;
  final VoidCallback onHold;
  final VoidCallback? onClear;
  final VoidCallback onComplete;

  const _BottomTotalsBar({
    required this.total,
    required this.canHold,
    required this.canComplete,
    required this.onHold,
    required this.onClear,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        border: Border(
          top: BorderSide(
            color: theme.dividerColor,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Toplam Tutar',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                formatMoney(total),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              SizedBox(
                width: 52,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    shape: const CircleBorder(),
                    padding: EdgeInsets.zero,
                    backgroundColor: Colors.orange.shade600,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: canHold ? onHold : null,
                  child: const Icon(Icons.pause),
                ),
              ),
              const SizedBox(width: 12),
              if (onClear != null)
                Expanded(
                  child: OutlinedButton(
                    onPressed: onClear,
                    child: const Text('Sepeti Temizle'),
                  ),
                )
              else
                const Spacer(),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: canComplete ? onComplete : null,
              child: const Text('Satışı Tamamla'),
            ),
          ),
        ],
      ),
    );
  }
}
