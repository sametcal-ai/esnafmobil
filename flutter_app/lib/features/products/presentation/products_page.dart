import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/scanner/barcode_scanner_view.dart';

import '../../../core/config/app_settings.dart';
import '../../../core/config/money_formatter.dart';
import '../../../core/firestore/firestore_refs.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../services/jojapi_external_search_service.dart';
import '../../auth/domain/user.dart';
import '../../company/domain/active_company_provider.dart';
import '../../company/domain/company_memberships_provider.dart';
import '../../auth/domain/current_user_provider.dart' show currentUserProvider;
import '../../pricing/domain/price_list_providers.dart';
import '../../pricing/domain/price_resolver.dart';
import '../../pricing/data/price_list_repository.dart';
import '../../suppliers/data/stock_entry_repository.dart';
import '../data/product_repository.dart';
import '../domain/product.dart';

class ProductsFeed {
  final List<Product> products;
  final bool isFromCache;
  final bool hasPendingWrites;

  const ProductsFeed({
    required this.products,
    required this.isFromCache,
    required this.hasPendingWrites,
  });
}

final productsProvider = StreamProvider.autoDispose<ProductsFeed>((ref) {
  final companyId = ref.watch(activeCompanyIdProvider);
  if (companyId == null) {
    return Stream.value(
      const ProductsFeed(
        products: <Product>[],
        isFromCache: false,
        hasPendingWrites: false,
      ),
    );
  }

  final refs = ref.watch(firestoreRefsProvider);

  return refs.productsRef(companyId).snapshots().map((snap) {
    final products = snap.docs
        .map((d) => d.data())
        .where((p) => !p.meta.isDeleted)
        .toList(growable: false);

    final hasPendingWrites =
        snap.metadata.hasPendingWrites || snap.docs.any((d) => d.metadata.hasPendingWrites);

    return ProductsFeed(
      products: products,
      isFromCache: snap.metadata.isFromCache,
      hasPendingWrites: hasPendingWrites,
    );
  });
});

class ProductsPage extends ConsumerStatefulWidget {
  const ProductsPage({super.key});

  @override
  ConsumerState<ProductsPage> createState() => _ProductsPageState();
}

class _SearchBarHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double minHeight;
  final double maxHeight;
  final Widget child;

  _SearchBarHeaderDelegate({
    required this.minHeight,
    required this.maxHeight,
    required this.child,
  });

  @override
  double get minExtent => minHeight;

  @override
  double get maxExtent => maxHeight;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant _SearchBarHeaderDelegate oldDelegate) {
    return minHeight != oldDelegate.minHeight ||
        maxHeight != oldDelegate.maxHeight ||
        child != oldDelegate.child;
  }
}

class _ProductsPageState extends ConsumerState<ProductsPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      setState(() {
        _searchQuery = value;
      });
    });
  }

  void _clearSearch() {
    _debounce?.cancel();
    _searchController.clear();
    setState(() {
      _searchQuery = '';
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
                    ownerId: 'products_page_scanner',
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

    _searchController.text = result;
    setState(() {
      _searchQuery = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);
    final currentUser = ref.watch(currentUserProvider);
    final isAdmin = currentUser != null && currentUser.role == UserRole.admin;
    final settings = ref.watch(appSettingsProvider);
    final minChars = settings.searchFilterMinChars;

    final activeItemMap = ref.watch(activePriceListItemMapProvider);

    return AppScaffold(
      title: 'Products',
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: () async {
                await showDialog<bool>(
                  context: context,
                  builder: (context) => const EditProductDialog(),
                );
              },
              icon: const Icon(Icons.add_box_outlined),
              label: const Text('Ürün Ekle'),
            )
          : null,
      body: productsAsync.when(
        data: (feed) {
          final products = feed.products;

          if (products.isEmpty) {
            return const Center(
              child: Text('Henüz ürün yok'),
            );
          }

          final query = _searchQuery.trim().toLowerCase();
          final isFilterActive =
              query.isNotEmpty && query.length >= minChars;

          final filteredProducts = isFilterActive
              ? products.where((product) {
                  final name = product.name.toLowerCase();
                  final brand = product.brand.toLowerCase();
                  final barcode = product.barcode.toLowerCase();
                  final tags = product.tags
                      .map((t) => t.toLowerCase())
                      .join(' ');

                  return name.contains(query) ||
                      brand.contains(query) ||
                      barcode.contains(query) ||
                      tags.contains(query);
                }).toList()
              : products;

          return CustomScrollView(
            slivers: [
              if (feed.isFromCache || feed.hasPendingWrites)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Row(
                      children: [
                        if (feed.isFromCache)
                          const Text(
                            'Offline cache',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        if (feed.isFromCache && feed.hasPendingWrites)
                          const SizedBox(width: 8),
                        if (feed.hasPendingWrites)
                          const Text(
                            'Senkronize ediliyor…',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blueGrey,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              SliverPadding(
                padding: const EdgeInsets.only(
                  left: 16,
                  right: 16,
                  bottom: 80,
                ),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      if (index.isOdd) {
                        return const SizedBox(height: 8);
                      }

                      final product = filteredProducts[index ~/ 2];
                      final brandText =
                          product.brand.isEmpty ? '-' : product.brand;
                      final tagsText =
                          product.tags.isEmpty ? '-' : product.tags.join(', ');

                      final priceListItem = activeItemMap[product.id];

                      final resolvedSalePrice = priceListItem != null
                          ? priceListItem.salePrice
                          : PriceResolver.resolveSellPrice(
                              product: product,
                              settings: settings,
                            );

                      final salePriceText = resolvedSalePrice > 0
                          ? formatMoney(resolvedSalePrice)
                          : '-';

                      final resolvedPurchasePrice =
                          priceListItem != null ? priceListItem.purchasePrice : product.lastPurchasePrice;

                      final purchasePriceText = resolvedPurchasePrice > 0
                          ? formatMoney(resolvedPurchasePrice)
                          : '-';

                      return Card(
                        child: InkWell(
                          onTap: isAdmin
                              ? () {
                                  context.push('/products/${product.id}');
                                }
                              : null,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            child: IntrinsicHeight(
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          product.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Marka: $brandText',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Etiket: $tagsText',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          'Son alış fiyatı: $purchasePriceText',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Satış fiyatı: $salePriceText',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          'Stok: ${product.stockQuantity}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium,
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isAdmin) ...[
                                    const SizedBox(width: 8),
                                    Center(
                                      child: IconButton(
                                        icon: const Icon(
                                          Icons.delete_outline,
                                        ),
                                        onPressed: () async {
                                          final companyId = ref.read(activeCompanyIdProvider);
                                          if (companyId == null) return;

                                          final repo = ref.read(productsRepositoryProvider);
                                          await repo.deleteProduct(companyId, product.id);
                                        },
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                    childCount: filteredProducts.isEmpty
                        ? 0
                        : (filteredProducts.length * 2) - 1,
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(
          child: Text('Ürünler yüklenemedi'),
        ),
      ),
    );
  }
}

class EditProductDialog extends ConsumerStatefulWidget {
  final Product? existing;

  const EditProductDialog({
    super.key,
    this.existing,
  });

  @override
  ConsumerState<EditProductDialog> createState() => _EditProductDialogState();
}

class _EditProductDialogState extends ConsumerState<EditProductDialog> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _brandController = TextEditingController();
  final TextEditingController _barcodeController = TextEditingController();
  final TextEditingController _tagsController = TextEditingController();
  final TextEditingController _stockController = TextEditingController();
  final TextEditingController _purchasePriceController =
      TextEditingController();
  final TextEditingController _salePriceController = TextEditingController();
  final TextEditingController _marginController = TextEditingController();

  final JojapiExternalSearchService _externalSearchService =
      JojapiExternalSearchService();
  bool _isSaving = false;
  bool _isLookingUp = false;
  String? _lookupImageUrl;

  double? _externalPrice;
  double? _externalTax;
  double? _externalTaxRate;
  double? _externalTotal;
  DateTime? _externalDate;

  String? _lastLookupBarcode;
  String? _lastLookupName;
  String? _lastLookupBrand;
  String? _lastLookupCategory;
  String? _lastLookupImageUrl;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _nameController.text = existing.name;
      _brandController.text = existing.brand;
      _barcodeController.text = existing.barcode;
      _tagsController.text = existing.tags.join(', ');
      _stockController.text = existing.stockQuantity.toString();
      if (existing.lastPurchasePrice > 0) {
        _purchasePriceController.text =
            existing.lastPurchasePrice.toStringAsFixed(2);
      }
      if (existing.salePrice > 0) {
        _salePriceController.text = existing.salePrice.toStringAsFixed(2);
      }
      if (existing.marginPercent > 0) {
        _marginController.text = existing.marginPercent.toStringAsFixed(0);
      }
      _lookupImageUrl = existing.imageUrl;

      _externalPrice = existing.externalPrice;
      _externalTax = existing.externalTax;
      _externalTaxRate = existing.externalTaxRate;
      _externalTotal = existing.externalTotal;
      _externalDate = existing.externalDate;
    } else {
      final settings = ref.read(appSettingsProvider);
      _marginController.text =
          settings.defaultMarginPercent.toStringAsFixed(0);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _brandController.dispose();
    _barcodeController.dispose();
    _tagsController.dispose();
    _stockController.dispose();
    _purchasePriceController.dispose();
    _salePriceController.dispose();
    _marginController.dispose();
    super.dispose();
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
                    ownerId: 'edit_product_scanner',
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

    _barcodeController.text = result;
    await _lookupAndFillFromBarcode(result);
  }

  Future<void> _lookupAndFillFromBarcode(String barcode) async {
    final trimmed = barcode.trim();
    if (trimmed.isEmpty) return;

    if (_lastLookupBarcode == trimmed &&
        (_lastLookupName != null ||
            _lastLookupBrand != null ||
            _lastLookupCategory != null ||
            _lastLookupImageUrl != null)) {
      _applyLookupResult(
        name: _lastLookupName,
        brand: _lastLookupBrand,
        category: _lastLookupCategory,
        imageUrl: _lastLookupImageUrl,
      );
      return;
    }

    setState(() {
      _isLookingUp = true;
      _lookupImageUrl = null;
    });

    try {
      final externalProduct =
          await _externalSearchService.searchProductByBarcode(trimmed);

      if (!mounted) return;

      setState(() {
        _isLookingUp = false;
      });

      _lastLookupBarcode = trimmed;
      _lastLookupName = externalProduct.name;
      _lastLookupBrand = externalProduct.brand;
      _lastLookupCategory = externalProduct.category;
      _lastLookupImageUrl = externalProduct.imageUrl;

      _externalPrice = externalProduct.price;
      _externalTax = externalProduct.tax;
      _externalTaxRate = externalProduct.taxRate;
      _externalTotal = externalProduct.total;
      _externalDate = DateTime.now();

      _applyLookupResult(
        name: externalProduct.name,
        brand: externalProduct.brand,
        category: externalProduct.category,
        imageUrl: externalProduct.imageUrl,
      );
    } on ExternalSearchException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLookingUp = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLookingUp = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ürün bilgileri alınırken bir hata oluştu.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _applyLookupResult({
    String? name,
    String? brand,
    String? category,
    String? imageUrl,
  }) {
    if ((name ?? '').isNotEmpty && _nameController.text.trim().isEmpty) {
      _nameController.text = name!;
    }
    if ((brand ?? '').isNotEmpty && _brandController.text.trim().isEmpty) {
      _brandController.text = brand!;
    }
    if ((category ?? '').isNotEmpty && _tagsController.text.trim().isEmpty) {
      _tagsController.text = category!;
    }

    setState(() {
      _lookupImageUrl = imageUrl;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Ürün bilgileri otomatik dolduruldu'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _save() async {
    final isEdit = widget.existing != null;

    final name = _nameController.text.trim();
    final brand = _brandController.text.trim();
    final barcode = _barcodeController.text.trim();
    final tagsText = _tagsController.text.trim();
    final stockText = _stockController.text.trim();
    final purchasePriceText = _purchasePriceController.text.trim();
    final salePriceText = _salePriceController.text.trim();
    final marginText = _marginController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ürün adı boş olamaz'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    int stockQuantity = 0;
    if (stockText.isNotEmpty) {
      final parsed = int.tryParse(stockText);
      if (parsed == null || parsed < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Geçerli bir stok miktarı girin'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      stockQuantity = parsed;
    }

    double purchasePrice = 0;
    if (!isEdit && purchasePriceText.isNotEmpty) {
      final parsed =
          double.tryParse(purchasePriceText.replaceAll(',', '.'));
      if (parsed == null || parsed < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Geçerli bir alış fiyatı girin'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      purchasePrice = parsed;
    }

    double marginPercent = 0;
    if (marginText.isNotEmpty) {
      final parsed = double.tryParse(marginText.replaceAll(',', '.'));
      if (parsed == null || parsed < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Geçerli bir kâr marjı girin'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      marginPercent = parsed;
    }

    double salePrice = 0;
    if (!isEdit && salePriceText.isNotEmpty) {
      final parsed = double.tryParse(salePriceText.replaceAll(',', '.'));
      if (parsed == null || parsed < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Geçerli bir satış fiyatı girin'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      salePrice = parsed;
    }

    final settings = ref.read(appSettingsProvider);

    final bool isManualPriceInput = !isEdit && salePriceText.isNotEmpty;

    if (!isEdit) {
      if (!isManualPriceInput && purchasePrice > 0) {
        final autoMargin = settings.defaultMarginPercent;
        if (autoMargin > 0) {
          marginPercent = autoMargin;
          salePrice = purchasePrice * (1 + autoMargin / 100);
        } else {
          salePrice = purchasePrice;
        }
      } else {
        if (purchasePrice > 0 && salePrice > 0 && marginPercent == 0) {
          marginPercent = ((salePrice / purchasePrice) - 1) * 100;
        }
      }
    }

    setState(() {
      _isSaving = true;
    });

    final tags = tagsText.isEmpty
        ? <String>[]
        : tagsText
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();

    final companyId = ref.read(activeCompanyIdProvider);
    if (companyId == null) {
      setState(() {
        _isSaving = false;
      });
      return;
    }

    final repo = ref.read(productsRepositoryProvider);

    if (barcode.isNotEmpty) {
      final existingByBarcode = await repo.findProductByBarcode(companyId, barcode);
      if (widget.existing == null) {
        if (existingByBarcode != null) {
          setState(() {
            _isSaving = false;
          });
          await showDialog<void>(
            context: context,
            builder: (context) {
              return AlertDialog(
                title: const Text('Barkod zaten kayıtlı'),
                content: const Text(
                  'Bu barkod ile kayıtlı bir ürün zaten var. '
                  'İsterseniz mevcut ürünü düzenleyebilirsiniz.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('İptal'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: const Text('Tamam'),
                  ),
                ],
              );
            },
          );
          return;
        }
      } else {
        if (existingByBarcode != null &&
            existingByBarcode.id != widget.existing!.id) {
          setState(() {
            _isSaving = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Bu barkod başka bir ürüne ait'),
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }
      }
    }

    final bool isManualPrice = !isEdit && salePriceText.isNotEmpty;

    if (widget.existing == null) {
      final product = await repo.createProduct(
        companyId: companyId,
        name: name,
        brand: brand,
        barcode: barcode,
        imageUrl: _lookupImageUrl,
        tags: tags,
        stockQuantity: 0,
        lastPurchasePrice: purchasePrice,
        salePrice: salePrice,
        marginPercent: marginPercent,
        isManualPrice: isManualPrice,
        externalPrice: _externalPrice,
        externalTax: _externalTax,
        externalTaxRate: _externalTaxRate,
        externalTotal: _externalTotal,
        externalDate: _externalDate,
      );

      final priceListRepo = ref.read(priceListRepositoryProvider);
      await priceListRepo.ensureProductInActiveList(
        companyId: companyId,
        product: product,
      );

      if (stockQuantity > 0) {
        final stockRepo = ref.read(stockEntryRepositoryProvider);
        await stockRepo.createSystemIncomingEntry(
          companyId: companyId,
          productId: product.id,
          quantity: stockQuantity,
          unitCost: purchasePrice,
        );
      }
    } else {
      final updated = widget.existing!.copyWith(
        name: name,
        brand: brand,
        barcode: barcode,
        imageUrl: _lookupImageUrl ?? widget.existing!.imageUrl,
        tags: tags,
        marginPercent: marginPercent,
        externalPrice: _externalPrice ?? widget.existing!.externalPrice,
        externalTax: _externalTax ?? widget.existing!.externalTax,
        externalTaxRate:
            _externalTaxRate ?? widget.existing!.externalTaxRate,
        externalTotal: _externalTotal ?? widget.existing!.externalTotal,
        externalDate: _externalDate ?? widget.existing!.externalDate,
      );
      await repo.updateProduct(companyId, updated);
    }

    if (!mounted) return;
    setState(() {
      _isSaving = false;
    });
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;

    return AlertDialog(
      title: Text(isEdit ? 'Ürünü Düzenle' : 'Yeni Ürün'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Ürün adı',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _brandController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Marka',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _barcodeController,
                    textInputAction: TextInputAction.next,
                    onSubmitted: (value) => _lookupAndFillFromBarcode(value),
                    decoration: const InputDecoration(
                      labelText: 'Barkod',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _isSaving ? null : _openBarcodeScanner,
                  icon: const Icon(Icons.qr_code_scanner_outlined),
                  tooltip: 'Barkod Oku',
                ),
              ],
            ),
            if (_isLookingUp) ...[
              const SizedBox(height: 8),
              const Align(
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 8),
                    Text('Ürün bilgileri sorgulanıyor...'),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _tagsController,
              decoration: const InputDecoration(
                labelText:
                    'Etiketler (virgülle ayırın, örn: kola, soğuk içecek)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _stockController,
              enabled: !isEdit,
              keyboardType:
                  const TextInputType.numberWithOptions(signed: false),
              decoration: InputDecoration(
                labelText: 'Stok miktarı',
                helperText: isEdit
                    ? 'Stok; alış/satış hareketlerinden hesaplanır, buradan değiştirilemez.'
                    : null,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _purchasePriceController,
              enabled: !isEdit,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Son alış fiyatı',
                helperText: isEdit
                    ? 'Fiyatlar aktif fiyat listesinden güncellenir, buradan değiştirilemez.'
                    : null,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _marginController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Kâr marjı (%)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _salePriceController,
                    enabled: !isEdit,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Satış fiyatı',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            if (_externalTotal != null) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dış fiyat (KDV dahil): ${formatMoney(_externalTotal!)}',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    if (_externalDate != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Son veri çekme tarihi: ${_externalDate!.toLocal()}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
            if (_lookupImageUrl != null) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ürün görseli (dış arama):',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 120,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          _lookupImageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const SizedBox(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
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
