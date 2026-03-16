import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_controller.dart';

/// Mevcut oturum açmış Firebase kullanıcısının UID'sini sağlar.
/// Kullanıcı yoksa null döner.
final currentUserIdProvider = Provider<String?>((ref) {
  final auth = ref.watch(authControllerProvider);
  return auth.firebaseUser?.uid;
});
