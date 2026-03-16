import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/scanner/barcode_scanner_view.dart';

import '../../../core/config/app_settings.dart';
import '../../../core/config/money_formatter.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../company/domain/active_company_provider.dart';
import '../../products/data/product_repository.dart';
import '../../products/domain/product.dart';
import '../data/stock_entry_repository.dart';
import '../data/supplier_repository.dart';
import '../domain/supplier.dart';

class _PurchaseLine {
  final Product product;
  final int quantity;
  final double unitCost;

  const _PurchaseLine({
    required this.product,
    required this.quantity,
    required this.unitCost,
  });

  double get lineTotal => quantity * unitCost;
}

class StockEntryPage extends ConsumerStatefulWidget {
  const StockEntryPage({super.key});

  @override
  ConsumerState<StockEntryPage> createState() => _StockEntryPageState();
}

class _StockEntryPageState extends ConsumerState<StockEntryPage> {
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _unitCostController = TextEditingController();
  final TextEditingController _marginController = TextEditingController();

  List<Supplier> _suppliers = const [];
  List<Product> _products = const [];
  Supplier? _selectedSupplier;
  Product? _selectedProduct;
  bool _isLoading = true;
  bool _isSaving = false;

  final List<_PurchaseLine> _lines = [];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final supplierRepo = SupplierRepository();
    final companyId = ref.read(activeCompanyIdProvider);
    if (companyId == null) {
      return;
    }

    final productRepo = ref.read(productsRepositoryProvider);
    final products = await productRepo.getAllProducts(companyId);

    if (!mounted) return;

    final settings = ref.read(appSettingsProvider);
    _marginController.text =
        settings.defaultMarginPercent.toStringAsFixed(0);

    setState(() {
      _suppliers = suppliers;
      _products = products;
      _selectedSupplier = suppliers.isNotEmpty ? suppliers.first : null;
      _selectedProduct = products.isNotEmpty ? products.first : null;
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _unitCostController.dispose();
    _marginController.dispose();
    super.dispose();
  }

  double get _subtotal {
    return _lines.fold(0, (sum, e) => sum + e.lineTotal);
  }

  Future<void> _addLine() async {
    if (_selectedProduct == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Önce bir ürün seçin'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final quantityText = _quantityController.text.trim();
    final unitCostText = _unitCostController.text.trim();

    final quantity = int.tryParse(quantityText);
    if (quantity == null || quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Geçerli bir miktar girin'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final unitCost =
        double.tryParse(unitCostText.replaceAll(',', '.')) ?? 0;
    if (unitCost <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Geçerli bir alış fiyatı girin'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _lines.add(
        _PurchaseLine(
          product: _selectedProduct!,
          quantity: quantity,
          unitCost: unitCost,
        ),
      );
      _quantityController.clear();
      _unitCostController.clear();
    });
  }

  Future<void> _openBarcodeScanner() async {
    var isPopping = false;

    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return SizedBox(
          height: 320,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'Barkodu kameraya hizalayın',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: BarcodeScannerView(
                    ownerId: 'stock_entry_scanner',
                    enabled: true,
                    onBarcode: (value) {
                      if (isPopping) return;
                      final trimmed = value.trim();
                      if (trimmed.isEmpty) return;

                      isPopping = true;
                      Navigator.of(context).pop(trimmed);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );

    if (!mounted || result == null || result.isEmpty) return;

    final companyId = ref.read(activeCompanyIdProvider);
    if (companyId == null) return;

    final repo = ref.read(productsRepositoryProvider);
    final product = await repo.findProductByBarcode(companyId, result);
    if (product == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Barkoda ait ürün bulunamadı'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _selectedProduct = product;
    });
  }

  Future<void> _save() async {
    if (_selectedSupplier == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tedarikçi seçmelisiniz'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('En az bir ürün eklemelisiniz'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final companyId = ref.read(activeCompanyIdProvider);
    if (companyId == null) {
      setState(() {
        _isSaving = false;
      });
      return;
    }

    final stockRepo = StockEntryRepository(ProductRepository());
    final marginText = _marginController.text.trim();
    final marginPercent =
        double.tryParse(marginText.replaceAll(',', '.')) ?? 0;

    for (final line in _lines) {
      await stockRepo.createStockEntry(
        companyId: companyId,
        supplierId: _selectedSupplier!.id,
        productId: line.product.id,
        quantity: line.quantity,
        unitCost: line.unitCost,
        marginPercent: marginPercent > 0 ? marginPercent : null,
      );
    }

    if (!mounted) return;

    setState(() {
      _isSaving = false;
      _lines.clear();
      _quantityController.clear();
      _unitCostController.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Stok girişi kaydedildi'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Stok Girişi',
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _suppliers.isEmpty || _products.isEmpty
              ? const Center(
                  child: Text(
                    'Stok girişi için önce tedarikçi ve ürün ekleyin',
                    textAlign: TextAlign.center,
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Tedarikçi:',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButton<Supplier>(
                              isExpanded: true,
                              value: _selectedSupplier,
                              items: _suppliers
                                  .map(
                                    (s) => DropdownMenuItem<Supplier>(
                                      value: s,
                                      child: Text(
                                        s.name,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedSupplier = value;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Text(
                            'Ürün:',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButton<Product>(
                              isExpanded: true,
                              value: _selectedProduct,
                              items: _products
                                  .map(
                                    (p) => DropdownMenuItem<Product>(
                                      value: p,
                                      child: Text(
                                        '${p.name} (${p.barcode})',
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedProduct = value;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: _openBarcodeScanner,
                            icon: const Icon(Icons.qr_code_scanner_outlined),
                            tooltip: 'Barkod Oku',
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _quantityController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(),
                              decoration: const InputDecoration(
                                labelText: 'Miktar',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _unitCostController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'Birim alış fiyatı',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: _addLine,
                            child: const Text('Ekle'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _marginController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'Varsayılan kâr marjı (%)',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(height: 0),
                      Expanded(
                        child: _lines.isEmpty
                            ? const Center(
                                child: Text(
                                  'Bu alış fişine ürün ekleyin',
                                  style: TextStyle(fontSize: 16),
                                ),
                              )
                            : ListView.builder(
                                itemCount: _lines.length,
                                itemBuilder: (context, index) {
                                  final line = _lines[index];
                                  return Dismissible(
                                    key: ValueKey(
                                        '${line.product.id}_$index'),
                                    direction: DismissDirection.endToStart,
                                    onDismissed: (_) {
                                      setState(() {
                                        _lines.removeAt(index);
                                      });
                                    },
                                    background: Container(
                                      alignment: Alignment.centerRight,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16),
                                      color: Colors.red.shade400,
                                      child: const Icon(
                                        Icons.delete_outline,
                                        color: Colors.white,
                                      ),
                                    ),
                                    child: ListTile(
                                      title: Text(
                                        line.product.name,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600),
                                      ),
                                      subtitle: Text(
                                        'Birim: ${formatMoney(line.unitCost)}  •  Adet: ${line.quantity}',
                                      ),
                                      trailing: Text(
                                        formatMoney(line.lineTotal),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color:
                              Theme.of(context).colorScheme.surfaceVariant,
                          border: Border(
                            top: BorderSide(
                              color: Theme.of(context).dividerColor,
                            ),
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Toplam Tutar',
                                    style:
                                        TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                ),
                                Text(
                                  '₺${_subtotal.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _isSaving ? null : _save,
                                child: Text(
                                  _isSaving
                                      ? 'Kaydediliyor...'
                                      : 'Stok Girişini Kaydet',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}