import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firestore/firestore_refs.dart';
import '../../../core/firestore/models/company_member.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../company/domain/active_company_provider.dart';
import '../../company/domain/company_memberships_provider.dart';
import '../domain/current_user_provider.dart';
import '../domain/firebase_auth_controller.dart';
import '../domain/user.dart';

class UserDetailPage extends ConsumerStatefulWidget {
  final String uid;

  const UserDetailPage({
    super.key,
    required this.uid,
  });

  @override
  ConsumerState<UserDetailPage> createState() => _UserDetailPageState();
}

class _UserDetailPageState extends ConsumerState<UserDetailPage> {
  final _displayNameController = TextEditingController();

  String? _role;
  bool? _isActive;
  bool _dirty = false;

  @override
  void dispose() {
    _displayNameController.dispose();
    super.dispose();
  }

  void _hydrateFromMember(CompanyMember m) {
    if (_dirty) return;

    _displayNameController.text = m.displayName;
    _role = m.role.isEmpty ? 'cashier' : m.role;
    _isActive = m.status == 'active';
  }

  Future<void> _save({
    required BuildContext context,
    required WidgetRef ref,
    required String companyId,
  }) async {
    final displayName = _displayNameController.text.trim();
    final role = _role;
    final isActive = _isActive;

    if (role == null || isActive == null) return;

    final auth = ref.read(firebaseAuthProvider);

    final app = Firebase.app();
    debugPrint('updateMember: projectId=${app.options.projectId}');

    await auth.currentUser?.reload();
    final idToken = await auth.currentUser?.getIdToken(true);

    final functions = ref.read(firebaseFunctionsProvider);
    final callable = functions.httpsCallable('updateMember');

    try {
      await callable(<String, dynamic>{
        'companyId': companyId,
        'uid': widget.uid,
        'displayName': displayName,
        'role': role,
        'active': isActive,
        if (idToken != null) 'idToken': idToken,
      });

      if (!context.mounted) return;
      setState(() => _dirty = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kullanıcı güncellendi.')),
      );
    } on FirebaseFunctionsException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Güncelleme başarısız: ${e.message ?? e.code}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final companyId = ref.watch(activeCompanyIdProvider);
    final currentUser = ref.watch(currentUserProvider);

    if (companyId == null) {
      return const AppScaffold(
        title: 'Kullanıcı Detayı',
        body: Center(child: Text('Aktif firma seçili değil.')),
      );
    }

    if (currentUser == null || currentUser.role != UserRole.admin) {
      return const AppScaffold(
        title: 'Kullanıcı Detayı',
        body: Center(child: Text('Bu sayfaya erişim için admin yetkisi gerekli.')),
      );
    }

    if (currentUser.id == widget.uid) {
      return const AppScaffold(
        title: 'Kullanıcı Detayı',
        body: Center(child: Text('Admin hesabı kendi kullanıcısını bu ekrandan düzenleyemez.')),
      );
    }

    final refs = ref.watch(firestoreRefsProvider);
    final memberStream = refs.member(companyId, widget.uid).snapshots();

    return AppScaffold(
      title: 'Kullanıcı Detayı',
      body: StreamBuilder<DocumentSnapshot<CompanyMember>>(
        stream: memberStream,
        builder: (context, snap) {
          if (snap.hasError) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Yüklenemedi: ${snap.error}'),
            );
          }

          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final doc = snap.data!;
          if (!doc.exists) {
            return const Center(child: Text('Kullanıcı bulunamadı.'));
          }

          final member = doc.data()!;
          _hydrateFromMember(member);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        member.email.isNotEmpty ? member.email : member.uid,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text('uid: ${member.uid}'),
                      const SizedBox(height: 8),
                      Text('mevcut durum: ${member.status}'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _displayNameController,
                decoration: const InputDecoration(
                  labelText: 'Display Name',
                ),
                onChanged: (_) => setState(() => _dirty = true),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _role,
                items: const [
                  DropdownMenuItem(value: 'cashier', child: Text('Cashier')),
                  DropdownMenuItem(value: 'admin', child: Text('Admin')),
                ],
                onChanged: (v) {
                  setState(() {
                    _role = v;
                    _dirty = true;
                  });
                },
                decoration: const InputDecoration(
                  labelText: 'Role',
                ),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Aktif'),
                value: _isActive ?? true,
                onChanged: (v) {
                  setState(() {
                    _isActive = v;
                    _dirty = true;
                  });
                },
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _dirty
                    ? () => _save(context: context, ref: ref, companyId: companyId)
                    : null,
                child: const Text('Kaydet'),
              ),
            ],
          );
        },
      ),
    );
  }
}
