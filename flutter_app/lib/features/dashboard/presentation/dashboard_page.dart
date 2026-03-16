import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/app_scaffold.dart';
import '../../auth/domain/user.dart';
import '../../company_context/domain/company_context_controller.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);
    final isAdmin = currentUser != null && currentUser.role == UserRole.admin;

    final cards = <_DashboardCard>[
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
      cards.add(
        _DashboardCard(
          icon: Icons.manage_accounts_outlined,
          title: 'Kullanıcı Yönetimi',
          color: Colors.indigo.shade600,
          onTap: () => context.pushNamed('users'),
        ),
      );
    }

    return AppScaffold(
      title: 'Ana Menü',
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1.1,
          children: cards,
        ),
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