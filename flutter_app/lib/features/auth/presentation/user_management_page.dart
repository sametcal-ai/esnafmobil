import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_scaffold.dart';

class UserManagementPage extends ConsumerWidget {
  const UserManagementPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const AppScaffold(
      title: 'Kullanıcı Yönetimi',
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Center(
          child: Text(
            'Bu proje Firebase Auth kullanıyor.\n'
            'Kullanıcı oluşturma / yönetme işlemlerini Firebase Console üzerinden\n'
            'veya ayrı bir admin paneli üzerinden yapabilirsiniz.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}