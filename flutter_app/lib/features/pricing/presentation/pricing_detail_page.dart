import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_settings.dart';
import '../../../core/config/money_formatter.dart';
import '../../../core/firestore/firestore_refs.dart';
import '../../../core/firestore/models/company_member.dart';
import '../../../core/scanner/barcode_scanner_view.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../auth/domain/current_user_provider.dart' show currentUserProvider;
import '../../auth/domain/user.dart';
import '../../company/domain/active_company_provider.dart';
import '../../products/data/product_repository.dart';
import '../../products/domain/product.dart';
import '../data/price_list_repository.dart';
import '../domain/price_list.dart';
import '../domain/price_list_item.dart';
import '../domain/price_list_providers.dart';

final _allProductsProvider = FutureProvider.family.autoDispose<List<Product>, String>((ref, companyId) {
  final repo = ref.watch(productsRepositoryProvider);
  return repo.getAllProducts(companyId);
});

class _MemberKey {
  final String companyId;
  final String uid;

  const _MemberKey({
    required this.companyId,
    required this.uid,
  });

  @override
  bool operator ==(Object other) {
    return other is _MemberKey && other.companyId == companyId && other.uid == uid;
  }

  @override
  int get hashCode => Object.hash(companyId, uid);
}

final _companyMemberProvider = FutureProvider.family.autoDispose<CompanyMember?, _MemberKey>((ref, key) async {
  if (key.uid.trim().isEmpty) return null;

  final refs = ref.watch(firestoreRefsProvider);
  final snap = await refs.member(key.companyId, key.uid).get();
  return snap.data();
});

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

class PricingDetailPage extends ConsumerWidget {
  final PriceList priceList;

  const PricingDetailPage({super.key, required this.priceList});

  String _dateText(DateTime dt) {
    final d = dt.toLocal();
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    final year = d.year.toString();
    return '$day.$month.$year';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final companyId = ref.watch(activeCompanyIdProvider);
    final lists = ref.watch(priceListsProvider).asData?.value;
    PriceList? latest;
    if (lists != null) {
      for (final p in lists) {
        if (p.id == priceList.id) {
          latest = p;
          break;
        }
      }
    }
    final pl = latest ?? priceList;

    final activeId = ref.watch(activePriceListProvider).asData?.value?.id;
    final isActive = companyId != null && activeId == pl.id;

    final itemsAsync = ref.watch(priceListItemsProvider(pl.id));

    return AppScaffold(
      title: 'Fiyat Listesi Detayı',
      actions: [
        IconButton(
          icon: const Icon(Icons.edit_outlined),
          onPressed: companyId == null
              ? null
              : () async {
                  await showDialog<void>(
                    context: context,
                    builder: (_) => _EditPriceListDialog(existing: pl),
                  );
                },
        ),
      ],
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pl.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Başlangıç: ${pl.startDate.toLocal().toString().split(' ').first}',
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Bitiş: ${pl.endDate.toLocal().toString().split(' ').first}',
                          ),
                        ],
                      ),
                    ),
                    if (isActive) const Chip(label: Text('Aktif')),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: companyId == null
                    ? null
                    : () async {
                        await showModalBottomSheet<void>(
                          context: context,
                          builder: (_) => _FillPriceListSheet(priceList: pl),
                        );
                      },
                child: const Text('Fiyat listesini doldur'),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: itemsAsync.when(
                data: (items) {
                  return Column(
                    children: [
                      Card(
                        child: ListTile(
                          title: const Text(
                            'Aktif ürün sayısı',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          trailing: Text(
                            items.length.toString(),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.inventory_2_outlined),
                          title: const Text(
                            'Ürünler',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: const Text('Liste ürünlerini görüntüle / düzenle'),
                          trailing: const Icon(Icons.chevron_right_outlined),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => _PriceListItemsPage(priceList: pl),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(child: _PriceListMovementsCard(priceList: pl, items: items)),
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => const Center(child: Text('Liste ürünleri yüklenemedi')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FillPriceListSheet extends ConsumerStatefulWidget {
  final PriceList priceList;

  const _FillPriceListSheet({required this.priceList});

  @override
  ConsumerState<_FillPriceListSheet> createState() => _FillPriceListSheetState();
}

class _FillPriceListSheetState extends ConsumerState<_FillPriceListSheet> {
  bool _isWorking = false;

  @override
  Widget build(BuildContext context) {
    final companyId = ref.watch(activeCompanyIdProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Fiyat listesini doldur',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.copy_outlined),
                title: const Text('Eski fiyat listesinden getir'),
                subtitle: const Text('Seçilen listeyi tutar/yüzde artış ile kopyalar'),
                trailing: const Icon(Icons.chevron_right_outlined),
                onTap: _isWorking
                    ? null
                    : () async {
                        Navigator.of(context).pop();
                        await showDialog<void>(
                          context: context,
                          builder: (_) => _ClonePriceListDialog(target: widget.priceList),
                        );
                      },
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.download_outlined),
                title: const Text('Ürünlerden getir'),
                subtitle: const Text(
                  'Sadece listede olmayan ürünleri, son alış + ürün kâr marjı ile oluşturur',
                ),
                trailing: _isWorking
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.chevron_right_outlined),
                onTap: _isWorking || companyId == null
                    ? null
                    : () async {
                        setState(() {
                          _isWorking = true;
                        });

                        final repo = ref.read(priceListRepositoryProvider);
                        await repo.syncMissingItemsFromProductsWithMargin(
                          companyId: companyId,
                          priceListId: widget.priceList.id,
                        );

                        if (!mounted) return;
                        Navigator.of(context).pop();
                      },
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _isWorking ? null : () => Navigator.of(context).pop(),
                child: const Text('Kapat'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditPriceListDialog extends ConsumerStatefulWidget {
  final PriceList existing;

  const _EditPriceListDialog({required this.existing});

  @override
  ConsumerState<_EditPriceListDialog> createState() => _EditPriceListDialogState();
}

class _EditPriceListDialogState extends ConsumerState<_EditPriceListDialog> {
  late final TextEditingController _nameController;
  late DateTime _startDate;
  late DateTime _endDate;
  late PriceListType _type;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existing.name);
    _startDate = widget.existing.startDate;
    _endDate = widget.existing.endDate;
    _type = widget.existing.type;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickStart() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      _startDate = DateTime(picked.year, picked.month, picked.day);
      if (_endDate.isBefore(_startDate)) {
        _endDate = _startDate;
      }
    });
  }

  Future<void> _pickEnd() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      _endDate = DateTime(picked.year, picked.month, picked.day);
    });
  }

  @override
  Widget build(BuildContext context) {
    final companyId = ref.watch(activeCompanyIdProvider);

    return AlertDialog(
      title: const Text('Fiyat Listesini Düzenle'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Liste adı',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<PriceListType>(
              value: _type,
              decoration: const InputDecoration(
                labelText: 'Liste türü',
                border: OutlineInputBorder(),
              ),
              items: PriceListType.values
                  .map(
                    (t) => DropdownMenuItem(
                      value: t,
                      child: Text(t.name),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (v) {
                if (v == null) return;
                setState(() {
                  _type = v;
                });
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _pickStart,
                    child: Text(
                      'Başlangıç: ${_startDate.toLocal().toString().split(' ').first}',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _pickEnd,
                    child: Text(
                      'Bitiş: ${_endDate.toLocal().toString().split(' ').first}',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('İptal'),
        ),
        ElevatedButton(
          onPressed: _isSaving || companyId == null
              ? null
              : () async {
                  final name = _nameController.text.trim();
                  if (name.isEmpty) return;

                  setState(() {
                    _isSaving = true;
                  });

                  final repo = ref.read(priceListRepositoryProvider);
                  await repo.updatePriceList(
                    companyId: companyId,
                    priceListId: widget.existing.id,
                    name: name,
                    startDate: _startDate,
                    endDate: _endDate,
                    type: _type,
                  );

                  if (!mounted) return;
                  Navigator.of(context).pop();
                },
          child: Text(_isSaving ? 'Kaydediliyor...' : 'Kaydet'),
        ),
      ],
    );
  }
}

class _ClonePriceListDialog extends ConsumerStatefulWidget {
  final PriceList target;

  const _ClonePriceListDialog({required this.target});

  @override
  ConsumerState<_ClonePriceListDialog> createState() => _ClonePriceListDialogState();
}

class _ClonePriceListDialogState extends ConsumerState<_ClonePriceListDialog> {
  String? _sourceId;
  final TextEditingController _incController = TextEditingController();
  bool _isPercent = true;
  bool _isSaving = false;

  @override
  void dispose() {
    _incController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final companyId = ref.watch(activeCompanyIdProvider);
    final lists = ref.watch(priceListsProvider).asData?.value ?? const <PriceList>[];

    final candidates = lists
        .where((pl) => pl.id != widget.target.id)
        .toList(growable: false);

    return AlertDialog(
      title: const Text('Eski fiyat listesinden getir'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            value: _sourceId,
            decoration: const InputDecoration(
              labelText: 'Kaynak fiyat listesi',
              border: OutlineInputBorder(),
            ),
            items: candidates
                .map(
                  (pl) => DropdownMenuItem(
                    value: pl.id,
                    child: Text(pl.name),
                  ),
                )
                .toList(growable: false),
            onChanged: (v) {
              setState(() {
                _sourceId = v;
              });
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _incController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: _isPercent ? 'Artış (%)' : 'Artış (tutar)',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          CheckboxListTile(
            value: _isPercent,
            onChanged: (v) {
              setState(() {
                _isPercent = v ?? true;
              });
            },
            contentPadding: EdgeInsets.zero,
            title: const Text('Yüzde olarak uygula'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('İptal'),
        ),
        ElevatedButton(
          onPressed: _isSaving || companyId == null || _sourceId == null
              ? null
              : () async {
                  final incText = _incController.text.trim();
                  final inc = double.tryParse(incText.replaceAll(',', '.')) ?? 0;

                  setState(() {
                    _isSaving = true;
                  });

                  final repo = ref.read(priceListRepositoryProvider);
                  await repo.cloneFromOtherListWithIncrease(
                    companyId: companyId,
                    sourcePriceListId: _sourceId!,
                    targetPriceListId: widget.target.id,
                    increaseValue: inc,
                    isPercent: _isPercent,
                  );

                  if (!mounted) return;
                  Navigator.of(context).pop();
                },
          child: Text(_isSaving ? 'Kopyalanıyor...' : 'Uygula'),
        ),
      ],
    );
  }
}

class _PriceListItemsPage extends ConsumerWidget {
  final PriceList priceList;

  const _PriceListItemsPage({required this.priceList});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(priceListItemsProvider(priceList.id));

    return AppScaffold(
      title: 'Ürünler',
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final selected = await showDialog<Product?>(
            context: context,
            builder: (_) => _SelectProductDialog(priceListId: priceList.id),
          );
          if (selected == null) return;

          await showDialog<void>(
            context: context,
            builder: (_) => _EditPriceListItemDialog(
              priceListId: priceList.id,
              product: selected,
              existingItem: null,
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
      body: itemsAsync.when(
        data: (items) => _PriceListItemsView(priceList: priceList, items: items),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('Liste ürünleri yüklenemedi')),
      ),
    );
  }
}

class _EditPriceListItemDialog extends ConsumerStatefulWidget {
  final String priceListId;
  final Product product;
  final PriceListItem? existingItem;

  const _EditPriceListItemDialog({
    required this.priceListId,
    required this.product,
    required this.existingItem,
  });

  @override
  ConsumerState<_EditPriceListItemDialog> createState() => _EditPriceListItemDialogState();
}

class _EditPriceListItemDialogState extends ConsumerState<_EditPriceListItemDialog> {
  late final TextEditingController _purchaseController;
  late final TextEditingController _saleController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _purchaseController = TextEditingController(
      text: (widget.existingItem?.purchasePrice ?? widget.product.lastPurchasePrice)
          .toStringAsFixed(2),
    );
    _saleController = TextEditingController(
      text: (widget.existingItem?.salePrice ?? widget.product.salePrice).toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _purchaseController.dispose();
    _saleController.dispose();
    super.dispose();
  }

  double _parseMoney(String raw) {
    return double.tryParse(raw.trim().replaceAll(',', '.')) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final companyId = ref.watch(activeCompanyIdProvider);

    return AlertDialog(
      title: Text(widget.product.name.isNotEmpty ? widget.product.name : 'Ürün'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _purchaseController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Alış fiyatı',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _saleController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Satış fiyatı',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('İptal'),
        ),
        ElevatedButton(
          onPressed: _isSaving || companyId == null
              ? null
              : () async {
                  setState(() {
                    _isSaving = true;
                  });

                  final repo = ref.read(priceListRepositoryProvider);
                  await repo.upsertItemForProduct(
                    companyId: companyId,
                    priceListId: widget.priceListId,
                    product: widget.product,
                    purchasePrice: _parseMoney(_purchaseController.text),
                    salePrice: _parseMoney(_saleController.text),
                  );

                  if (!mounted) return;
                  Navigator.of(context).pop();
                },
          child: Text(_isSaving ? 'Kaydediliyor...' : 'Kaydet'),
        ),
      ],
    );
  }
}

class _SelectProductDialog extends ConsumerStatefulWidget {
  final String priceListId;

  const _SelectProductDialog({required this.priceListId});

  @override
  ConsumerState<_SelectProductDialog> createState() => _SelectProductDialogState();
}

class _SelectProductDialogState extends ConsumerState<_SelectProductDialog> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final companyId = ref.watch(activeCompanyIdProvider);
    if (companyId == null) {
      return const AlertDialog(content: Text('Firma seçili değil'));
    }

    final existing = ref.watch(priceListItemsProvider(widget.priceListId)).asData?.value ??
        const <PriceListItem>[];
    final existingIds = existing.map((e) => e.productId).toSet();

    final productsAsync = ref.watch(_allProductsProvider(companyId));

    return AlertDialog(
      title: const Text('Ürün seç'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(
                hintText: 'Ara',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (v) {
                setState(() {
                  _query = v.trim().toLowerCase();
                });
              },
            ),
            const SizedBox(height: 12),
            productsAsync.when(
              data: (products) {
                final filtered = products.where((p) {
                  if (existingIds.contains(p.id)) return false;
                  if (_query.isEmpty) return true;
                  return p.name.toLowerCase().contains(_query) ||
                      p.barcode.toLowerCase().contains(_query);
                }).toList(growable: false);

                if (filtered.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text('Eklenecek ürün bulunamadı'),
                  );
                }

                return SizedBox(
                  height: 300,
                  child: ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final p = filtered[index];
                      return ListTile(
                        title: Text(p.name.isNotEmpty ? p.name : p.id),
                        subtitle: p.barcode.isNotEmpty ? Text(p.barcode) : null,
                        onTap: () => Navigator.of(context).pop(p),
                      );
                    },
                  ),
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, __) => const Text('Ürünler yüklenemedi'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Kapat'),
        ),
      ],
    );
  }
}

class _PriceListItemsView extends ConsumerStatefulWidget {
  final PriceList priceList;
  final List<PriceListItem> items;

  const _PriceListItemsView({
    required this.priceList,
    required this.items,
  });

  @override
  ConsumerState<_PriceListItemsView> createState() => _PriceListItemsViewState();
}

class _PriceListItemsViewState extends ConsumerState<_PriceListItemsView> {
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
                    ownerId: 'price_list_items_scanner',
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
    final companyId = ref.watch(activeCompanyIdProvider);
    if (companyId == null) {
      return const Center(child: Text('Firma seçili değil'));
    }

    final productsAsync = ref.watch(_allProductsProvider(companyId));

    final currentUser = ref.watch(currentUserProvider);
    final isAdmin = currentUser != null && currentUser.role == UserRole.admin;

    final settings = ref.watch(appSettingsProvider);
    final minChars = settings.searchFilterMinChars;

    return productsAsync.when(
      data: (products) {
        final byId = {for (final p in products) p.id: p};

        final sorted = [...widget.items]..sort((a, b) {
            final an = byId[a.productId]?.name ?? '';
            final bn = byId[b.productId]?.name ?? '';
            return an.compareTo(bn);
          });

        final query = _searchQuery.trim().toLowerCase();
        final isFilterActive = query.isNotEmpty && query.length >= minChars;

        final filtered = isFilterActive
            ? sorted.where((item) {
                final p = byId[item.productId];
                final name = (p?.name ?? '').toLowerCase();
                final barcode = (p?.barcode ?? '').toLowerCase();
                return name.contains(query) || barcode.contains(query);
              }).toList(growable: false)
            : sorted;

        return CustomScrollView(
          slivers: [
            SliverPersistentHeader(
              pinned: true,
              delegate: _SearchBarHeaderDelegate(
                minHeight: 76,
                maxHeight: 76,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: TextField(
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
                ),
              ),
            ),
            if (isFilterActive && filtered.isEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Text(
                    'Sonuç bulunamadı',
                    style: TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    if (index.isOdd) {
                      return const SizedBox(height: 8);
                    }

                    final item = filtered[index ~/ 2];
                    final product = byId[item.productId];
                    final title =
                        product?.name.isNotEmpty == true ? product!.name : item.productId;

                    return Card(
                      child: ListTile(
                        title: Text(title),
                        subtitle: Text(
                          'Alış: ${formatMoney(item.purchasePrice)}  •  Satış: ${formatMoney(item.salePrice)}',
                        ),
                        trailing: isAdmin
                            ? IconButton(
                                icon: const Icon(Icons.delete_outline),
                                tooltip: 'Sil',
                                onPressed: () async {
                                  final ok = await showDialog<bool>(
                                    context: context,
                                    builder: (context) {
                                      return AlertDialog(
                                        title: const Text('Silinsin mi?'),
                                        content: Text(
                                          '"$title" ürünü bu fiyat listesinden silinecek.',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.of(context).pop(false),
                                            child: const Text('İptal'),
                                          ),
                                          ElevatedButton(
                                            onPressed: () =>
                                                Navigator.of(context).pop(true),
                                            child: const Text('Sil'),
                                          ),
                                        ],
                                      );
                                    },
                                  );

                                  if (ok != true) return;

                                  final repo = ref.read(priceListRepositoryProvider);
                                  await repo.deleteItemForProduct(
                                    companyId: companyId,
                                    priceListId: widget.priceList.id,
                                    productId: item.productId,
                                  );
                                },
                              )
                            : (item.isInherited
                                ? const Icon(Icons.warning_amber_outlined)
                                : const Icon(Icons.edit_outlined)),
                        onTap: product == null
                            ? null
                            : () async {
                                await showDialog<void>(
                                  context: context,
                                  builder: (_) => _EditPriceListItemDialog(
                                    priceListId: widget.priceList.id,
                                    product: product,
                                    existingItem: item,
                                  ),
                                );
                              },
                      ),
                    );
                  },
                  childCount: filtered.isEmpty ? 0 : (filtered.length * 2) - 1,
                ),
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text('Ürünler yüklenemedi')),
    );
  }
}

class _PriceListMovementsCard extends ConsumerWidget {
  final PriceList priceList;
  final List<PriceListItem> items;

  const _PriceListMovementsCard({required this.priceList, required this.items});

  String _actorLabel({
    required CompanyMember? member,
    required String fallback,
  }) {
    final m = member;
    if (m != null) {
      final dn = m.displayName.trim();
      if (dn.isNotEmpty) return dn;

      final email = m.email.trim();
      if (email.isNotEmpty) return email;
    }

    return fallback.trim();
  }

  String _subtitleWithActor(String title, String actor) {
    final trimmed = actor.trim();
    if (trimmed.isEmpty) return title;
    return '$title • $trimmed';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final companyId = ref.watch(activeCompanyIdProvider);
    if (companyId == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Firma seçili değil'),
        ),
      );
    }

    final productsAsync = ref.watch(_allProductsProvider(companyId));

    return productsAsync.when(
      data: (products) {
        final byId = {for (final p in products) p.id: p};

        final settings = ref.watch(appSettingsProvider);
        final pageSize = settings.movementsPageSize;

        final entries = <_MovementEntry>[
          _MovementEntry(
            occurredAt: priceList.meta.modifiedDate,
            title: 'Fiyat listesi güncellendi',
            subject: priceList.name,
            actorId: priceList.meta.modifiedBy,
          ),
          ...items.map(
            (i) {
              final productName = byId[i.productId]?.name ?? i.productId;
              return _MovementEntry(
                occurredAt: i.meta.modifiedDate,
                title: 'Ürün fiyatı güncellendi',
                subject: productName,
                actorId: i.meta.modifiedBy,
              );
            },
          ),
        ];

        entries.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));

        final limited = entries.length > pageSize ? entries.sublist(0, pageSize) : entries;

        return Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ListTile(
                title: Text(
                  'Hareketler',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const Divider(height: 0),
              if (limited.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Hareket yok'),
                )
              else
                Expanded(
                  child: ListView.separated(
                    itemCount: limited.length,
                    separatorBuilder: (_, __) => const Divider(height: 0),
                    itemBuilder: (context, index) {
                      final e = limited[index];

                      final local = e.occurredAt.toLocal();
                      final dateStr =
                          '${local.day.toString().padLeft(2, '0')}.'
                          '${local.month.toString().padLeft(2, '0')}.'
                          '${local.year}';
                      final timeStr =
                          '${local.hour.toString().padLeft(2, '0')}:'
                          '${local.minute.toString().padLeft(2, '0')}';

                      return Consumer(
                        builder: (context, ref, _) {
                          final rawActor = e.actorId.trim();
                          final looksLikeEmail = rawActor.contains('@');

                          final memberAsync = looksLikeEmail || rawActor.isEmpty
                              ? null
                              : ref.watch(
                                  _companyMemberProvider(
                                    _MemberKey(companyId: companyId, uid: rawActor),
                                  ),
                                );

                          final actor = _actorLabel(
                            member: memberAsync?.asData?.value,
                            fallback: rawActor,
                          );

                          return ListTile(
                            leading: SizedBox(
                              width: 64,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(dateStr, style: const TextStyle(fontSize: 12)),
                                  Text(timeStr, style: const TextStyle(fontSize: 12)),
                                ],
                              ),
                            ),
                            title: Text(e.title),
                            subtitle: Text(_subtitleWithActor(e.subject, actor)),
                          );
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
      loading: () => const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (_, __) => const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Hareketler yüklenemedi'),
        ),
      ),
    );
  }
}

class _MovementEntry {
  final DateTime occurredAt;
  final String title;
  final String subject;
  final String actorId;

  _MovementEntry({
    required this.occurredAt,
    required this.title,
    required this.subject,
    required this.actorId,
  });
}