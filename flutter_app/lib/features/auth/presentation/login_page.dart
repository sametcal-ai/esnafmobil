import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_button.dart';
import '../domain/auth_controller.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _passwordFocusNode = FocusNode();

  bool _isRegister = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final controller = ref.read(authControllerProvider.notifier);

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    final success = _isRegister
        ? await controller.register(email, password)
        : await controller.login(email, password);

    final state = ref.read(authControllerProvider);

    if (!success) {
      final msg = state.errorMessage;
      if (msg != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    // Yönlendirme GoRouter.redirect içinde yapılacak (firma seçimi dahil).
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isRegister ? 'Kayıt Ol' : 'Giriş Yap'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 24),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'E-posta',
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
                label: authState.isLoading
                    ? (_isRegister ? 'Kayıt yapılıyor...' : 'Giriş yapılıyor...')
                    : (_isRegister ? 'Kayıt Ol' : 'Giriş Yap'),
                onPressed: authState.isLoading ? null : _submit,
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: authState.isLoading
                  ? null
                  : () {
                      setState(() {
                        _isRegister = !_isRegister;
                      });
                    },
              child: Text(
                _isRegister
                    ? 'Zaten hesabın var mı? Giriş Yap'
                    : 'Hesabın yok mu? Kayıt Ol',
              ),
            ),
          ],
        ),
      ),
    );
  }
}