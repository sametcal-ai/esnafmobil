import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_scaffold.dart';
import '../../company/domain/active_company_provider.dart';
import '../domain/firebase_auth_controller.dart';

class AccountPage extends ConsumerWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authUser = ref.watch(authStateProvider).value;
    final activeCompanyId = ref.watch(activeCompanyIdProvider);

    return AppScaffold(
      title: 'Hesabım',
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.person_outline),
                ),
                title: Text(authUser?.email ?? '—'),
                subtitle: Text(
                  activeCompanyId == null
                      ? 'Aktif firma seçilmedi'
                      : 'Aktif firma: $activeCompanyId',
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                ref.read(activeCompanyIdProvider.notifier).state = null;
              },
              child: const Text('Firma Değiştir'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () async {
                await ref.read(firebaseAuthControllerProvider.notifier).signOut();
              },
              child: const Text('Çıkış Yap'),
            ),
          ],
        ),
      ),
    );
  }
}