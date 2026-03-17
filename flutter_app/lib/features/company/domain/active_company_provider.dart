import 'package:flutter_riverpod/legacy.dart';

import '../../auth/domain/firebase_auth_controller.dart';

final activeCompanyIdProvider = StateProvider<String?>((ref) {
  return null;
});

/// Auth logout olduğunda aktif company context'ini sıfırlar.
///
/// appRouterProvider ve CompanyGatePage gibi yerlerde `ref.watch` edilmesi yeterli;
/// kendisi UI üretmez, sadece side-effect.
final activeCompanyResetterProvider = Provider<void>((ref) {
  ref.listen(authStateProvider, (prev, next) {
    final wasLoggedIn = prev?.value != null;
    final isLoggedIn = next.value != null;

    if (wasLoggedIn && !isLoggedIn) {
      ref.read(activeCompanyIdProvider.notifier).state = null;
    }
  });
});
