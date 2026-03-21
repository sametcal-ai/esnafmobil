import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/app_scaffold.dart';

class OperationsPage extends StatelessWidget {
  const OperationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cards = <_OperationCardData>[
      _OperationCardData(
        icon: Icons.inventory_outlined,
        title: 'Stok Düzenleme',
        color: Colors.blueGrey.shade700,
        onTap: () => context.pushNamed('stock_adjustment'),
      ),
    ];

    return AppScaffold(
      title: 'İşlemler',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1.1,
          children: [
            for (final c in cards)
              _OperationCard(
                icon: c.icon,
                title: c.title,
                color: c.color,
                onTap: c.onTap,
              ),
          ],
        ),
      ),
    );
  }
}

class _OperationCardData {
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;

  const _OperationCardData({
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
  });
}

class _OperationCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;

  const _OperationCard({
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
