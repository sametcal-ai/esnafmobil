import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_settings.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../auth/domain/auth_controller.dart';
import '../../auth/domain/user.dart';
import '../data/supplier_repository.dart';
import '../domain/supplier.dart';

final suppliersProvider =
    FutureProvider.autoDispose<List<Supplier>>((ref) async {
  final repo = SupplierRepository();
  return repo.getAllSuppliers();
});

class SuppliersPage extends ConsumerStatefulWidget {
  const SuppliersPage({super.key});

  @override
  ConsumerState<SuppliersPage> createState() => _SuppliersPageState();
}

class _SuppliersPageState extends ConsumerState<SuppliersPage> {
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
    final suppliersAsync = ref.watch(suppliersProvider);
    final authState = ref.watch(authControllerProvider);
    final currentUser = authState.currentUser;
    final isAdmin = currentUser != null && currentUser.role == UserRole.admin;
    final settings = ref.watch(appSettingsProvider);
    final minChars = settings.searchFilterMinChars;

    return AppScaffold(
      title: 'Suppliers',
      actions: [
        if (isAdmin)
          IconButton(
            icon: const Icon(Icons.list_alt_outlined),
            tooltip: 'Stok Hareketleri',
            onPressed: () {
              context.pushNamed('stock_movements');
            },
          ),
        if (isAdmin)
          IconButton(
            icon: const Icon(Icons.inventory_outlined),
            tooltip: 'Stok Girişi',
            onPressed: () {
              context.pushNamed('stock_entry');
            },
          ),
      ],
      body: suppliersAsync.when(
        data: (suppliers) {
          if (suppliers.isEmpty) {
            return const Center(
              child: Text('Henüz tedarikçi yok'),
            );
          }

          final query = _searchQuery.trim().toLowerCase();
          final isFilterActive =
              query.isNotEmpty && query.length >= minChars;

          final filteredSuppliers = isFilterActive
              ? suppliers.where((supplier) {
                  final name = supplier.name.toLowerCase();
                  final phone = (supplier.phone ?? '').toLowerCase();
                  final address = (supplier.address ?? '').toLowerCase();
                  final note = (supplier.note ?? '').toLowerCase();
                  return name.contains(query) ||
                      phone.contains(query) ||
                      address.contains(query) ||
                      note.contains(query);
                }).toList()
              : suppliers;

          return ListView.separated(
            padding: const EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: 80,
            ),
            itemCount: filteredSuppliers.length + 1,
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
                    hintText: 'Tedarikçilerde ara',
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

              final supplier = filteredSuppliers[index - 1];
              return Card(
                child: Column(
                  children: [
                    ListTile(
                      title: Text(supplier.name),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (supplier.phone != null &&
                              supplier.phone!.isNotEmpty)
                            Text('Telefon: ${supplier.phone}'),
                          if (supplier.address != null &&
                              supplier.address!.isNotEmpty)
                            Text('Adres: ${supplier.address}'),
                        ],
                      ),
                      onTap: () {
                        context.push('/suppliers/${supplier.id}');
                      },
                      trailing: isAdmin
                          ? IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () async {
                                final repo = SupplierRepository();
                                await repo.deleteSupplier(supplier.id);
                                ref.invalidate(suppliersProvider);
                              },
                            )
                          : null,
                    ),
                    if (isAdmin)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(
                          start: 12,
                          end: 12,
                          bottom: 12,
                        ),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              context.pushNamed(
                                'stock_entry',
                                extra: supplier,
                              );
                            },
                            icon: const Icon(Icons.shopping_cart_outlined),
                            label: const Text('Ürün Alış / Stok Girişi'),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(
          child: Text('Tedarikçiler yüklenemedi'),
        ),
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: () async {
                final created = await showDialog<bool>(
                  context: context,
                  builder: (context) => const _EditSupplierDialog(),
                );
                if (created == true) {
                  ref.invalidate(suppliersProvider);
                }
              },
              icon: const Icon(Icons.person_add_alt_1_outlined),
              label: const Text('Tedarikçi Ekle'),
            )
          : null,
    );
  }
}

class _EditSupplierDialog extends StatefulWidget {
  final Supplier? existing;

  const _EditSupplierDialog({super.key, this.existing});

  @override
  State<_EditSupplierDialog> createState() => _EditSupplierDialogState();
}

class _EditSupplierDialogState extends State<_EditSupplierDialog> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _nameController.text = existing.name;
      _phoneController.text = existing.phone ?? '';
      _addressController.text = existing.address ?? '';
      _noteController.text = existing.note ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final address = _addressController.text.trim();
    final note = _noteController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tedarikçi adı boş olamaz'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final repo = SupplierRepository();

    if (widget.existing == null) {
      await repo.createSupplier(
        name: name,
        phone: phone.isEmpty ? null : phone,
        address: address.isEmpty ? null : address,
        note: note.isEmpty ? null : note,
      );
    } else {
      final updated = widget.existing!.copyWith(
        name: name,
        phone: phone.isEmpty ? null : phone,
        address: address.isEmpty ? null : address,
        note: note.isEmpty ? null : note,
      );
      await repo.updateSupplier(updated);
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
      title: Text(isEdit ? 'Tedarikçiyi Düzenle' : 'Yeni Tedarikçi'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Tedarikçi adı',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneController,
              textInputAction: TextInputAction.next,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Telefon',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _addressController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Adres',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: 'Not',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed:
              _isSaving ? null : () => Navigator.of(context).pop(false),
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