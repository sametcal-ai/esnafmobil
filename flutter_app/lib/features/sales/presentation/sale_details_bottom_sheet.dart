import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/money_formatter.dart';
import '../../company/domain/active_company_provider.dart';
import '../data/sales_repository.dart';
import 'sale_edit_args.dart';

String paymentMethodLabel(String method) {
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

Future<void> showSaleDetailsBottomSheet(
  BuildContext context,
  WidgetRef ref,
  Sale sale, {
  required String customerLabel,
  required String createdByLabel,
  required bool canEdit,
  required bool canCancel,
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
            Text('Ödeme: ${paymentMethodLabel(sale.paymentMethod)}'),
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
                    'sale_edit',
                    extra: SaleEditArgs(sale: sale),
                  );
                },
                child: const Text('Satışı Düzenle'),
              ),
            if (canCancel) ...[
              const SizedBox(height: 8),
              FilledButton.tonal(
                style: FilledButton.styleFrom(
                  foregroundColor: Colors.red.shade700,
                ),
                onPressed: () async {
                  final navigator = Navigator.of(ctx);

                  final confirmed = await showDialog<bool>(
                    context: ctx,
                    builder: (context) {
                      return AlertDialog(
                        title: const Text('Satışı iptal et'),
                        content: const Text(
                          'Bu satış iptal edilecek. Bu işlem geri alınamaz. Devam edilsin mi?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text('Vazgeç'),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade700,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () => Navigator.of(context).pop(true),
                            child: const Text('İptal Et'),
                          ),
                        ],
                      );
                    },
                  );

                  if (confirmed != true) return;

                  final companyId = ref.read(activeCompanyIdProvider);
                  if (companyId == null) return;

                  final ok = await ref.read(salesRepositoryProvider).softDeleteSaleCascade(
                        companyId: companyId,
                        sale: sale,
                      );

                  if (!ctx.mounted) return;

                  if (!ok) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(
                        content: Text('Satış iptal edilemedi'),
                        behavior: SnackBarBehavior.floating,
                        duration: Duration(seconds: 2),
                      ),
                    );
                    return;
                  }

                  navigator.pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Satış iptal edildi'),
                      behavior: SnackBarBehavior.floating,
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                child: const Text('Satışı İptal Et'),
              ),
            ],
          ],
        ),
      );
    },
  );
}
