import 'package:flutter/material.dart';

class SelectCompanyPage extends StatelessWidget {
  const SelectCompanyPage({
    super.key,
    required this.companyIds,
    required this.onSelect,
  });

  final List<String> companyIds;
  final void Function(String companyId) onSelect;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: companyIds.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final companyId = companyIds[index];
        return Card(
          child: ListTile(
            leading: const Icon(Icons.business),
            title: Text(companyId),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => onSelect(companyId),
          ),
        );
      },
    );
  }
}
