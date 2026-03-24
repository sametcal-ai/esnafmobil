import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_settings.dart';
import '../../../core/config/money_formatter.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../auth/domain/user.dart';
import '../../auth/domain/current_user_provider.dart' show currentUserProvider;
import '../../company/domain/active_company_provider.dart';
import '../../sales/data/sales_repository.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  DateTime _startOfDay(DateTime dt) {
    return DateTime(dt.year, dt.month, dt.day);
  }

  DateTime _startOfWeek(DateTime dt) {
    // Pazartesi başlangıç (ISO)
    final normalized = _startOfDay(dt);
    final diff = normalized.weekday - DateTime.monday;
    return normalized.subtract(Duration(days: diff));
  }

  DateTime _startOfMonth(DateTime dt) {
    return DateTime(dt.year, dt.month, 1);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);
    final isAdmin = currentUser != null && currentUser.role == UserRole.admin;

    final settings = ref.watch(appSettingsProvider);
    final companyId = ref.watch(activeCompanyIdProvider);

    final menuCards = <_DashboardCard>[
      _DashboardCard(
        icon: Icons.inventory_2_outlined,
        title: 'Ürünler',
        color: Colors.blue.shade600,
        onTap: () => context.pushNamed('products'),
      ),
      _DashboardCard(
        icon: Icons.people_alt_outlined,
        title: 'Müşteriler',
        color: Colors.green.shade600,
        onTap: () => context.pushNamed('customers'),
      ),
      _DashboardCard(
        icon: Icons.local_shipping_outlined,
        title: 'Tedarikçiler',
        color: Colors.orange.shade600,
        onTap: () => context.pushNamed('suppliers'),
      ),
      _DashboardCard(
        icon: Icons.price_change_outlined,
        title: 'Fiyat Listeleri',
        color: Colors.purple.shade600,
        onTap: () => context.pushNamed('pricing'),
      ),
      _DashboardCard(
        icon: Icons.settings_outlined,
        title: 'Sistem Ayarları',
        color: Colors.teal.shade600,
        onTap: () => context.pushNamed('settings'),
      ),
    ];

    if (isAdmin) {
      menuCards.addAll([
        _DashboardCard(
          icon: Icons.playlist_add_check_outlined,
          title: 'İşlemler',
          color: Colors.brown.shade600,
          onTap: () => context.pushNamed('operations'),
        ),
        _DashboardCard(
          icon: Icons.warning_amber_rounded,
          title: 'Stok Uyarıları',
          color: Colors.red.shade700,
          onTap: () => context.pushNamed('alerts'),
        ),
        _DashboardCard(
          icon: Icons.manage_accounts_outlined,
          title: 'Kullanıcı Yönetimi',
          color: Colors.indigo.shade600,
          onTap: () => context.pushNamed('users'),
        ),
      ]);
    }

    final salesStream = companyId == null
        ? const Stream<List<Sale>>.empty()
        : ref.watch(salesRepositoryProvider).watchSales(companyId);

    return AppScaffold(
      title: 'Ana Menü',
      body: StreamBuilder<List<Sale>>(
        stream: salesStream,
        builder: (context, snapshot) {
          final sales = snapshot.data ?? const <Sale>[];
          final now = DateTime.now();

          final dayStart = _startOfDay(now);
          final weekStart = _startOfWeek(now);
          final monthStart = _startOfMonth(now);

          double dailyTotal = 0;
          double weeklyTotal = 0;
          double monthlyTotal = 0;

          if (settings.showSalesMetrics) {
            for (final s in sales) {
              if (s.createdAt.isAfter(dayStart) ||
                  s.createdAt.isAtSameMomentAs(dayStart)) {
                dailyTotal += s.total;
              }
              if (s.createdAt.isAfter(weekStart) ||
                  s.createdAt.isAtSameMomentAs(weekStart)) {
                weeklyTotal += s.total;
              }
              if (s.createdAt.isAfter(monthStart) ||
                  s.createdAt.isAtSameMomentAs(monthStart)) {
                monthlyTotal += s.total;
              }
            }
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (isAdmin) ...[
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Satışlar',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          if (settings.showSalesMetrics) ...[
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _SalesMetricCard(
                                    title: 'Günlük',
                                    value: dailyTotal,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _SalesMetricCard(
                                    title: 'Haftalık',
                                    value: weeklyTotal,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _SalesMetricCard(
                                    title: 'Aylık',
                                    value: monthlyTotal,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                          ] else
                            const SizedBox(height: 12),
                          InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => context.pushNamed('sales_list'),
                            child: Ink(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: Theme.of(context).colorScheme.surfaceVariant,
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.receipt_long_outlined),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Satış Listesi',
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 1.1,
                  children: menuCards,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SalesMetricCard extends StatelessWidget {
  final String title;
  final double value;

  const _SalesMetricCard({
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            formatMoney(value),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;

  const _DashboardCard({
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: color.withOpacity(0.08),
          border: Border.all(
            color: color.withOpacity(0.4),
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 40,
                color: color,
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
