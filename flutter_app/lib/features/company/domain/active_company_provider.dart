import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../auth/domain/firebase_auth_controller.dart';

class ActiveCompanyController extends Notifier<String?> {
  static const _key = 'active_company_id';

  @override
  String? build() {
    Future.microtask(_load);
    return null;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    if (saved != null && saved.isNotEmpty) {
      state = saved;
    }
  }

  Future<void> setActiveCompanyId(String companyId) async {
    state = companyId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, companyId);
  }

  Future<void> clear() async {
    state = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

final activeCompanyIdProvider = NotifierProvider<ActiveCompanyController, String?>(
  ActiveCompanyController.new,
);

/// Auth logout olduğunda aktif company context'ini sıfırlar.
///
/// appRouterProvider ve CompanyGatePage gibi yerlerde `ref.watch` edilmesi yeterli;
/// kendisi UI üretmez, sadece side-effect.
class ActiveCompanyResetter {
  const ActiveCompanyResetter();
}

final activeCompanyResetterProvider = Provider<ActiveCompanyResetter>((ref) {
  ref.listen(authStateProvider, (prev, next) {
    final wasLoggedIn = prev?.asData?.value != null;
    final isLoggedIn = next.asData?.value != null;

    if (wasLoggedIn && !isLoggedIn) {
      ref.read(activeCompanyIdProvider.notifier).clear();
    }
  });

  return const ActiveCompanyResetter();
});
