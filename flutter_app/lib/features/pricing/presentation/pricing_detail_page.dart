import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/money_formatter.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../company/domain/active_company_provider.dart';
import '../../products/data/product_repository.dart';
import '../../products/domain/product.dart';
import '../data/price_list_repository.dart';
import '../domain/price_list.dart';
import '../domain/price_list_item.dart';
import '../domain/price_list_providers.dart';

class PricingDetailPage extends ConsumerWidget {
  final PriceList priceList;

  const PricingDetailPage({super.key, required this.priceList});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final companyId = ref.watch(activeCompanyIdProvider);
    final activeId = ref.watch(activePriceListProvider).asData?.value?.id;
    final isActive = companyId != null && activeId == priceList.id;

    final itemsAsync = companyId == null
        ? const AsyncValue<List<PriceListItem>>.data(<PriceListItem>[])
        : ref.watch(
            StreamProvider.autoDispose<List<PriceListItem>>(
              (ref) {
                final repo = ref.watch(priceListRepositoryProvider);
                return repo.watchItems(companyId, priceList.id);
              },
            ),
          );

    return AppScaffold(
      title: 'Fiyat Listesi Detayı',
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: ListTile(
                title: Text(
                  priceList.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  '${priceList.startDate.toLocal().toString().split(' ').first} - ${priceList.endDate.toLocal().toString().split(' ').first}',
                ),
                trailing: isActive ? const Chip(label: Text('Aktif')) : null,
              ),
            ),
            const SizedBox(height: 12),
            itemsAsync.when(
              data: (items) {
                return Expanded(
                  child: items.isEmpty
                      ? _EmptyPriceListActions(priceList: priceList)
                      : _PriceListItemsView(
                          priceList: priceList,
                          items: items,
                        ),
                );
              },
              loading: () => const Expanded(
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, __) => const Expanded(
                child: Center(child: Text('Liste ürünleri yüklenemedi')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyPriceListActions extends ConsumerStatefulWidget {
  final PriceList priceList;

  const _EmptyPriceListActions({required this.priceList});

  @override
  ConsumerState<_EmptyPriceListActions> createState() =>
      _EmptyPriceListActionsState();
}

class _EmptyPriceListActionsState extends ConsumerState<_EmptyPriceListActions> {
  bool _isWorking = false;

  @override
  Widget build(BuildContext context) {
    final companyId = ref.watch(activeCompanyIdProvider);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Bu fiyat listesinde henüz ürün yok'),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isWorking || companyId == null
                  ? null
                  : () async {
                      setState(() {
                        _isWorking = true;
                      });

                      final repo = ref.read(priceListRepositoryProvider);
                      await repo.syncMissingItemsFromProducts(
                        companyId: companyId,
                        priceListId: widget.priceList.id,
                      );

                      if (!mounted) return;
                      setState(() {
                        _isWorking = false;
                      });
                    },
              icon: const Icon(Icons.download_outlined),
              label: Text(
                _isWorking ? 'Aktarılıyor...' : 'Ürünlerden çek',
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isWorking
                  ? null
                  : () async {
                      await showDialog<void>(
                        context: context,
                        builder: (_) =>
                            _ClonePriceListDialog(target: widget.priceList),
                      );
                    },
              icon: const Icon(Icons.copy_outlined),
              label: const Text('Eski listeden kopyala + artış'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ClonePriceListDialog extends ConsumerStatefulWidget {
  final PriceList target;

  const _ClonePriceListDialog({required this.target});

  @override
  ConsumerState<_ClonePriceListDialog> createState() =>
      _ClonePriceListDialogState();
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
      title: const Text('Eski listeden kopyala'),
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
          child: Text(_isSaving ? 'Kopyalanıyor...' : 'Kopyala'),
        ),
      ],
    );
  }
}

class _PriceListItemsView extends ConsumerWidget {
  final PriceList priceList;
  final List<PriceListItem> items;

  const _PriceListItemsView({
    required this.priceList,
    required this.items,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final companyId = ref.watch(activeCompanyIdProvider);
    if (companyId == null) {
      return const Center(child: Text('Firma seçili değil'));
    }

    final productsAsync = ref.watch(
      FutureProvider.autoDispose<List<Product>>((ref) async {
        final repo = ref.watch(productsRepositoryProvider);
        return repo.getAllProducts(companyId);
      }),
    );

    return productsAsync.when(
      data: (products) {
        final byId = {for (final p in products) p.id: p};

        return ListView.separated(
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final item = items[index];
            final product = byId[item.productId];
            final title = product?.name.isNotEmpty == true
                ? product!.name
                : item.productId;

            return Card(
              child: ListTile(
                title: Text(title),
                subtitle: Text(
                  'Alış: ${formatMoney(item.purchasePrice)}  •  Satış: ${formatMoney(item.salePrice)}',
                ),
                trailing: item.isInherited
                    ? const Icon(Icons.warning_amber_outlined)
                    : null,
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text('Ürünler yüklenemedi')),
    );
  }
}