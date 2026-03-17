import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_scaffold.dart';
import '../../company/domain/active_company_provider.dart';
import '../domain/auth_controller.dart';
import '../domain/firebase_auth_controller.dart';

class AccountPage extends ConsumerStatefulWidget {
  const AccountPage({super.key});

  @override
  ConsumerState<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends ConsumerState<AccountPage> {
  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _newPasswordAgainController =
      TextEditingController();

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _newPasswordAgainController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    final currentPassword = _currentPasswordController.text;
    final newPassword = _newPasswordController.text;
    final newPasswordAgain = _newPasswordAgainController.text;

    if (newPassword != newPasswordAgain) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Yeni şifreler eşleşmiyor'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (newPassword.trim().length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Yeni şifre en az 6 karakter olmalı'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final controller = ref.read(authControllerProvider.notifier);
    final ok = await controller.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );

    if (!mounted) return;

    final state = ref.read(authControllerProvider);

    if (!ok) {
      final msg = state.errorMessage;
      if (msg != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    _currentPasswordController.clear();
    _newPasswordController.clear();
    _newPasswordAgainController.clear();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Şifre güncellendi'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authUser = ref.watch(authStateProvider).asData?.value;
    final activeCompanyId = ref.watch(activeCompanyIdProvider);
    final authState = ref.watch(authControllerProvider);

    return AppScaffold(
      title: 'Hesabım',
      actions: [
        IconButton(
          icon: const Icon(Icons.logout),
          tooltip: 'Çıkış Yap',
          onPressed: () async {
            await ref.read(firebaseAuthControllerProvider.notifier).signOut();
          },
        ),
      ],
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
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
                ref.read(activeCompanyIdProvider.notifier).clear();
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
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Şifre Değiştir',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _currentPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Mevcut şifre',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _newPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Yeni şifre',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _newPasswordAgainController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Yeni şifre (tekrar)',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) {
                        if (!authState.isLoading) {
                          _changePassword();
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: authState.isLoading ? null : _changePassword,
                        child: Text(
                          authState.isLoading
                              ? 'Güncelleniyor...'
                              : 'Şifreyi Güncelle',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}