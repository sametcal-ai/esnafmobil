import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/migration/migration_state_provider.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../auth/domain/firebase_auth_controller.dart';
import '../domain/active_company_provider.dart';
import '../domain/company_gate_logic.dart';
import '../domain/company_memberships_provider.dart';
import 'no_company_page.dart';
import 'pending_approval_page.dart';
import 'select_company_page.dart';

final connectivityResultProvider =
    FutureProvider.autoDispose<ConnectivityResult>((ref) async {
  final dynamic results = await Connectivity().checkConnectivity();
  if (results is List<ConnectivityResult>) {
    return results.isEmpty ? ConnectivityResult.none : results.first;
  }
  return results as ConnectivityResult;
});

class CompanyGatePage extends ConsumerWidget {
  const CompanyGatePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(activeCompanyResetterProvider);

    final memberships = ref.watch(companyMembershipsProvider);
    final activeCompanyId = ref.watch(activeCompanyIdProvider);
    final authUser = ref.watch(authStateProvider).value;
    final migrationState = ref.watch(migrationStateProvider);

    // Active company seçilmiş ve migrasyon tamamlanmamışsa gate içinde migrasyon UI'si göster.
    if (authUser != null && activeCompanyId != null &&
        migrationState.status != MigrationStatus.done) {
      return AppScaffold(
        title: 'Migrasyon',
        body: _MigrationBody(companyId: activeCompanyId),
      );
    }

    return AppScaffold(
      title: 'Firma',
      body: memberships.when(
        data: (items) {
          final hasAnyMembership = items.isNotEmpty;

          // İlk kurulumda cache boş olabilir. Bu durumda offline ise kullanıcıyı yönlendir.
          if (!hasAnyMembership) {
            final connectivity = ref.watch(connectivityResultProvider).value;
            if (connectivity == ConnectivityResult.none) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'İlk kurulum / ilk firma bağlanma için internete bağlanın.',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
          }

          final decision = decideCompanyGate(
            memberships: items,
            currentActiveCompanyId: activeCompanyId,
          );

          if (decision.autoSelectCompanyId != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ref.read(activeCompanyIdProvider.notifier).state =
                  decision.autoSelectCompanyId;
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

class _MigrationBody extends ConsumerWidget {
  final String companyId;

  const _MigrationBody({
    required this.companyId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(migrationStateProvider);
    final authUser = ref.watch(authStateProvider).value;

    final progress = state.progress;
    final phase = progress?.phase ?? 'starting';
    final migrated = progress?.migrated ?? 0;
    final total = progress?.total ?? 0;

    Widget content;

    switch (state.status) {
      case MigrationStatus.error:
        content = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Migrasyon tamamlanamadı.'),
            const SizedBox(height: 12),
            Text(state.errorMessage ?? 'Bilinmeyen hata'),
            const SizedBox(height: 16),
            AppButton(
              label: 'Tekrar Dene',
              onPressed: () {
                ref.read(migrationStateProvider.notifier).retry(
                      isLoggedIn: authUser != null,
                      companyId: companyId,
                    );
              },
            ),
          ],
        );
        break;
      case MigrationStatus.done:
        content = const CircularProgressIndicator();
        break;
      case MigrationStatus.running:
      case MigrationStatus.idle:
        content = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Migrasyon yapılıyor...'),
            const SizedBox(height: 12),
            Text('$phase: $migrated / $total'),
            const SizedBox(height: 16),
            SizedBox(
              width: 220,
              child: LinearProgressIndicator(
                value: progress == null ? null : progress.ratio,
              ),
            ),
          ],
        );
        break;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: content,
      ),
    );
  }
}