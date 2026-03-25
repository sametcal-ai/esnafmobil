import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_settings.dart';
import '../../../core/scanner/barcode_scanner_view.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../company/domain/active_company_provider.dart';
import '../../products/data/product_repository.dart';
import '../../products/domain/product.dart';
import '../../sales/quick_sale/product_search.dart';
import '../../suppliers/data/stock_entry_repository.dart';

class StockAdjustmentPage extends ConsumerStatefulWidget {
  const StockAdjustmentPage({super.key});

  @override
  ConsumerState<StockAdjustmentPage> createState() => _StockAdjustmentPageState();
}

class _StockAdjustmentPageState extends ConsumerState<StockAdjustmentPage> {
  final TextEditingController _queryController = TextEditingController();
  final FocusNode _queryFocusNode = FocusNode();

  String _query = '';
  bool _isCompleting = false;

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
                    ownerId: 'stock_adjustment_scanner',
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

    _queryController.text = result;
    if (mounted) {
      FocusScope.of(context).requestFocus(_queryFocusNode);
    }
  }

  final List<_StockAdjustmentItem> _items = <_StockAdjustmentItem>[];

  void _clearQuery() {
    _queryController.clear();
    if (mounted) {
      FocusScope.of(context).requestFocus(_queryFocusNode);
    }
  }

  @override
  void initState() {
    super.initState();
    _queryController.addListener(() {
      final text = _queryController.text;
      if (text == _query) return;
      setState(() {
        _query = text;
      });
    });
  }

  @override
  void dispose() {
    _queryController.dispose();
    _queryFocusNode.dispose();
    super.dispose();
  }

  Future<int?> _showNewStockModal({
    required String title,
    required int currentStock,
  }) async {
    final controller = TextEditingController();

    final confirmed = await showDialog<int>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Güncel stok: $currentStock'),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Yeni miktar',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () {
                final raw = controller.text.trim();
                final parsed = int.tryParse(raw);
                if (parsed == null || parsed < 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Yeni miktar numerik olmalı'),
                      behavior: SnackBarBehavior.floating,
                      duration: Duration(seconds: 2),
                    ),
                  );
                  return;
                }

                Navigator.of(context).pop(parsed);
              },
              child: const Text('Onayla'),
            ),
          ],
        );
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.dispose();
    });

    return confirmed;
  }

  Future<void> _addOrUpdate(Product product) async {
    final confirmed = await _showNewStockModal(
      title: product.name,
      currentStock: product.stockQuantity,
    );
    if (confirmed == null) return;

    setState(() {
      final existingIndex = _items.indexWhere((e) => e.productId == product.id);
      final next = _StockAdjustmentItem(
        productId: product.id,
        productName: product.name,
        currentStock: product.stockQuantity,
        newStock: confirmed,
        lastPurchasePrice: product.lastPurchasePrice,
      );

      if (existingIndex >= 0) {
        _items[existingIndex] = next;
      } else {
        _items.add(next);
      }
    });

    _queryController.clear();
    if (mounted) {
      FocusScope.of(context).requestFocus(_queryFocusNode);
    }
  }

  Future<void> _editItem(_StockAdjustmentItem item) async {
    final confirmed = await _showNewStockModal(
      title: item.productName,
      currentStock: item.currentStock,
    );
    if (confirmed == null) return;

    setState(() {
      final index = _items.indexWhere((e) => e.productId == item.productId);
      if (index < 0) return;
      _items[index] = item.copyWith(newStock: confirmed);
    });
  }

  Future<void> _complete() async {
    if (_items.isEmpty || _isCompleting) return;

    setState(() {
      _isCompleting = true;
    });

    final companyId = ref.read(activeCompanyIdProvider);
    if (companyId == null) {
      setState(() {
        _isCompleting = false;
      });
      return;
    }

    final stockRepo = ref.read(stockEntryRepositoryProvider);

    final items = List<_StockAdjustmentItem>.from(_items);

    try {
      for (final item in items) {
        if (item.currentStock == item.newStock) {
          continue;
        }

        if (item.currentStock > item.newStock) {
          final diff = item.currentStock - item.newStock;
          await stockRepo.createSystemOutgoingEntry(
            companyId: companyId,
            productId: item.productId,
            quantity: diff,
            supplierName: 'system',
          );
        } else {
          final diff = item.newStock - item.currentStock;
          await stockRepo.createSystemIncomingEntry(
            companyId: companyId,
            productId: item.productId,
            quantity: diff,
            unitCost: item.lastPurchasePrice,
            supplierName: 'system',
          );
        }
      }

      if (!mounted) return;

      setState(() {
        _items.clear();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isCompleting = false;
        });
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Stok düzenleme işlemi tamamlandı'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final companyId = ref.watch(activeCompanyIdProvider);
    final settings = ref.watch(appSettingsProvider);

    final productsStream = companyId == null
        ? const Stream<List<Product>>.empty()
        : ref.watch(productsRepositoryProvider).watchProducts(companyId);

    return AppScaffold(
      title: 'Stok Düzenleme',
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _queryController,
              focusNode: _queryFocusNode,
              autofocus: true,
              textInputAction: TextInputAction.search,
              keyboardType: TextInputType.text,
              decoration: InputDecoration(
                labelText: 'Barkod okut / yaz',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: _openBarcodeScanner,
                      icon: const Icon(Icons.qr_code_scanner_outlined),
                      tooltip: 'Barkod Oku',
                    ),
                    if (_query.trim().isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: _clearQuery,
                        tooltip: 'Temizle',
                      ),
                  ],
                ),
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: StreamBuilder<List<Product>>(
              stream: productsStream,
              builder: (context, snapshot) {
                final products = snapshot.data ?? const <Product>[];
                final query = _query.trim();

                final canFilter = query.length >= settings.searchFilterMinChars;
                final suggestions = canFilter
                    ? filterProductsForQuickSale(products, query, limit: 10)
                    : const <Product>[];

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
                          subtitleParts.add("Etiket: ${p.tags.join(', ')}");
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
                          onTap: () => _addOrUpdate(p),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
          const Divider(height: 0),
          Expanded(
            child: _items.isEmpty
                ? const Center(
                    child: Text(
                      'Düzenlenecek ürün ekleyin',
                      style: TextStyle(fontSize: 16),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      return Dismissible(
                        key: ValueKey(item.productId),
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
                        onDismissed: (_) {
                          setState(() {
                            _items.removeAt(index);
                          });
                        },
                        child: Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: ListTile(
                            title: Text(
                              item.productName,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              'Güncel: ${item.currentStock}   Yeni: ${item.newStock}',
                            ),
                            trailing: const Icon(Icons.edit_outlined),
                            onTap: () => _editItem(item),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: AppButton(
              label: _isCompleting ? 'İşleniyor...' : 'İşlemi Tamamla',
              isPrimary: true,
              isExpanded: true,
              onPressed: _items.isEmpty || _isCompleting ? null : _complete,
            ),
          ),
        ],
      ),
    );
  }
}

class _StockAdjustmentItem {
  final String productId;
  final String productName;
  final int currentStock;
  final int newStock;
  final double lastPurchasePrice;

  const _StockAdjustmentItem({
    required this.productId,
    required this.productName,
    required this.currentStock,
    required this.newStock,
    required this.lastPurchasePrice,
  });

  _StockAdjustmentItem copyWith({
    String? productId,
    String? productName,
    int? currentStock,
    int? newStock,
    double? lastPurchasePrice,
  }) {
    return _StockAdjustmentItem(
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      currentStock: currentStock ?? this.currentStock,
      newStock: newStock ?? this.newStock,
      lastPurchasePrice: lastPurchasePrice ?? this.lastPurchasePrice,
    );
  }
}
