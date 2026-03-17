import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/active_company_provider.dart';
import '../domain/company_memberships_provider.dart';

class NoCompanyPage extends ConsumerWidget {
  const NoCompanyPage({super.key});

  Future<void> _joinByCode(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();

    final companyCode = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Davet kodu ile katıl'),
          content: TextField(
            controller: controller,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Firma Kodu',
              hintText: 'Örn: ABC123',
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text),
              child: const Text('Gönder'),
            ),
          ],
        );
      },
    );

    final trimmed = (companyCode ?? '').trim();
    if (trimmed.isEmpty) return;

    final functions = ref.read(firebaseFunctionsProvider);
    final callable = functions.httpsCallable('joinCompanyByCode');

    try {
      final res = await callable(<String, dynamic>{
        'companyCode': trimmed,
      });

      final data = res.data;
      if (data is Map) {
        final status = (data['status'] as String?) ?? 'pending';

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                status == 'active'
                    ? 'Firmaya katıldınız.'
                    : 'Üyelik isteği gönderildi. Onay bekleniyor.',
              ),
            ),
          );
        }
      }
    } on FirebaseFunctionsException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('İstek gönderilemedi: ${e.message ?? e.code}')),
      );
    }
  }

  Future<void> _createCompany(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();

    final name = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Firma oluştur'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Firma Adı',
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text),
              child: const Text('Oluştur'),
            ),
          ],
        );
      },
    );

    final trimmed = (name ?? '').trim();
    if (trimmed.isEmpty) return;

    final functions = ref.read(firebaseFunctionsProvider);
    final callable = functions.httpsCallable('createCompany');

    try {
      final res = await callable(<String, dynamic>{
        'name': trimmed,
      });

      final data = res.data;
      if (data is Map) {
        final companyId = data['companyId'] as String?;
        final companyCode = data['companyCode'] as String?;

        if (companyId != null && companyId.isNotEmpty) {
          await ref
              .read(activeCompanyIdProvider.notifier)
              .setActiveCompanyId(companyId);

          if (context.mounted) {
            if (companyCode != null && companyCode.isNotEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Firma kodu: $companyCode')),
              );
            }
            context.go('/dashboard');
          }
        }
      }
    } on FirebaseFunctionsException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Firma oluşturulamadı: ${e.message ?? e.code}')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.business_outlined, size: 48),
            const SizedBox(height: 16),
            const Text(
              'Henüz bir firmaya bağlı değilsiniz',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Davet kodu ile bir firmaya katılabilir veya yeni bir firma oluşturabilirsiniz.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => _createCompany(context, ref),
              child: const Text('Firma oluştur'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => _joinByCode(context, ref),
              child: const Text('Davet kodu ile katıl'),
            ),
          ],
        ),
      ),
    );
  }
}
