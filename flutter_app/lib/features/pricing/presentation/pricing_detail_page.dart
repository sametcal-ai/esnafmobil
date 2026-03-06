import 'package:flutter/material.dart';

import '../../../core/config/money_formatter.dart';
import '../../../core/widgets/app_scaffold.dart';
import 'pricing_page.dart';

class PricingDetailPage extends StatelessWidget {
  final PricingItem item;

  const PricingDetailPage({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final taxAmount = item.salePrice * (item.taxRate / 100);
    final totalWithTax = item.salePrice + taxAmount;

    return AppScaffold(
      title: 'Fiyat Detayı',
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: ListTile(
                title: Text(
                  item.productName,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('Ürün / Fiyat listesi adı'),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _InfoRow(
                      label: 'Alış fiyatı',
                      value: item.purchasePrice,
                    ),
                    const SizedBox(height: 8),
                    _InfoRow(
                      label: 'Satış fiyatı',
                      value: item.salePrice,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'KDV / Vergi oranı',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                        Text('%${item.taxRate.toStringAsFixed(0)}'),
                      ],
                    ),
                    const Divider(height: 24),
                    _InfoRow(
                      label: 'KDV Dahil Toplam',
                      value: totalWithTax,
                      isEmphasized: true,
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Güncelleme işlevi daha sonra eklenecek'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                icon: const Icon(Icons.save_outlined),
                label: const Text('Güncelle (opsiyonel)'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final double value;
  final bool isEmphasized;

  const _InfoRow({
    required this.label,
    required this.value,
    this.isEmphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = isEmphasized
        ? const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
        : const TextStyle(fontSize: 14);

    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: style,
          ),
        ),
        Text(
          formatMoney(value),
          style: style,
        ),
      ],
    );
  }
}