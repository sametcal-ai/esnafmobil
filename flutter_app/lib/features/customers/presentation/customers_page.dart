import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_settings.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../auth/domain/auth_controller.dart';
import '../../auth/domain/user.dart';
import '../data/customer_repository.dart';
import '../domain/customer.dart';

final customersProvider =
    FutureProvider.autoDispose<List<Customer>>((ref) async {
  final repo = CustomerRepository();
  return repo.getAllCustomers();
});

class CustomersPage extends ConsumerStatefulWidget {
  const CustomersPage({super.key});

  @override
  ConsumerState<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends ConsumerState<CustomersPage> {
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
    final customersAsync = ref.watch(customersProvider);
    final authState = ref.watch(authControllerProvider);
    final user = authState.currentUser;
    final isAdmin = user != null && user.role == UserRole.admin;
    final settings = ref.watch(appSettingsProvider);
    final minChars = settings.searchFilterMinChars;

    return AppScaffold(
      title: 'Customers',
      actions: [
        if (isAdmin)
          IconButton(
            icon: const Icon(Icons.assessment_outlined),
            tooltip: 'Cari Durum',
            onPressed: () {
              context.pushNamed('customer_balances');
            },
          ),
      ],
      body: customersAsync.when(
        data: (customers) {
          if (customers.isEmpty) {
            return const Center(
              child: Text('Henüz müşteri yok'),
            );
          }

          final query = _searchQuery.trim().toLowerCase();
          final isFilterActive =
              query.isNotEmpty && query.length >= minChars;

          final filteredCustomers = isFilterActive
              ? customers.where((customer) {
                  final name = customer.name.toLowerCase();
                  final phone = (customer.phone ?? '').toLowerCase();
                  return name.contains(query) || phone.contains(query);
                }).toList()
              : customers;

          return ListView.separated(
            padding: const EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: 80,
            ),
            itemCount: filteredCustomers.length + 1,
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
                    hintText: 'Müşterilerde ara',
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

              final customer = filteredCustomers[index - 1];
              return Card(
                child: ListTile(
                  title: Text(customer.name),
                  subtitle: Text(customer.phone ?? ''),
                  onTap: () {
                    context.push(
                      '/customers/${customer.id}',
                    );
                  },
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(
          child: Text('Müşteriler yüklenemedi'),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await showDialog<bool>(
            context: context,
            builder: (context) {
              return const _AddCustomerDialog();
            },
          );
          if (created == true) {
            ref.invalidate(customersProvider);
          }
        },
        icon: const Icon(Icons.person_add_alt_1_outlined),
        label: const Text('Müşteri Ekle'),
      ),
    );
  }
}

class _AddCustomerDialog extends StatefulWidget {
  const _AddCustomerDialog({super.key});

  @override
  State<_AddCustomerDialog> createState() => _AddCustomerDialogState();
}

class _AddCustomerDialogState extends State<_AddCustomerDialog> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim().isEmpty
        ? null
        : _phoneController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Müşteri adı boş olamaz'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final repo = CustomerRepository();
    // Şimdilik current user bilgisine bu dialog içinden erişmiyoruz,
    // bu nedenle createdBy 'system' olarak kalmaya devam ediyor.
    await repo.createCustomer(name: name, phone: phone);

    if (!mounted) return;
    setState(() {
      _isSaving = false;
    });
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Yeni Müşteri'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Müşteri adı',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Telefon (opsiyonel)',
              border: OutlineInputBorder(),
            ),
          ),
        ],
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