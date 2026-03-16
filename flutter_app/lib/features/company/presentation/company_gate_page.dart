import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/app_scaffold.dart';
import '../domain/active_company_provider.dart';
import '../domain/company_gate_logic.dart';
import '../domain/company_memberships_provider.dart';
import 'no_company_page.dart';
import 'pending_approval_page.dart';
import 'select_company_page.dart';

class CompanyGatePage extends ConsumerWidget {
  const CompanyGatePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(activeCompanyResetterProvider);

    final memberships = ref.watch(companyMembershipsProvider);
    final activeCompanyId = ref.watch(activeCompanyIdProvider);

    return AppScaffold(
      title: 'Firma',
      body: memberships.when(
        data: (items) {
          final decision = decideCompanyGate(
            memberships: items,
            currentActiveCompanyId: activeCompanyId,
          );

          if (decision.autoSelectCompanyId != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ref.read(activeCompanyIdProvider.notifier).state =
                  decision.autoSelectCompanyId;
              context.go('/dashboard');
            });

            return const Center(child: CircularProgressIndicator());
          }

          switch (decision.route) {
            case CompanyGateRoute.ready:
              WidgetsBinding.instance.addPostFrameCallback((_) {
                context.go('/dashboard');
              });
              return const Center(child: CircularProgressIndicator());
            case CompanyGateRoute.pendingApproval:
              return const PendingApprovalPage();
            case CompanyGateRoute.selectCompany:
              return SelectCompanyPage(
                companyIds: decision.activeCompanyIds,
                onSelect: (companyId) {
                  ref.read(activeCompanyIdProvider.notifier).state = companyId;
                  context.go('/dashboard');
                },
              );
            case CompanyGateRoute.noCompany:
              return const NoCompanyPage();
            case CompanyGateRoute.loading:
              return const Center(child: CircularProgressIndicator());
          }
        },
        error: (e, _) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Üyelik bilgileri yüklenemedi: $e'),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
