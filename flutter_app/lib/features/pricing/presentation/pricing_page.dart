import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_scaffold.dart';
import '../../auth/domain/user.dart';
import '../../auth/domain/current_user_provider.dart' show currentUserProvider;
import '../../company/domain/active_company_provider.dart';
import '../data/price_list_repository.dart';
import '../domain/price_list.dart';
import '../domain/price_list_providers.dart';
import 'pricing_detail_page.dart';

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

  String _typeText(PriceListType type) {
    switch (type) {
      case PriceListType.cash:
        return 'Nakit';
      case PriceListType.card:
        return 'K.Kartı';
      case PriceListType.credit:
        return 'Veresiye';
      case PriceListType.general:
        return 'Genel';
    }
  }

  @override
  Widget build(BuildContext context) {
    final listsAsync = ref.watch(priceListsProvider);
    final activeAsync = ref.watch(activePriceListProvider);

    final currentUser = ref.watch(currentUserProvider);
    final isAdmin = currentUser != null && currentUser.role == UserRole.admin;

    return AppScaffold(
      title: 'Fiyat Listeleri',
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: () async {
                await showDialog<void>(
                  context: context,
                  builder: (_) => const _CreatePriceListDialog(),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Yeni Liste'),
            )
          : null,
      body: listsAsync.when(
        data: (lists) {
          final query = _searchQuery.trim().toLowerCase();
          final filtered = query.isEmpty
              ? lists
              : lists
                  .where((pl) => pl.name.toLowerCase().contains(query))
                  .toList(growable: false);

          if (filtered.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
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
                  ),
                  const SizedBox(height: 24),
                  const Center(child: Text('Henüz fiyat listesi yok')),
                  if (isAdmin) ...[
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () async {
                        await showDialog<void>(
                          context: context,
                          builder: (_) => const _CreatePriceListDialog(),
                        );
                      },
                      child: const Text('Fiyat Listesi Oluştur'),
                    ),
                  ],
                ],
              ),
            );
          }

          final activeId = activeAsync.asData?.value?.id;

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: filtered.length + 1,
            separatorBuilder: (context, index) =>
                const SizedBox(height: 8),
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

              final pl = filtered[index - 1];
              final isActive = pl.id == activeId;

              final dateText =
                  '${pl.startDate.toLocal().toString().split(' ').first} - ${pl.endDate.toLocal().toString().split(' ').first}';

              return Card(
                child: ListTile(
                  title: Text(
                    pl.name,
                    style: TextStyle(
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    '${_typeText(pl.type)}  •  $dateText'
                    '${pl.inactiveReason != null ? '\n${pl.inactiveReason}' : ''}',
                  ),
                  trailing: isActive
                      ? const Chip(label: Text('Aktif'))
                      : isAdmin
                          ? ElevatedButton(
                              onPressed: () async {
                                final companyId =
                                    ref.read(activeCompanyIdProvider);
                                if (companyId == null) return;

                                final ok = await showDialog<bool>(
                                  context: context,
                                  builder: (context) {
                                    return AlertDialog(
                                      title: const Text('Fiyat listesi aktif edilsin mi?'),
                                      content: Text('"${pl.name}" aktif fiyat listesi olarak ayarlanacak.'),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.of(context).pop(false),
                                          child: const Text('İptal'),
                                        ),
                                        ElevatedButton(
                                          onPressed: () => Navigator.of(context).pop(true),
                                          child: const Text('Onayla'),
                                        ),
                                      ],
                                    );
                                  },
                                );

                                if (ok != true) return;

                                final repo =
                                    ref.read(priceListRepositoryProvider);
                                await repo.setActivePriceList(
                                  companyId: companyId,
                                  priceListId: pl.id,
                                  previousExpired: false,
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                visualDensity: VisualDensity.compact,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              child: const Text('Aktif Et'),
                            )
                          : null,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PricingDetailPage(priceList: pl),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('Fiyat listeleri yüklenemedi')),
      ),
    );
  }
}

class _CreatePriceListDialog extends ConsumerStatefulWidget {
  const _CreatePriceListDialog();

  @override
  ConsumerState<_CreatePriceListDialog> createState() =>
      _CreatePriceListDialogState();
}

class _CreatePriceListDialogState extends ConsumerState<_CreatePriceListDialog> {
  final TextEditingController _nameController = TextEditingController();
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 30));
  PriceListType _type = PriceListType.general;
  bool _makeActive = true;
  bool _isSaving = false;

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
    return AlertDialog(
      title: const Text('Yeni Fiyat Listesi'),
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
            const SizedBox(height: 8),
            CheckboxListTile(
              value: _makeActive,
              onChanged: (v) {
                setState(() {
                  _makeActive = v ?? true;
                });
              },
              contentPadding: EdgeInsets.zero,
              title: const Text('Oluşturunca aktif yap'),
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
          onPressed: _isSaving
              ? null
              : () async {
                  final name = _nameController.text.trim();
                  if (name.isEmpty) return;

                  final companyId = ref.read(activeCompanyIdProvider);
                  if (companyId == null) return;

                  setState(() {
                    _isSaving = true;
                  });

                  try {
                    final repo = ref.read(priceListRepositoryProvider);
                    await repo.createPriceList(
                      companyId: companyId,
                      name: name,
                      startDate: _startDate,
                      endDate: _endDate,
                      type: _type,
                      makeActive: _makeActive,
                    );

                    if (!mounted) return;
                    Navigator.of(context).pop();
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Kayıt hatası: $e')),
                    );
                    setState(() {
                      _isSaving = false;
                    });
                  }
                },
          child: Text(_isSaving ? 'Kaydediliyor...' : 'Kaydet'),
        ),
      ],
    );
  }
}