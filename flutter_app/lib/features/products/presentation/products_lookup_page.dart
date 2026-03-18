import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_settings.dart';
import '../../../core/config/money_formatter.dart';
import '../../../core/scanner/barcode_scanner_view.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../pricing/domain/price_list_item.dart';
import '../../pricing/domain/price_list_providers.dart';
import '../../pricing/domain/price_resolver.dart';
import '../domain/product.dart';
import 'products_page.dart';

class ProductsLookupPage extends ConsumerStatefulWidget {
  const ProductsLookupPage({super.key});

  @override
  ConsumerState<ProductsLookupPage> createState() => _ProductsLookupPageState();
}

class _ProductsLookupPageState extends ConsumerState<ProductsLookupPage> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  String _searchQuery = '';

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
                    ownerId: 'products_lookup_scanner',
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
    final settings = ref.watch(appSettingsProvider);
    final minChars = settings.searchFilterMinChars;

    final activeItemMap = ref.watch(activePriceListItemMapProvider);

    return AppScaffold(
      title: 'Ürünler',
      body: productsAsync.when(
        data: (feed) {
          final products = feed.products;
          final query = _searchQuery.trim().toLowerCase();
          final isFilterActive = query.isNotEmpty && query.length >= minChars;

          String normalizeForSearch(String value) {
            return value
                .toLowerCase()
                // "İ" -> "i\u0307" (i + combining dot). Remove the combining dot.
                .replaceAll('\u0307', '')
                // Treat Turkish dotless i as i to make search more forgiving.
                .replaceAll('ı', 'i');
          }

          final normalizedQuery = normalizeForSearch(query);

          final filteredProducts = isFilterActive
              ? products.where((product) {
                  final name = normalizeForSearch(product.name);
                  final brand = normalizeForSearch(product.brand);
                  final barcode = normalizeForSearch(product.barcode);
                  final tags = product.tags.map(normalizeForSearch).join(' ');

                  return name.contains(normalizedQuery) ||
                      brand.contains(normalizedQuery) ||
                      barcode.contains(normalizedQuery) ||
                      tags.contains(normalizedQuery);
                }).toList()
              : products;

          return Padding(
            padding: const EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: 80,
            ),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Ürünlerde ara...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: _openBarcodeScanner,
                          icon: const Icon(Icons.qr_code_scanner_outlined),
                          tooltip: 'Barkod Oku',
                        ),
                        if (_searchQuery.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: _clearSearch,
                          ),
                      ],
                    ),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.separated(
                    itemCount: filteredProducts.length,
                    separatorBuilder: (context, index) {
                      return const SizedBox(height: 10);
                    },
                    itemBuilder: (context, index) {
                      final product = filteredProducts[index];
                      return _ProductLookupCard(
                        product: product,
                        settings: settings,
                        activeItemMap: activeItemMap,
                      );
                    },
                  ),
                ),
              ],
            ),
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

class _ProductLookupCard extends StatelessWidget {
  final Product product;
  final AppSettings settings;
  final Map<String, PriceListItem> activeItemMap;

  const _ProductLookupCard({
    required this.product,
    required this.settings,
    required this.activeItemMap,
  });

  @override
  Widget build(BuildContext context) {
    final brandText = product.brand.isEmpty ? '-' : product.brand;
    final tagsText = product.tags.isEmpty ? '-' : product.tags.join(', ');

    final priceListItem = activeItemMap[product.id];

    final resolvedSalePrice = priceListItem != null
        ? priceListItem.salePrice
        : PriceResolver.resolveSellPrice(
            product: product,
            settings: settings,
          );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Marka: $brandText',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.grey,
                      ),
                    ),
                    Text(
                      'Etiket: $tagsText',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 120,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 2,
                      child: Center(
                        child: Text(
                          'Stok: ${product.stockQuantity}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Center(
                        child: resolvedSalePrice > 0
                            ? Text(
                                formatMoney(resolvedSalePrice),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: Colors.green.shade700,
                                  fontSize: 16,
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
