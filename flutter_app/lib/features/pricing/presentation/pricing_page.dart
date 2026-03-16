import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_settings.dart';
import '../../../core/config/money_formatter.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../company/domain/active_company_provider.dart';
import '../../products/data/product_repository.dart';
import '../../products/domain/product.dart';
import '../domain/price_resolver.dart';
import 'pricing_detail_page.dart';

class PricingItem {
  final Product product;
  final double salePrice;
  final double taxRate;
  final bool isManualPrice;

  const PricingItem({
    required this.product,
    required this.salePrice,
    required this.taxRate,
    required this.isManualPrice,
  });

  double get purchasePrice => product.lastPurchasePrice;
  String get productName => product.name;
}

final pricingProvider =
    FutureProvider.autoDispose<List<PricingItem>>((ref) async {
  final companyId = ref.watch(activeCompanyIdProvider);
  if (companyId == null) return const <PricingItem>[];

  final productRepo = ref.watch(productsRepositoryProvider);
  final products = await productRepo.getAllProducts(companyId);
  final settings = ref.watch(appSettingsProvider);

  // Pricing'i tek gerçek kaynak olacak şekilde hesapla:
  // - Manuel fiyatı (isManualPrice == true) her zaman kullan.
  // - Aksi halde sistem varsayılan kâr marjıyla otomatik hesapla.
  return products
      .map(
        (p) {
          final resolvedPrice = PriceResolver.resolveSellPrice(
            product: p,
            settings: settings,
          );

          final bool isManual = p.isManualPrice && p.salePrice > 0;

          return PricingItem(
            product: p,
            salePrice: resolvedPrice,
            taxRate: 20,
            isManualPrice: isManual,
          );
        },
      )
      .toList(growable: false);
});

class PricingPage extends ConsumerStatefulWidget {
  const PricingPage({super.key});

  @override
  ConsumerState<PricingPage> createState() => _PricingPageState();
}

class _PricingPageState extends ConsumerState<PricingPage> {
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
    _debounce = Timer(const Duration(milliseconds: 300), () {
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

  @override
  Widget build(BuildContext context) {
    final pricingAsync = ref.watch(pricingProvider);
    final settings = ref.watch(appSettingsProvider);
    final minChars = settings.searchFilterMinChars;

    return AppScaffold(
      title: 'Fiyat Listeleri',
      body: pricingAsync.when(
        data: (pricingModels) {
          if (pricingModels.isEmpty) {
            return const Center(
              child: Text('Henüz ürün bulunamadı'),
            );
          }

          final query = _searchQuery.trim().toLowerCase();
          final isFilterActive =
              query.isNotEmpty && query.length >= minChars;

          final filteredModels = isFilterActive
              ? pricingModels.where((model) {
                  final name = model.productName.toLowerCase();
                  final brand = model.product.brand.toLowerCase();
                  final barcode = model.product.barcode.toLowerCase();
                  final tags = model.product.tags
                      .map((t) => t.toLowerCase())
                      .join(' ');
                  return name.contains(query) ||
                      brand.contains(query) ||
                      barcode.contains(query) ||
                      tags.contains(query);
                }).toList()
              : pricingModels;

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: filteredModels.length + 1,
            separatorBuilder: (context, index) {
              if (index == 0) {
                return const SizedBox(height: 12);
              }
              return const SizedBox(height: 8);
            },
            itemBuilder: (context, index) {
              if (index == 0) {
                return TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Fiyat listesinde ara',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: _clearSearch,
                          )
                        : null,
                    border: const OutlineInputBorder(),
                  ),
                );
              }

              final model = filteredModels[index - 1];
              return Card(
                child: ListTile(
                  title: Text(model.productName),
                  subtitle: const Text('Detay için tıklayın'),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Alış: ${formatMoney(model.purchasePrice)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      Text(
                        'Satış: ${formatMoney(model.salePrice)}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PricingDetailPage(item: model),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(
          child: Text('Fiyat listeleri yüklenemedi'),
        ),
      ),
    );
  }
}