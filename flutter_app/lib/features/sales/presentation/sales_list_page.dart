import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/money_formatter.dart';
import '../../../core/firestore/firestore_refs.dart';
import '../../../core/firestore/models/company_member.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../auth/domain/current_user_provider.dart' show currentUserProvider;
import '../../auth/domain/user.dart';
import '../../company/domain/active_company_provider.dart';
import '../../customers/data/customer_repository.dart';
import '../../customers/domain/customer.dart';
import '../data/sales_repository.dart';
import 'sale_edit_args.dart';

final _salesCustomersMapProvider = FutureProvider<Map<String, Customer>>((ref) async {
  final companyId = ref.watch(activeCompanyIdProvider);
  if (companyId == null) return <String, Customer>{};

  final repo = ref.watch(customerRepositoryProvider);
  final customers = await repo.getAllCustomers(companyId);
  return {
    for (final c in customers) c.id: c,
  };
});

final _companyMembersMapProvider = StreamProvider<Map<String, CompanyMember>>((ref) {
  final companyId = ref.watch(activeCompanyIdProvider);
  if (companyId == null) return const Stream<Map<String, CompanyMember>>.empty();

  final refs = ref.watch(firestoreRefsProvider);
  return refs.members(companyId).snapshots().map((snap) {
    final map = <String, CompanyMember>{};
    for (final d in snap.docs) {
      final m = d.data();
      map[m.uid] = m;
    }
    return map;
  });
});

class SalesListPage extends ConsumerWidget {
  const SalesListPage({super.key});

  String _paymentLabel(String method) {
    switch (method) {
      case 'cash':
        return 'Nakit';
      case 'card':
        return 'Kredi Kartı';
      case 'credit':
        return 'Veresiye';
      case 'split':
        return 'Parçalı';
      default:
        return method;
    }
  }

  Future<void> _showSaleDetails(
    BuildContext context,
    WidgetRef ref,
    Sale sale, {
    required String customerLabel,
    required String createdByLabel,
    required bool canEdit,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Satış Detayı',
                      style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('Cari: $customerLabel'),
              const SizedBox(height: 4),
              Text('Ödeme: ${_paymentLabel(sale.paymentMethod)}'),
              const SizedBox(height: 4),
              Text('Kullanıcı: $createdByLabel'),
              const SizedBox(height: 4),
              Text('Tarih: ${sale.createdAt}'),
              const SizedBox(height: 12),
              const Divider(height: 0),
              const SizedBox(height: 12),
              Text(
                'Ürünler',
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: sale.items.length,
                  separatorBuilder: (_, __) => const Divider(height: 0),
                  itemBuilder: (context, index) {
                    final item = sale.items[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        item.productName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text('${item.quantity} x ${formatMoney(item.unitPrice)}'),
                      trailing: Text(
                        formatMoney(item.lineTotal),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              const Divider(height: 0),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Expanded(child: Text('Ara Toplam')),
                  Text(formatMoney(sale.subtotal)),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Expanded(child: Text('İndirim')),
                  Text(sale.discount <= 0 ? formatMoney(0) : '- ${formatMoney(sale.discount)}'),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Expanded(child: Text('KDV')),
                  Text(formatMoney(sale.vat)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Toplam',
                      style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  Text(
                    formatMoney(sale.total),
                    style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (canEdit)
                FilledButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    context.goNamed(
                      'sales',
                      extra: SaleEditArgs(sale: sale),
                    );
                  },
                  child: const Text('Satışı Düzenle'),
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final companyId = ref.watch(activeCompanyIdProvider);
    final currentUser = ref.watch(currentUserProvider);
    final isAdmin = currentUser != null && currentUser.role == UserRole.admin;

    if (companyId == null) {
      return const AppScaffold(
        title: 'Satış Listesi',
        body: Center(child: Text('Firma seçilmedi')),
      );
    }

    final salesStream = ref.watch(salesRepositoryProvider).watchSales(companyId);
    final customersAsync = ref.watch(_salesCustomersMapProvider);
    final membersAsync = ref.watch(_companyMembersMapProvider);

    return AppScaffold(
      title: 'Satış Listesi',
      body: StreamBuilder<List<Sale>>(
        stream: salesStream,
        builder: (context, snapshot) {
          final sales = snapshot.data ?? const <Sale>[];

          if (snapshot.connectionState == ConnectionState.waiting && sales.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (sales.isEmpty) {
            return const Center(child: Text('Henüz satış yok'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: sales.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final sale = sales[index];

              final customersMap = customersAsync.asData?.value ?? const <String, Customer>{};
              final customer = sale.customerId == null ? null : customersMap[sale.customerId!];

              final isMuhtelif = sale.paymentMethod == 'cash' || sale.paymentMethod == 'card';
              final customerLabel = isMuhtelif ? 'Muhtelif' : (customer?.name ?? 'Cari');

              final membersMap = membersAsync.asData?.value ?? const <String, CompanyMember>{};
              final createdByLabel = membersMap[sale.meta.createdBy]?.displayName.trim().isNotEmpty == true
                  ? membersMap[sale.meta.createdBy]!.displayName
                  : sale.meta.createdBy;

              return Card(
                child: ListTile(
                  title: Text(
                    customerLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    'Tutar: ${formatMoney(sale.total)} • Kullanıcı: $createdByLabel',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Text(
                    _paymentLabel(sale.paymentMethod),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  onTap: () async {
                    await _showSaleDetails(
                      context,
                      ref,
                      sale,
                      customerLabel: customerLabel,
                      createdByLabel: createdByLabel,
                      canEdit: isAdmin,
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
