import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/app_scaffold.dart';
import '../../company/domain/active_company_provider.dart';
import '../domain/pos_controller.dart';
import 'held_sale_card.dart';
import 'held_sales_provider.dart';

class HeldSalesTab extends ConsumerWidget {
  const HeldSalesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final heldSalesAsync = ref.watch(heldSalesProvider);

    return AppScaffold(
      title: 'Bekleyen Satışlar',
      body: heldSalesAsync.when(
        data: (heldSales) {
          return heldSales.isEmpty
              ? const Center(
                  child: Text('Bekleyen satış yok'),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.1,
                  ),
                  itemCount: heldSales.length,
                  itemBuilder: (context, index) {
                    final sale = heldSales[index];
                    return HeldSaleCard(
                      sale: sale,
                      onTap: () => _openSale(context, ref, sale.id),
                      onLongPress: () => _showMenu(context, ref, sale.id),
                    );
                  },
                );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('Bekleyen satışlar okunamadı')),
      ),
    );
  }

  Future<void> _openSale(BuildContext context, WidgetRef ref, String id) async {
    final companyId = ref.read(activeCompanyIdProvider);
    if (companyId == null) return;

    final repo = ref.read(heldSalesRepositoryProvider);
    final sale = await repo.takeSale(companyId, id);
    if (sale == null) return;

    ref.read(posControllerProvider.notifier).loadCartItems(sale.items);

    if (context.mounted) {
      context.goNamed('sales');
    }
  }

  Future<void> _showMenu(BuildContext context, WidgetRef ref, String id) async {
    final result = await showModalBottomSheet<_HeldSaleAction>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.play_arrow_outlined),
                title: const Text('Satışı Aç'),
                onTap: () {
                  Navigator.of(context).pop(_HeldSaleAction.open);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Satışı Sil'),
                onTap: () {
                  Navigator.of(context).pop(_HeldSaleAction.delete);
                },
              ),
            ],
          ),
        );
      },
    );

    if (result == _HeldSaleAction.open) {
      await _openSale(context, ref, id);
      return;
    }

    if (result == _HeldSaleAction.delete) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Satışı Sil'),
            content: const Text('Bu bekleyen satışı silmek istiyor musunuz?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Vazgeç'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Sil'),
              ),
            ],
          );
        },
      );

      if (confirmed == true) {
        final companyId = ref.read(activeCompanyIdProvider);
        if (companyId == null) return;
        await ref.read(heldSalesRepositoryProvider).deleteSale(companyId, id);
      }
    }
  }
}

enum _HeldSaleAction {
  open,
  delete,
}
