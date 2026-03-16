import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/domain/user.dart';
import '../domain/company_context_controller.dart';

class CompanySelectPage extends ConsumerWidget {
  const CompanySelectPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(companyContextProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Firma Seç'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: state.isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (state.errorMessage != null) ...[
                    Text(
                      state.errorMessage!,
                      style: const TextStyle(color: Colors.red),
                    ),
                    const SizedBox(height: 12),
                  ],
                  const Text(
                    'Üye olduğunuz firmalardan birini seçin',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.separated(
                      itemCount: state.memberships.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final m = state.memberships[index];
                        final isActive = m.companyId == state.activeCompanyId;
                        final role = m.role.toLowerCase() == 'admin'
                            ? UserRole.admin
                            : UserRole.cashier;

                        return Card(
                          child: ListTile(
                            title: Text(m.companyId),
                            subtitle: Text(
                              role == UserRole.admin ? 'Yönetici' : 'Kasiyer',
                            ),
                            trailing:
                                isActive ? const Icon(Icons.check) : null,
                            onTap: () async {
                              await ref
                                  .read(companyContextProvider.notifier)
                                  .setActiveCompany(m.companyId);

                              if (!context.mounted) return;
                              final currentUser = ref.read(currentUserProvider);

                              if (currentUser?.role == UserRole.admin) {
                                context.goNamed('dashboard');
                              } else {
                                context.goNamed('sales');
                              }
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
