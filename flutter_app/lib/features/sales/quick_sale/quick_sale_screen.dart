import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_beep/flutter_beep.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../core/scanner/barcode_scanner_view.dart';
import '../../../core/config/money_formatter.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../company/domain/active_company_provider.dart';
import '../../customers/data/customer_repository.dart';
import '../../customers/data/customer_ledger_repository.dart';
import '../../customers/domain/customer.dart';
import '../../products/data/product_repository.dart';
import '../../products/domain/product.dart' as catalog;
import '../domain/pos_controller.dart';
import '../domain/pos_models.dart';
import '../held_sales/held_sales_provider.dart';
import '../presentation/sale_edit_args.dart';
import 'product_search.dart';

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

class QuickSalePaymentController extends Notifier<QuickSalePaymentState> {
  @override
  QuickSalePaymentState build() {
    return QuickSalePaymentState.initial();
  }

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
    NotifierProvider<QuickSalePaymentController, QuickSalePaymentState>(
  QuickSalePaymentController.new,
);

final holdSaleNameDraftProvider = StateProvider<String>((ref) => '');
final quickSaleCustomerQueryProvider = StateProvider<String>((ref) => '');

final quickSaleCustomersProvider = FutureProvider<List<Customer>>((ref) async {
  final companyId = ref.watch(activeCompanyIdProvider);
  if (companyId == null) return const <Customer>[];

  final repo = ref.watch(customerRepositoryProvider);
  return repo.getAllCustomers(companyId);
});

final quickSaleProductsProvider = StreamProvider<List<catalog.Product>>((ref) {
  final companyId = ref.watch(activeCompanyIdProvider);
  if (companyId == null) {
    return const Stream<List<catalog.Product>>.empty();
  }

  final repo = ref.watch(productsRepositoryProvider);
  return repo.watchProducts(companyId);
});

class QuickSaleScreen extends ConsumerWidget {
  const QuickSaleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const _PosScreen();
  }
}

class SaleEditScreen extends ConsumerWidget {
  final SaleEditArgs editArgs;

  const SaleEditScreen({
    super.key,
    required this.editArgs,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _PosScreen(editArgs: editArgs);
  }
}

class _PosScreen extends ConsumerStatefulWidget {
  final SaleEditArgs? editArgs;

  const _PosScreen({
    this.editArgs,
  });

  @override
  ConsumerState<_PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<_PosScreen> {
  final TextEditingController _barcodeController = TextEditingController();
  final FocusNode _barcodeFocusNode = FocusNode();

  bool _isCameraMode = false;
  bool _suppressBarcodeRefocus = false;

  String _productSearchQuery = '';

  String? _lastCameraBarcode;
  DateTime? _lastCameraScanAt;

  String? _lastManualBarcode;
  DateTime? _lastManualScanAt;

  void _applyEditArgs(SaleEditArgs? args) {
    final posController = ref.read(posControllerProvider.notifier);

    if (args == null) {
      // StatefulShellRoute branch'i cached tuttuğu için, farklı sayfalardan
      // /sales'e tekrar dönüldüğünde eski sepet kalabiliyor.
      posController.clearCart();
      return;
    }

    posController.loadCartItems(
      args.sale.items
          .map(
            (i) => CartItem(
              product: Product(
                id: i.productId,
                name: i.productName,
                barcode: i.barcode ?? '',
                unitPrice: i.unitPrice,
              ),
              quantity: i.quantity,
            ),
          )
          .toList(growable: false),
    );
  }

  @override
  void initState() {
    super.initState();
    _barcodeFocusNode.addListener(_handleFocusChange);
    _barcodeController.addListener(_handleBarcodeTextChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applyEditArgs(widget.editArgs);
    });
  }

  @override
  void didUpdateWidget(covariant _PosScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    // /sales route'u aynı branch içinde cached kaldığı için initState her zaman
    // çalışmıyor. extra ile yeni editArgs geldiğinde sepeti burada yükle.
    final oldSaleId = oldWidget.editArgs?.sale.id;
    final newSaleId = widget.editArgs?.sale.id;
    if (oldSaleId != newSaleId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _applyEditArgs(widget.editArgs);
      });
    }
  }

  void _handleBarcodeTextChanged() {
    final text = _barcodeController.text;
    if (text == _productSearchQuery) return;
    setState(() {
      _productSearchQuery = text;
    });
  }

  void _handleFocusChange() {
    if (_suppressBarcodeRefocus) return;

    if (!_barcodeFocusNode.hasFocus && !_isCameraMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_isCameraMode || _suppressBarcodeRefocus) return;

        // When a dialog/bottom-sheet is presented, this route is no longer current.
        // Avoid forcing focus while the current route is being covered/transitioning.
        final isCurrentRoute = ModalRoute.of(context)?.isCurrent ?? true;
        if (!isCurrentRoute) return;

        FocusScope.of(context).requestFocus(_barcodeFocusNode);
      });
    }
  }

  @override
  void dispose() {
    _barcodeFocusNode.removeListener(_handleFocusChange);
    _barcodeController.removeListener(_handleBarcodeTextChanged);
    _barcodeController.dispose();
    _barcodeFocusNode.dispose();
    super.dispose();
  }

  Future<bool> _confirmMissingPriceListAndAdd(catalog.Product product) async {
    final posController = ref.read(posControllerProvider.notifier);
    final missing = posController.hasActivePriceList() &&
        posController.isMissingPriceListPrice(product);

    if (!missing) {
      posController.addProduct(product);
      return true;
    }

    final shouldContinue = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Fiyat listesinde fiyat yok'),
          content: Text(
            '"${product.name}" ürünü aktif fiyat listesinde tanımlı değil.\n\nDevam etmek isterseniz ürün kartındaki satış fiyatı kullanılacak.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Devam Et'),
            ),
          ],
        );
      },
    );

    if (shouldContinue != true) {
      return false;
    }

    final fallback = posController.resolveFallbackUnitPrice(product);
    if (fallback <= 0) {
      if (!mounted) return false;
      await showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Satış yapılamıyor'),
            content: const Text(
              'Bu ürün için fiyat listesinde fiyat yok ve ürün kartında satış fiyatı (salePrice) tanımlı değil.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Tamam'),
              ),
            ],
          );
        },
      );
      await FlutterBeep.error();
      return false;
    }

    posController.addProductWithUnitPrice(
      product,
      unitPrice: fallback,
      missingPriceListPrice: true,
    );

    if (!mounted) return true;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Fiyat listesinde yok: ürün kartı satış fiyatı kullanıldı'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 3),
      ),
    );

    return true;
  }

  Future<void> _handleBarcode(
    String value, {
    bool fromCamera = false,
  }) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return;
    }

    // Camera scanners often emit the same barcode multiple times in quick
    // succession. Debounce to avoid double-adding.
    final now = DateTime.now();
    if (fromCamera) {
      if (_lastCameraBarcode == trimmed &&
          _lastCameraScanAt != null &&
          now.difference(_lastCameraScanAt!).inMilliseconds < 800) {
        return;
      }
      _lastCameraBarcode = trimmed;
      _lastCameraScanAt = now;
    } else {
      if (_lastManualBarcode == trimmed &&
          _lastManualScanAt != null &&
          now.difference(_lastManualScanAt!).inMilliseconds < 400) {
        return;
      }
      _lastManualBarcode = trimmed;
      _lastManualScanAt = now;
    }

    final companyId = ref.read(activeCompanyIdProvider);
    if (companyId == null) {
      await FlutterBeep.error();
      return;
    }

    final repo = ref.read(productsRepositoryProvider);
    final catalogProduct = await repo.findProductByBarcode(companyId, trimmed);

    if (!fromCamera) {
      _barcodeController.clear();
    }

    if (catalogProduct == null) {
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
      return;
    }

    final added = await _confirmMissingPriceListAndAdd(catalogProduct);
    if (added) {
      await FlutterBeep.success();
    }
  }

  void _onBarcodeSubmitted(String value) {
    _handleBarcode(value);
  }

  Future<void> _addProductToCart(catalog.Product product) async {
    final added = await _confirmMissingPriceListAndAdd(product);

    _barcodeController.clear();

    if (mounted && !_isCameraMode) {
      FocusScope.of(context).requestFocus(_barcodeFocusNode);
    }

    if (added) {
      await FlutterBeep.success();
    }
  }

  @override
  Widget build(BuildContext context) {
    final posState = ref.watch(posControllerProvider);
    final posController = ref.read(posControllerProvider.notifier);
    final productsAsync = ref.watch(quickSaleProductsProvider);

    final isEditing = widget.editArgs != null;

    return AppScaffold(
      title: isEditing ? 'Satışı Düzenle' : 'Hızlı Satış',
      body: Column(
        children: [
          if (!_isCameraMode) ...[
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
              child: productsAsync.when(
                data: (products) {
                  final suggestions = filterProductsForQuickSale(
                    products,
                    _productSearchQuery,
                  );

                  if (suggestions.isEmpty) {
                    return const SizedBox.shrink();
                  }

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    clipBehavior: Clip.antiAlias,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 260),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: suggestions.length,
                        separatorBuilder: (_, __) => const Divider(height: 0),
                        itemBuilder: (context, index) {
                          final p = suggestions[index];
                          final subtitleParts = <String>[];
                          if (p.brand.trim().isNotEmpty) {
                            subtitleParts.add(p.brand.trim());
                          }
                          if (p.tags.isNotEmpty) {
                            subtitleParts
                                .add("Etiket: ${p.tags.join(', ')}");
                          }
                          if (p.barcode.trim().isNotEmpty) {
                            subtitleParts.add('Barkod: ${p.barcode.trim()}');
                          }

                          return ListTile(
                            title: Text(
                              p.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: subtitleParts.isEmpty
                                ? null
                                : Text(
                                    subtitleParts.join(' • '),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                            onTap: () => _addProductToCart(p),
                          );
                        },
                      ),
                    ),
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: LinearProgressIndicator(),
                ),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ),
          ],
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
                    ownerId: 'quick_sale_camera',
                    enabled: _isCameraMode,
                    onBarcode: (value) async {
                      if (!_isCameraMode) return;
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
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: item.product.missingPriceListPrice
                                    ? Colors.red.shade700
                                    : null,
                              ),
                            ),
                            subtitle: Text(
                              '${item.quantity} x ${formatMoney(item.product.unitPrice)} = ${formatMoney(item.lineTotal)}',
                              style: item.product.missingPriceListPrice
                                  ? TextStyle(color: Colors.red.shade700)
                                  : null,
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
              final editingSale = widget.editArgs?.sale;
              if (editingSale != null) {
                final oldTotal = editingSale.total;
                final newTotal = posState.total;

                final ok = await posController.updateSale(
                  originalSale: editingSale,
                );

                if (!context.mounted) return;

                if (!ok) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Satış güncellenemedi'),
                      behavior: SnackBarBehavior.floating,
                      duration: Duration(seconds: 2),
                    ),
                  );
                  return;
                }

                if (editingSale.paymentMethod == 'credit' &&
                    editingSale.customerId != null) {
                  final delta = newTotal - oldTotal;
                  if (delta.abs() > 0.01) {
                    final companyId = ref.read(activeCompanyIdProvider);
                    if (companyId != null) {
                      final customerRepo = ref.read(customerRepositoryProvider);
                      final customer = await customerRepo.getCustomerById(
                        companyId,
                        editingSale.customerId!,
                      );
                      if (customer != null) {
                        final ledgerRepo =
                            ref.read(customerLedgerRepositoryProvider);
                        await ledgerRepo.addSaleEntry(
                          companyId: companyId,
                          customer: customer,
                          amount: delta,
                          note: 'POS satış düzeltme',
                          saleId: editingSale.id,
                        );
                      }
                    }
                  }
                }

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Satış güncellendi'),
                    behavior: SnackBarBehavior.floating,
                    duration: Duration(seconds: 2),
                  ),
                );

                return;
              }

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

    _suppressBarcodeRefocus = true;
    FocusScope.of(context).unfocus();

    final controller =
        TextEditingController(text: ref.read(holdSaleNameDraftProvider));
    void listener() {
      ref.read(holdSaleNameDraftProvider.notifier).state = controller.text;
    }

    controller.addListener(listener);

    final confirmed = await showDialog<String>(
      context: context,
      builder: (context) {
        return AnimatedPadding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
          ),
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          child: Center(
            child: Material(
              borderRadius: BorderRadius.circular(16),
              clipBehavior: Clip.antiAlias,
              color: Theme.of(context).dialogBackgroundColor,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Satışı Beklet',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: controller,
                      autofocus: true,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                        labelText: 'Satış adı (opsiyonel)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(null),
                          child: const Text('İptal'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () =>
                              Navigator.of(context).pop(controller.text),
                          child: const Text('Kaydet'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    controller.removeListener(listener);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.dispose();
    });

    _suppressBarcodeRefocus = false;
    if (mounted && !_isCameraMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _isCameraMode) return;
        FocusScope.of(context).requestFocus(_barcodeFocusNode);
      });
    }

    if (confirmed == null) return false;

    final companyId = ref.read(activeCompanyIdProvider);
    if (companyId == null) return false;

    try {
      await ref.read(heldSalesRepositoryProvider).holdSale(
            companyId: companyId,
            name: confirmed,
            items: posState.items,
            total: posState.total,
          );
    } on FirebaseException catch (e) {
      if (!context.mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Satış beklemeye alınamadı: ${e.message ?? e.code}'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
      return false;
    }

    ref.read(holdSaleNameDraftProvider.notifier).state = '';

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

  double _parseMoneyInput(String raw) {
    final cleaned = raw
        .trim()
        .replaceAll(' ', '')
        .replaceAll(',', '.')
        .replaceAll(RegExp(r'[^0-9\.]'), '');
    if (cleaned.isEmpty) return 0;
    return double.tryParse(cleaned) ?? 0;
  }

  Future<void> _showPaymentModal(
    BuildContext context,
    WidgetRef ref,
    PosState posState,
    PosController posController,
  ) async {
    if (!posState.hasItems) return;

    final hasInvalidPrice = posState.items.any((i) => i.product.unitPrice <= 0);
    if (hasInvalidPrice) {
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Satış yapılamıyor'),
            content: const Text(
              'Sepette fiyatı olmayan ürün var. Lütfen ürün fiyatlarını kontrol edin.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Tamam'),
              ),
            ],
          );
        },
      );
      return;
    }

    _suppressBarcodeRefocus = true;
    FocusScope.of(context).unfocus();

    ref.read(quickSalePaymentProvider.notifier).reset();

    final cashReceivedController = TextEditingController();
    double cashReceived = 0;

    bool isSplitPayment = false;

    bool splitCashEnabled = true;
    bool splitCardEnabled = false;
    bool splitCreditEnabled = false;

    final splitCardAmountController = TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return Consumer(
          builder: (context, ref, _) {
            final paymentState = ref.watch(quickSalePaymentProvider);
            final customersAsync = ref.watch(quickSaleCustomersProvider);

            return StatefulBuilder(
              builder: (context, setModalState) {
                final change = cashReceived - posState.total;

                final splitCardAmount =
                    _parseMoneyInput(splitCardAmountController.text);

                final splitRemainingAfterCard = posState.total -
                    (splitCardEnabled ? splitCardAmount : 0);

                final splitCashApplied = splitCashEnabled
                    ? splitRemainingAfterCard
                        .clamp(0, cashReceived)
                        .toDouble()
                    : 0.0;

                final splitCreditApplied = splitCreditEnabled
                    ? (splitRemainingAfterCard - splitCashApplied)
                        .clamp(0, posState.total)
                        .toDouble()
                    : 0.0;

                final splitTotal = (splitCardEnabled ? splitCardAmount : 0) +
                    splitCashApplied +
                    splitCreditApplied;

                final splitRemaining = posState.total - splitTotal;
                final splitCashChange = cashReceived - splitCashApplied;

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
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Ödeme Seç',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ),
                            Chip(
                              backgroundColor: Colors.blue.shade700,
                              label: Text(
                                'Sepet: ${formatMoney(posState.total)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ToggleButtons(
                          isSelected: [!isSplitPayment, isSplitPayment],
                          onPressed: (index) {
                            setModalState(() {
                              isSplitPayment = index == 1;

                              if (isSplitPayment) {
                                splitCashEnabled = true;
                                splitCardEnabled = false;
                                splitCreditEnabled = false;

                                splitCardAmountController.clear();
                                ref
                                    .read(quickSalePaymentProvider.notifier)
                                    .setCustomer(null);
                                ref
                                    .read(quickSaleCustomerQueryProvider.notifier)
                                    .state = '';

                                cashReceivedController.clear();
                                cashReceived = 0;
                              }
                            });
                          },
                          children: const [
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: Text('Tek Ödeme'),
                            ),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: Text('Parçalı Ödeme'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (!isSplitPayment) ...[
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
                          if (paymentState.type == QuickSalePaymentType.cash) ...[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  TextField(
                                    controller: cashReceivedController,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                    decoration: const InputDecoration(
                                      labelText: 'Müşteriden alınan',
                                      border: OutlineInputBorder(),
                                    ),
                                    onChanged: (value) {
                                      setModalState(() {
                                        cashReceived = _parseMoneyInput(value);
                                      });
                                    },
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    change >= 0
                                        ? 'Para üstü: ${formatMoney(change)}'
                                        : 'Eksik: ${formatMoney(-change)}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: change >= 0
                                              ? Colors.green.shade800
                                              : Colors.red.shade700,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
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

                                final draftQuery =
                                    ref.watch(quickSaleCustomerQueryProvider);

                                return Autocomplete<Customer>(
                                  initialValue:
                                      TextEditingValue(text: draftQuery),
                                  displayStringForOption: (c) => c.name,
                                  optionsBuilder: (value) {
                                    final query =
                                        value.text.trim().toLowerCase();
                                    if (query.isEmpty) {
                                      return const Iterable<Customer>.empty();
                                    }
                                    return customers.where((c) {
                                      final name = c.name.toLowerCase();
                                      final phone =
                                          (c.phone ?? '').toLowerCase();
                                      return name.contains(query) ||
                                          phone.contains(query);
                                    });
                                  },
                                  onSelected: (customer) {
                                    ref
                                        .read(quickSalePaymentProvider.notifier)
                                        .setCustomer(customer);
                                    ref
                                        .read(quickSaleCustomerQueryProvider
                                            .notifier)
                                        .state = customer.name;
                                  },
                                  fieldViewBuilder: (context, textController,
                                      focusNode, onSubmit) {
                                    return TextField(
                                      controller: textController,
                                      focusNode: focusNode,
                                      autofocus: true,
                                      textInputAction: TextInputAction.done,
                                      onChanged: (value) {
                                        ref
                                            .read(quickSaleCustomerQueryProvider
                                                .notifier)
                                            .state = value;
                                      },
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
                        ] else ...[
                          Text(
                            splitRemaining.abs() < 0.01
                                ? 'Toplam tamam'
                                : splitRemaining > 0
                                    ? 'Kalan: ${formatMoney(splitRemaining)}'
                                    : 'Fazla: ${formatMoney(-splitRemaining)}',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: splitRemaining.abs() < 0.01
                                      ? Colors.green.shade800
                                      : Colors.red.shade700,
                                ),
                          ),
                          const SizedBox(height: 8),
                          CheckboxListTile(
                            value: splitCashEnabled,
                            title: const Text('Nakit'),
                            onChanged: (value) {
                              setModalState(() {
                                splitCashEnabled = value ?? false;
                                if (!splitCashEnabled) {
                                  cashReceivedController.clear();
                                  cashReceived = 0;
                                }
                              });
                            },
                          ),
                          if (splitCashEnabled) ...[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  TextField(
                                    controller: cashReceivedController,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                    decoration: const InputDecoration(
                                      labelText: 'Müşteriden alınan',
                                      border: OutlineInputBorder(),
                                    ),
                                    onChanged: (value) {
                                      setModalState(() {
                                        cashReceived = _parseMoneyInput(value);
                                      });
                                    },
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    splitCashChange >= 0
                                        ? 'Para üstü: ${formatMoney(splitCashChange)}'
                                        : 'Eksik: ${formatMoney(-splitCashChange)}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: splitCashChange >= 0
                                              ? Colors.green.shade800
                                              : Colors.red.shade700,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          CheckboxListTile(
                            value: splitCardEnabled,
                            title: const Text('Kredi Kartı'),
                            onChanged: (value) {
                              setModalState(() {
                                splitCardEnabled = value ?? false;
                                if (!splitCardEnabled) {
                                  splitCardAmountController.clear();
                                }
                              });
                            },
                          ),
                          if (splitCardEnabled) ...[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                              child: TextField(
                                controller: splitCardAmountController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                decoration: const InputDecoration(
                                  labelText: 'Kart tutar',
                                  border: OutlineInputBorder(),
                                ),
                                onChanged: (_) => setModalState(() {}),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          CheckboxListTile(
                            value: splitCreditEnabled,
                            title: const Text('Veresiye'),
                            onChanged: (value) {
                              setModalState(() {
                                splitCreditEnabled = value ?? false;
                                if (!splitCreditEnabled) {
                                  ref
                                      .read(quickSalePaymentProvider.notifier)
                                      .setCustomer(null);
                                  ref
                                      .read(quickSaleCustomerQueryProvider.notifier)
                                      .state = '';
                                }
                              });
                            },
                          ),
                          if (splitCreditEnabled) ...[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                              child: Text(
                                'Kalan bakiye veresiye: ${formatMoney(splitCreditApplied)}',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                            const SizedBox(height: 8),
                            customersAsync.when(
                              data: (customers) {
                                if (customers.isEmpty) {
                                  return const Text(
                                      'Veresiye için önce müşteri ekleyin');
                                }

                                final draftQuery =
                                    ref.watch(quickSaleCustomerQueryProvider);

                                return Autocomplete<Customer>(
                                  initialValue:
                                      TextEditingValue(text: draftQuery),
                                  displayStringForOption: (c) => c.name,
                                  optionsBuilder: (value) {
                                    final query =
                                        value.text.trim().toLowerCase();
                                    if (query.isEmpty) {
                                      return const Iterable<Customer>.empty();
                                    }
                                    return customers.where((c) {
                                      final name = c.name.toLowerCase();
                                      final phone =
                                          (c.phone ?? '').toLowerCase();
                                      return name.contains(query) ||
                                          phone.contains(query);
                                    });
                                  },
                                  onSelected: (customer) {
                                    ref
                                        .read(quickSalePaymentProvider.notifier)
                                        .setCustomer(customer);
                                    ref
                                        .read(quickSaleCustomerQueryProvider
                                            .notifier)
                                        .state = customer.name;
                                  },
                                  fieldViewBuilder: (context, textController,
                                      focusNode, onSubmit) {
                                    return TextField(
                                      controller: textController,
                                      focusNode: focusNode,
                                      autofocus: true,
                                      textInputAction: TextInputAction.done,
                                      onChanged: (value) {
                                        ref
                                            .read(quickSaleCustomerQueryProvider
                                                .notifier)
                                            .state = value;
                                      },
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
                              isSplitPayment: isSplitPayment,
                              cashReceived: cashReceived,
                              splitCashEnabled: splitCashEnabled,
                              splitCardEnabled: splitCardEnabled,
                              splitCreditEnabled: splitCreditEnabled,
                              splitCardAmount:
                                  _parseMoneyInput(splitCardAmountController.text),
                            );
                            if (ok && context.mounted) {
                              Navigator.of(context).pop();
                            }
                          },
                          child: const Text('Satışı Tamamla'),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey.shade600,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
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
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      cashReceivedController.dispose();
      splitCardAmountController.dispose();
    });

    _suppressBarcodeRefocus = false;
    if (mounted && !_isCameraMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _isCameraMode) return;
        FocusScope.of(context).requestFocus(_barcodeFocusNode);
      });
    }
  }

  Future<bool> _completeSaleFromModal(
    BuildContext context,
    WidgetRef ref,
    PosState posState,
    PosController posController, {
    required bool isSplitPayment,
    required double cashReceived,
    required bool splitCashEnabled,
    required bool splitCardEnabled,
    required bool splitCreditEnabled,
    required double splitCardAmount,
  }) async {
    if (!posState.hasItems) return false;

    if (isSplitPayment) {
      final anySelected =
          splitCashEnabled || splitCardEnabled || splitCreditEnabled;
      if (!anySelected) {
        if (!context.mounted) return false;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('En az bir ödeme aracı seçin'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
        return false;
      }

      if (splitCardEnabled && splitCardAmount <= 0) {
        if (!context.mounted) return false;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kart tutarını girin'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
        return false;
      }

      if (splitCashEnabled && cashReceived <= 0) {
        if (!context.mounted) return false;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Müşteriden alınan tutarı girin'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
        return false;
      }

      final remainingAfterCard = posState.total -
          (splitCardEnabled ? splitCardAmount : 0);

      if (remainingAfterCard < -0.01) {
        if (!context.mounted) return false;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kart tutarı sepet tutarını geçemez'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
        return false;
      }

      final cashApplied = splitCashEnabled
          ? remainingAfterCard.clamp(0, cashReceived).toDouble()
          : 0.0;

      final creditApplied = splitCreditEnabled
          ? (remainingAfterCard - cashApplied)
              .clamp(0, posState.total)
              .toDouble()
          : 0.0;

      final splitTotal = (splitCardEnabled ? splitCardAmount : 0) +
          cashApplied +
          creditApplied;

      if (!splitCreditEnabled && (splitTotal - posState.total).abs() > 0.01) {
        if (!context.mounted) return false;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Parçalı ödeme toplamı sepet tutarına eşit olmalı'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
        return false;
      }

      if (!splitCreditEnabled && splitCashEnabled && cashReceived < remainingAfterCard) {
        if (!context.mounted) return false;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Müşteriden alınan nakit tutar yetersiz'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
        return false;
      }

      Customer? customer;
      if (splitCreditEnabled && creditApplied > 0) {
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

        final paymentState = ref.read(quickSalePaymentProvider);
        customer = paymentState.selectedCustomer;
        if (customer == null) {
          if (!context.mounted) return false;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Parçalı veresiye için müşteri seçin'),
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 2),
            ),
          );
          return false;
        }
      }

      final saleId = await posController.completeSale(
        customerId: customer?.id,
        paymentMethod: 'split',
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

      if (customer != null && creditApplied > 0) {
        final companyId = ref.read(activeCompanyIdProvider);
        if (companyId == null) return false;

        final ledgerRepo = ref.read(customerLedgerRepositoryProvider);
        await ledgerRepo.addSaleEntry(
          companyId: companyId,
          customer: customer,
          amount: creditApplied,
          note: 'POS parçalı satış (veresiye)',
          saleId: saleId,
        );

        if (!context.mounted) return false;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Satış tamamlandı (Parçalı)'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
      return true;
    }

    final paymentState = ref.read(quickSalePaymentProvider);

    if (paymentState.type == QuickSalePaymentType.cash) {
      if (cashReceived > 0 && cashReceived < posState.total) {
        if (!context.mounted) return false;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Müşteriden alınan tutar yetersiz'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
        return false;
      }

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

    final companyId = ref.read(activeCompanyIdProvider);
    if (companyId == null) return false;

    final ledgerRepo = ref.read(customerLedgerRepositoryProvider);
    await ledgerRepo.addSaleEntry(
      companyId: companyId,
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
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
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
