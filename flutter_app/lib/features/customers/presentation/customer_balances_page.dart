import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/money_formatter.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../data/customer_repository.dart';
import '../data/customer_ledger_repository.dart';
import '../domain/customer.dart';
import '../domain/customer_ledger.dart';

enum BalanceFilter {
  all,
  debtOnly,
  creditOnly,
}

final customerBalancesProvider = FutureProvider.autoDispose<
    List<CustomerBalance>>((ref) async {
  final customerRepo = CustomerRepository();
  final ledgerRepo = CustomerLedgerRepository(customerRepo);

  final customers = await customerRepo.getAllCustomers();
  final balances = <CustomerBalance>[];

  for (final customer in customers) {
    final balance = await ledgerRepo.getBalanceForCustomer(customer.id);
    if (balance != 0) {
      balances.add(
        CustomerBalance(customer: customer, balance: balance),
      );
    }
  }

  // Bakiyeye göre büyükten küçüğe
  balances.sort((a, b) => b.balance.compareTo(a.balance));

  return balances;
});

class CustomerBalancesPage extends ConsumerStatefulWidget {
  const CustomerBalancesPage({super.key});

  @override
  ConsumerState<CustomerBalancesPage> createState() =>
      _CustomerBalancesPageState();
}

class _CustomerBalancesPageState
    extends ConsumerState<CustomerBalancesPage> {
  BalanceFilter _filter = BalanceFilter.all;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _dateFilterEnabled = false;

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final initialFirstDate =
        _startDate ?? DateTime(now.year, now.month, 1);
    final initialLastDate = _endDate ?? now;

    final result = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
      initialDateRange: DateTimeRange(
        start: initialFirstDate,
        end: initialLastDate,
      ),
    );

    if (result != null) {
      setState(() {
        _startDate = result.start;
        _endDate = result.end;
        _dateFilterEnabled = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final balancesAsync = ref.watch(customerBalancesProvider);

    return AppScaffold(
      title: 'Cari Durum',
      body: Column(
        children: [
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Filtreler',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Tümü'),
                      selected: _filter == BalanceFilter.all,
                      onSelected: (_) {
                        setState(() {
                          _filter = BalanceFilter.all;
                        });
                      },
                    ),
                    ChoiceChip(
                      label: const Text('Borçlu (> 0)'),
                      selected: _filter == BalanceFilter.debtOnly,
                      onSelected: (_) {
                        setState(() {
                          _filter = BalanceFilter.debtOnly;
                        });
                      },
                    ),
                    ChoiceChip(
                      label: const Text('Alacaklı (< 0)'),
                      selected: _filter == BalanceFilter.creditOnly,
                      onSelected: (_) {
                        setState(() {
                          _filter = BalanceFilter.creditOnly;
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _dateFilterEnabled && _startDate != null
                            ? 'Tarih: '
                                '${_startDate!.day.toString().padLeft(2, '0')}.'
                                '${_startDate!.month.toString().padLeft(2, '0')}.'
                                '${_startDate!.year}'
                                ' - '
                                '${_endDate!.day.toString().padLeft(2, '0')}.'
                                '${_endDate!.month.toString().padLeft(2, '0')}.'
                                '${_endDate!.year}'
                            : 'Tarih: tüm hareketler',
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _pickDateRange,
                      icon: const Icon(Icons.date_range_outlined),
                      label: const Text('Tarih Seç'),
                    ),
                    if (_dateFilterEnabled)
                      IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _dateFilterEnabled = false;
                            _startDate = null;
                            _endDate = null;
                          });
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 0),
          Expanded(
            child: balancesAsync.when(
              data: (balances) {
                if (balances.isEmpty) {
                  return const Center(
                    child: Text('Aktif borcu olan müşteri yok'),
                  );
                }

                final filtered = balances.where((item) {
                  final b = item.balance;
                  if (_filter == BalanceFilter.debtOnly && b <= 0) {
                    return false;
                  }
                  if (_filter == BalanceFilter.creditOnly && b >= 0) {
                    return false;
                  }
                  return true;
                }).toList();

                if (filtered.isEmpty) {
                  return const Center(
                    child: Text('Seçili filtrelere göre sonuç bulunamadı'),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    final customer = item.customer;
                    final balance = item.balance;

                    final color = balance > 0
                        ? Colors.red.shade700
                        : Colors.green.shade700;

                    return Card(
                      child: ListTile(
                        title: Text(customer.name),
                        subtitle: Text(customer.phone ?? ''),
                        trailing: Text(
                          formatMoney(balance),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
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
              loading: () => const Center(
                child: CircularProgressIndicator(),
              ),
              error: (_, __) => const Center(
                child: Text('Cari durum yüklenemedi'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}