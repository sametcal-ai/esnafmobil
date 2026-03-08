import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_settings.dart';
import '../../../core/config/money_formatter.dart';
import '../../../core/scanner/barcode_scanner_view.dart';
import '../../../core/widgets/app_scaffold.dart';
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

    return AppScaffold(
      title: 'Ürünler',
      body: productsAsync.when(
        data: (products) {
          final query = _searchQuery.trim().toLowerCase();
          final isFilterActive = query.isNotEmpty && query.length >= minChars;

          final filteredProducts = isFilterActive
              ? products.where((product) {
                  final name = product.name.toLowerCase();
                  final brand = product.brand.toLowerCase();
                  final barcode = product.barcode.toLowerCase();
                  final tags =
                      product.tags.map((t) => t.toLowerCase()).join(' ');

                  return name.contains(query) ||
                      brand.contains(query) ||
                      barcode.contains(query) ||
                      tags.contains(query);
                }).toList()
              : products;

          return ListView.separated(
            padding: const EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: 80,
            ),
            itemCount: filteredProducts.length + 1,
            separatorBuilder: (context, index) {
              if (index == 0) {
                return const SizedBox(height: 12);
              }
              return const SizedBox(height: 10);
            },
            itemBuilder: (context, index) {
              if (index == 0) {
                return TextField(
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
                );
              }

              final product = filteredProducts[index - 1];
              return _ProductLookupCard(
                product: product,
                settings: settings,
              );
            },
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

  const _ProductLookupCard({
    required this.product,
    required this.settings,
  });

  @override
  Widget build(BuildContext context) {
    final tagsText = product.tags.isEmpty ? '' : product.tags.join(', ');

    final subtitleParts = <String>[];
    if (product.brand.isNotEmpty) {
      subtitleParts.add(product.brand);
    }
    if (tagsText.isNotEmpty) {
      subtitleParts.add(tagsText);
    }

    final resolvedSalePrice = PriceResolver.resolveSellPrice(
      product: product,
      settings: settings,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (subtitleParts.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          subtitleParts.join(' • '),
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 110,
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
              ],
            ),
            if (resolvedSalePrice > 0)
              Positioned(
                right: 0,
                bottom: 0,
                child: Text(
                  formatMoney(resolvedSalePrice),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Colors.green.shade700,
                    fontSize: 16,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
