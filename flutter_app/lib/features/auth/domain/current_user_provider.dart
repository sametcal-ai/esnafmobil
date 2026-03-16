import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../company/domain/active_company_provider.dart';
import '../../company/domain/company_memberships_provider.dart';
import 'auth_controller.dart';
import 'user.dart';

/// Mevcut oturum açmış Firebase kullanıcısının UID'sini sağlar.
/// Kullanıcı yoksa null döner.
final currentUserIdProvider = Provider<String?>((ref) {
  final auth = ref.watch(authControllerProvider);
  return auth.firebaseUser?.uid;
});

/// Firebase Auth kullanıcısı + aktif firma üyeliğinden gelen rol ile User üretir.
final currentUserProvider = Provider<User?>((ref) {
  final auth = ref.watch(authControllerProvider);
  final fbUser = auth.firebaseUser;
  if (fbUser == null) return null;

  final companyId = ref.watch(activeCompanyIdProvider);
  final memberships = ref.watch(companyMembershipsProvider).valueOrNull ?? const [];

  final roleStr = memberships
      .where((m) => m.companyId == companyId)
      .map((m) => m.member.role)
      .firstOrNull;

  final role = (roleStr ?? '').toLowerCase() == 'admin' ? UserRole.admin : UserRole.cashier;

  return User(
    id: fbUser.uid,
    email: fbUser.email ?? fbUser.uid,
    role: role,
  );
});

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
