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

    final itemsAsync = companyId == null
        ? const AsyncValue<List<PriceListItem>>.data(<PriceListItem>[])
        : ref.watch(
            StreamProvider.autoDispose<List<PriceListItem>>(
              (ref) {
                final repo = ref.watch(priceListRepositoryProvider);
                return repo.watchItems(companyId, pl.id);
              },
            ),
          );

    return AppScaffold(
      title: 'Fiyat Listesi Detayı',
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: itemsAsync.when(
          data: (items) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
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
                              Text('Başlangıç: ${_dateText(pl.startDate)}'),
                              const SizedBox(height: 4),
                              Text('Bitiş: ${_dateText(pl.endDate)}'),
                              if (isActive) ...[
                                const SizedBox(height: 8),
                                const Chip(label: Text('Aktif')),
                              ],
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Düzenle',
                          onPressed: companyId == null
                              ? null
                              : () async {
                                  await showModalBottomSheet<void>(
                                    context: context,
                                    isScrollControlled: true,
                                    builder: (_) => _EditPriceListSheet(
                                      priceList: pl,
                                      companyId: companyId,
                                    ),
                                  );
                                },
                          icon: const Icon(Icons.edit_outlined),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Card(
                        child: ListTile(
                          title: const Text('Aktif ürün sayısı'),
                          subtitle: Text(items.length.toString()),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: items.isEmpty
                      ? _EmptyPriceListActions(priceList: priceList)
                      : Card(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const ListTile(
                                title: Text(
                                  'Ürünler',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ),
                              const Divider(height: 1),
                              Expanded(
                                child: _PriceListItemsView(
                                  priceList: priceList,
                                  items: items,
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const Center(child: Text('Liste ürünleri yüklenemedi')),
        ),
      ),
    );
  }
}

class _EditPriceListSheet extends ConsumerStatefulWidget {
  final PriceList priceList;
  final String companyId;

  const _EditPriceListSheet({
    required this.priceList,
    required this.companyId,
  });

  @override
  ConsumerState<_EditPriceListSheet> createState() => _EditPriceListSheetState();
}

class _EditPriceListSheetState extends ConsumerState<_EditPriceListSheet> {
  late final TextEditingController _nameController;
  late DateTime _startDate;
  late DateTime _endDate;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.priceList.name);
    _startDate = widget.priceList.startDate;
    _endDate = widget.priceList.endDate;
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
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: 16 + bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Fiyat Listesini Düzenle',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Liste adı',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isSaving ? null : _pickStart,
                  child: Text(
                    'Başlangıç: ${_startDate.toLocal().toString().split(' ').first}',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: _isSaving ? null : _pickEnd,
                  child: Text(
                    'Bitiş: ${_endDate.toLocal().toString().split(' ').first}',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                  child: const Text('İptal'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isSaving
                      ? null
                      : () async {
                          final name = _nameController.text.trim();
                          if (name.isEmpty) return;

                          setState(() {
                            _isSaving = true;
                          });

                          try {
                            final repo = ref.read(priceListRepositoryProvider);
                            await repo.updatePriceList(
                              companyId: widget.companyId,
                              priceListId: widget.priceList.id,
                              name: name,
                              startDate: _startDate,
                              endDate: _endDate,
                            );

                            if (!mounted) return;
                            Navigator.of(context).pop();
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Güncelleme hatası: $e')),
                            );
                            setState(() {
                              _isSaving = false;
                            });
                          }
                        },
                  child: Text(_isSaving ? 'Kaydediliyor...' : 'Kaydet'),
                ),
              ),
            ],
          ),
        ],
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