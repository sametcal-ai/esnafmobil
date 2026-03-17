import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firestore/firestore_refs.dart';
import '../../../core/firestore/models/company_member.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../company/domain/active_company_provider.dart';
import '../../company/domain/company_memberships_provider.dart';
import '../domain/current_user_provider.dart';
import '../domain/user.dart';

class UserManagementPage extends ConsumerWidget {
  const UserManagementPage({super.key});

  Future<void> _approveMember({
    required BuildContext context,
    required WidgetRef ref,
    required String companyId,
    required String uid,
  }) async {
    UserRole? role = UserRole.cashier;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return AlertDialog(
              title: const Text('Kullanıcıyı onayla'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RadioListTile<UserRole>(
                    value: UserRole.cashier,
                    groupValue: role,
                    title: const Text('Cashier'),
                    onChanged: (v) => setState(() => role = v),
                  ),
                  RadioListTile<UserRole>(
                    value: UserRole.admin,
                    groupValue: role,
                    title: const Text('Admin'),
                    onChanged: (v) => setState(() => role = v),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Vazgeç'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('Onayla'),
                ),
              ],
            );
          },
        );
      },
    );

    if (ok != true || role == null) return;

    // Callable functions attach the Firebase Auth ID token automatically.
    // In some cases (fresh emulator, token not yet minted/expired) the call can
    // end up unauthenticated. Force-refresh token before invoking.
    final auth = ref.read(firebaseAuthProvider);
    await auth.currentUser?.getIdToken(true);

    final functions = ref.read(firebaseFunctionsProvider);
    final callable = functions.httpsCallable('approveMember');

    try {
      await callable(<String, dynamic>{
        'companyId': companyId,
        'uid': uid,
        'role': role == UserRole.admin ? 'admin' : 'cashier',
      });
    } on FirebaseFunctionsException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Onay işlemi başarısız: ${e.message ?? e.code}')),
      );
    }
  }

  Future<void> _rejectMember({
    required BuildContext context,
    required WidgetRef ref,
    required String companyId,
    required String uid,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Üyeliği reddet'),
          content: const Text('Bu kullanıcı için bekleyen üyelik isteği silinecek.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Reddet'),
            ),
          ],
        );
      },
    );

    if (ok != true) return;

    final auth = ref.read(firebaseAuthProvider);
    await auth.currentUser?.getIdToken(true);

    final functions = ref.read(firebaseFunctionsProvider);
    final callable = functions.httpsCallable('rejectMember');

    try {
      await callable(<String, dynamic>{
        'companyId': companyId,
        'uid': uid,
      });
    } on FirebaseFunctionsException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reddetme başarısız: ${e.message ?? e.code}')),
      );
    }
  }

  Widget _memberTile({
    required BuildContext context,
    required WidgetRef ref,
    required String companyId,
    required CompanyMember member,
    required bool isPending,
  }) {
    final subtitle = isPending
        ? 'pending'
        : 'active • ${member.role.isEmpty ? '-' : member.role}';

    return ListTile(
      title: Text(member.uid),
      subtitle: Text(subtitle),
      trailing: isPending
          ? Wrap(
              spacing: 8,
              children: [
                OutlinedButton(
                  onPressed: () => _rejectMember(
                    context: context,
                    ref: ref,
                    companyId: companyId,
                    uid: member.uid,
                  ),
                  child: const Text('Reddet'),
                ),
                FilledButton(
                  onPressed: () => _approveMember(
                    context: context,
                    ref: ref,
                    companyId: companyId,
                    uid: member.uid,
                  ),
                  child: const Text('Onayla'),
                ),
              ],
            )
          : null,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final companyId = ref.watch(activeCompanyIdProvider);
    final user = ref.watch(currentUserProvider);

    if (companyId == null) {
      return const AppScaffold(
        title: 'Kullanıcı Yönetimi',
        body: Center(child: Text('Aktif firma seçili değil.')),
      );
    }

    if (user == null || user.role != UserRole.admin) {
      return const AppScaffold(
        title: 'Kullanıcı Yönetimi',
        body: Center(child: Text('Bu sayfaya erişim için admin yetkisi gerekli.')),
      );
    }

    final refs = ref.watch(firestoreRefsProvider);

    final pendingStream = refs
        .members(companyId)
        .where('status', isEqualTo: 'pending')
        .snapshots();

    final activeStream = refs
        .members(companyId)
        .where('status', isEqualTo: 'active')
        .snapshots();

    return AppScaffold(
      title: 'Kullanıcı Yönetimi',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Onay Bekleyenler', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          StreamBuilder<QuerySnapshot<CompanyMember>>(
            stream: pendingStream,
            builder: (context, snap) {
              if (snap.hasError) {
                return Text('Yüklenemedi: ${snap.error}');
              }
              if (!snap.hasData) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final items = snap.data!.docs.map((d) => d.data()).toList();
              if (items.isEmpty) {
                return const Text('Bekleyen kullanıcı yok.');
              }

              return Card(
                child: Column(
                  children: items
                      .map(
                        (m) => _memberTile(
                          context: context,
                          ref: ref,
                          companyId: companyId,
                          member: m,
                          isPending: true,
                        ),
                      )
                      .toList(),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          Text('Aktif Kullanıcılar', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          StreamBuilder<QuerySnapshot<CompanyMember>>(
            stream: activeStream,
            builder: (context, snap) {
              if (snap.hasError) {
                return Text('Yüklenemedi: ${snap.error}');
              }
              if (!snap.hasData) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final items = snap.data!.docs.map((d) => d.data()).toList();
              if (items.isEmpty) {
                return const Text('Aktif kullanıcı yok.');
              }

              return Card(
                child: Column(
                  children: items
                      .map(
                        (m) => _memberTile(
                          context: context,
                          ref: ref,
                          companyId: companyId,
                          member: m,
                          isPending: false,
                        ),
                      )
                      .toList(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}