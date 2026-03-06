import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/app_button.dart';
import '../../auth/domain/auth_controller.dart';
import '../../auth/domain/user.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _passwordFocusNode = FocusNode();

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final authController = ref.read(authControllerProvider.notifier);
    final success = await authController.login(
      _usernameController.text.trim(),
      _passwordController.text,
    );

    final state = ref.read(authControllerProvider);

    if (!success) {
      if (state.errorMessage != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(state.errorMessage!),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    if (!mounted) return;

    final user = state.currentUser;
    if (user == null) return;

    if (user.role == UserRole.admin) {
      context.goNamed('dashboard');
    } else {
      context.goNamed('sales');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Giriş Yap'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 24),
            TextField(
              controller: _usernameController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Kullanıcı adı',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) {
                _passwordFocusNode.requestFocus();
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              focusNode: _passwordFocusNode,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Şifre',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: AppButton(
                label: authState.isLoading ? 'Giriş yapılıyor...' : 'Giriş Yap',
                onPressed: authState.isLoading ? null : _submit,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'İlk giriş için varsayılan yönetici:\nKullanıcı adı: admin\nŞifre: admin123',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}