import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/firestore/firestore_refs.dart';
import '../../auth/data/firebase_auth_repository.dart';
import '../../auth/domain/auth_controller.dart';
import '../../auth/domain/user.dart';

class CompanyMembership {
  final String companyId;
  final String role;

  const CompanyMembership({
    required this.companyId,
    required this.role,
  });
}

class CompanyContextState {
  final bool isLoading;
  final List<CompanyMembership> memberships;
  final String? activeCompanyId;
  final String? errorMessage;

  const CompanyContextState({
    required this.isLoading,
    required this.memberships,
    required this.activeCompanyId,
    required this.errorMessage,
  });

  factory CompanyContextState.initial() {
    return const CompanyContextState(
      isLoading: false,
      memberships: <CompanyMembership>[],
      activeCompanyId: null,
      errorMessage: null,
    );
  }

  CompanyContextState copyWith({
    bool? isLoading,
    List<CompanyMembership>? memberships,
    String? activeCompanyId,
    String? errorMessage,
  }) {
    return CompanyContextState(
      isLoading: isLoading ?? this.isLoading,
      memberships: memberships ?? this.memberships,
      activeCompanyId: activeCompanyId ?? this.activeCompanyId,
      errorMessage: errorMessage,
    );
  }

  UserRole? get activeRole {
    final companyId = activeCompanyId;
    if (companyId == null) return null;

    final membership = memberships.where((m) => m.companyId == companyId).firstOrNull;
    if (membership == null) return null;

    return membership.role.toLowerCase() == 'admin' ? UserRole.admin : UserRole.cashier;
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

class CompanyContextController extends StateNotifier<CompanyContextState> {
  CompanyContextController(
    this._firestore,
    this._sessionBox,
    this._auth,
    this._functions,
  ) : super(CompanyContextState.initial()) {
    _sub = _auth.authStateChanges().listen((user) {
      if (user == null) {
        _clear();
      } else {
        _loadMemberships(user.uid);
      }
    });
  }

  static const String _activeCompanyKey = 'activeCompanyId';

  final FirebaseFirestore _firestore;
  final Box _sessionBox;
  final FirebaseAuthRepository _auth;
  final FirebaseFunctions _functions;
  StreamSubscription? _sub;

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _clear() {
    state = CompanyContextState.initial();
    _sessionBox.delete(_activeCompanyKey);
  }

  Future<List<CompanyMembership>> _fallbackMembershipsViaFunction(String uid) async {
    final callable = _functions.httpsCallable('getMyMemberships');
    final res = await callable();

    final data = res.data;
    if (data is! Map) return const <CompanyMembership>[];

    final raw = data['memberships'];
    if (raw is! List) return const <CompanyMembership>[];

    return raw.map((item) {
      if (item is! Map) return null;

      final companyId = item['companyId'];
      final member = item['member'];

      if (companyId is! String || member is! Map) return null;

      final role = (member['role'] as String?) ?? 'cashier';

      return CompanyMembership(
        companyId: companyId,
        role: role,
      );
    }).whereType<CompanyMembership>().toList(growable: false);
  }

  Future<void> _loadMemberships(String uid) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final snap = await _firestore.collectionGroup('members').where('uid', isEqualTo: uid).get();

      final memberships = <CompanyMembership>[];
      for (final doc in snap.docs) {
        final parent = doc.reference.parent.parent;
        if (parent == null) continue;
        final role = (doc.data()['role'] as String?) ?? 'cashier';
        memberships.add(CompanyMembership(companyId: parent.id, role: role));
      }

      await _setMembershipsAndActive(memberships);
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        final memberships = await _fallbackMembershipsViaFunction(uid);
        await _setMembershipsAndActive(memberships);
        return;
      }
      rethrow;
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        memberships: const <CompanyMembership>[],
        activeCompanyId: null,
        errorMessage: 'Firma üyelikleri okunamadı',
      );
    }
  }

  Future<void> _setMembershipsAndActive(List<CompanyMembership> memberships) async {
    final stored = _sessionBox.get(_activeCompanyKey);
    final storedCompanyId = stored is String && stored.isNotEmpty ? stored : null;

    String? active;
    if (storedCompanyId != null && memberships.any((m) => m.companyId == storedCompanyId)) {
      active = storedCompanyId;
    } else if (memberships.isNotEmpty) {
      active = memberships.first.companyId;
      await _sessionBox.put(_activeCompanyKey, active);
    }

    state = state.copyWith(
      isLoading: false,
      memberships: memberships,
      activeCompanyId: active,
      errorMessage: memberships.isEmpty ? 'Bu kullanıcı hiçbir firmaya üye değil' : null,
    );
  }

  Future<void> setActiveCompany(String companyId) async {
    if (!state.memberships.any((m) => m.companyId == companyId)) return;

    await _sessionBox.put(_activeCompanyKey, companyId);
    state = state.copyWith(activeCompanyId: companyId, errorMessage: null);
  }

  FirestoreRefs refs() {
    return FirestoreRefs(_firestore);
  }
}

final firebaseFirestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

final firebaseFunctionsProvider = Provider<FirebaseFunctions>((ref) {
  return FirebaseFunctions.instance;
});

final sessionBoxProvider = Provider<Box>((ref) {
  return Hive.box('session');
});

final companyContextProvider =
    StateNotifierProvider<CompanyContextController, CompanyContextState>((ref) {
  final firestore = ref.watch(firebaseFirestoreProvider);
  final sessionBox = ref.watch(sessionBoxProvider);
  final authRepo = ref.watch(firebaseAuthRepositoryProvider);
  final functions = ref.watch(firebaseFunctionsProvider);

  return CompanyContextController(firestore, sessionBox, authRepo, functions);
});

final activeCompanyIdProvider = Provider<String?>((ref) {
  return ref.watch(companyContextProvider).activeCompanyId;
});

final currentUserProvider = Provider<User?>((ref) {
  final auth = ref.watch(authControllerProvider);
  final fbUser = auth.firebaseUser;
  if (fbUser == null) return null;

  final company = ref.watch(companyContextProvider);
  final role = company.activeRole ?? UserRole.cashier;

  return User(
    id: fbUser.uid,
    email: fbUser.email ?? fbUser.uid,
    role: role,
  );
});
