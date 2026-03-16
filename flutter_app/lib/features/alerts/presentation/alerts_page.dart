import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firestore/firestore_refs.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../company/domain/active_company_provider.dart';
import '../../company/domain/company_memberships_provider.dart';

class AlertsPage extends ConsumerWidget {
  const AlertsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final companyId = ref.watch(activeCompanyIdProvider);
    if (companyId == null) {
      return const AppScaffold(
        title: 'Uyarılar',
        body: Center(child: Text('Firma seçili değil')),
      );
    }

    final refs = ref.watch(firestoreRefsProvider);
    final query = refs
        .alerts(companyId)
        .orderBy('createdAt', descending: true)
        .limit(50);

    return AppScaffold(
      title: 'Stok Uyarıları',
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: query.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('Hata: ${snapshot.error}'),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('Uyarı yok'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();

              if ((data['type'] as String?) != 'oversold') {
                return const SizedBox.shrink();
              }

              final saleId = (data['saleId'] as String?) ?? '';
              final status = (data['status'] as String?) ?? 'open';

              final itemsRaw = data['items'];
              final items = <Map<String, dynamic>>[];
              if (itemsRaw is List) {
                for (final i in itemsRaw.whereType<Map>()) {
                  items.add(Map<String, dynamic>.from(i));
                }
              }

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Oversold',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                          Text(
                            status,
                            style: TextStyle(
                              color: status == 'open' ? Colors.redAccent : Colors.grey.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Sale: $saleId'),
                      const SizedBox(height: 8),
                      ...items.map((i) {
                        final productId = (i['productId'] as String?) ?? '';
                        final requestedQty = (i['requestedQty'] as num?)?.toInt() ?? 0;
                        final stockAfter = (i['stockAfter'] as num?)?.toInt() ?? 0;

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            '- $productId | qty: $requestedQty | stockAfter: $stockAfter',
                            style: const TextStyle(fontFamily: 'monospace'),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
