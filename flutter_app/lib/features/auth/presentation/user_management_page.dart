import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_scaffold.dart';
import '../data/local_auth_repository.dart';
import '../domain/user.dart';
import '../domain/auth_controller.dart';

class UserManagementPage extends ConsumerStatefulWidget {
  const UserManagementPage({super.key});

  @override
  ConsumerState<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends ConsumerState<UserManagementPage> {
  late final LocalAuthRepository _repository;
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = true;
  List<User> _users = <User>[];

  @override
  void initState() {
    super.initState();
    _repository = ref.read(localAuthRepositoryProvider);
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    final users = await _repository.getAllUsers();
    if (!mounted) return;
    setState(() {
      _users = users;
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _createCashier() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kullanıcı adı ve şifre boş olamaz'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final created = await _repository.createUser(
      username: username,
      password: password,
      role: UserRole.cashier,
      currentUserId: null,
    );

    if (!mounted) return;

    if (created == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bu kullanıcı adı zaten mevcut'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    _usernameController.clear();
    _passwordController.clear();

    setState(() {
      _users = [..._users, created];
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Yeni kasiyer kullanıcısı oluşturuldu'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'User Management',
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _users.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final user = _users[index];
                      return Card(
                        child: ListTile(
                          title: Text(user.username),
                          subtitle: Text(
                            user.role == UserRole.admin ? 'Admin' : 'Cashier',
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const Divider(height: 0),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Yeni kasiyer ekle',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    labelText: 'Kullanıcı adı',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Şifre',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _createCashier,
                    child: const Text('Kasiyer Oluştur'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}