import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';


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
import 'sale_details_bottom_sheet.dart';

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
                    paymentMethodLabel(sale.paymentMethod),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  onTap: () async {
                    await showSaleDetailsBottomSheet(
                      context,
                      ref,
                      sale,
                      customerLabel: customerLabel,
                      createdByLabel: createdByLabel,
                      canEdit: isAdmin,
                      canCancel: isAdmin,
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
