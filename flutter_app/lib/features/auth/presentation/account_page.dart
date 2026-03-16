import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_scaffold.dart';
import '../../company_context/domain/company_context_controller.dart';
import '../domain/auth_controller.dart';
import '../domain/user.dart';

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
  bool _isSaving = false;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _newPasswordAgainController.dispose();
    super.dispose();
  }

  Future<void> _handleChangePassword() async {
    final current = _currentPasswordController.text.trim();
    final next = _newPasswordController.text.trim();
    final nextAgain = _newPasswordAgainController.text.trim();

    if (current.isEmpty || next.isEmpty || nextAgain.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tüm alanları doldurun'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (next != nextAgain) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Yeni şifreler birbiriyle uyuşmuyor'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final controller = ref.read(authControllerProvider.notifier);
    final success = await controller.changePassword(
      currentPassword: current,
      newPassword: next,
    );

    if (!mounted) return;

    setState(() {
      _isSaving = false;
    });

    if (!success) {
      final msg = ref.read(authControllerProvider).errorMessage;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg ?? 'Şifre güncellenemedi'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    _currentPasswordController.clear();
    _newPasswordController.clear();
    _newPasswordAgainController.clear();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Şifre başarıyla güncellendi'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);

    return AppScaffold(
      title: 'Hesabım',
      actions: [
        IconButton(
          icon: const Icon(Icons.logout),
          tooltip: 'Çıkış Yap',
          onPressed: () async {
            await ref.read(authControllerProvider.notifier).logout();
          },
        ),
      ],
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: user == null
            ? const Center(
                child: Text('Kullanıcı bilgisi bulunamadı'),
              )
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.person_outline),
                        ),
                        title: Text(user.email),
                        subtitle: Text(
                          user.role == UserRole.admin ? 'Yönetici' : 'Kasiyer',
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Hesap Ayarları',
                      style:
                          Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Şifre Değiştir',
                      style:
                          Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                    ),
                    const SizedBox(height: 8),
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
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _handleChangePassword,
                        child: Text(
                          _isSaving ? 'Kaydediliyor...' : 'Kaydet',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}