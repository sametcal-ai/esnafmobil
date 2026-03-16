import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/firebase_auth_repository.dart';

class AuthState {
  final fb.User? firebaseUser;
  final bool isLoading;
  final String? errorMessage;

  const AuthState({
    required this.firebaseUser,
    required this.isLoading,
    required this.errorMessage,
  });

  bool get isAuthenticated => firebaseUser != null;

  factory AuthState.initial() {
    return const AuthState(
      firebaseUser: null,
      isLoading: false,
      errorMessage: null,
    );
  }

  AuthState copyWith({
    fb.User? firebaseUser,
    bool? isLoading,
    String? errorMessage,
  }) {
    return AuthState(
      firebaseUser: firebaseUser ?? this.firebaseUser,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class AuthController extends StateNotifier<AuthState> {
  final FirebaseAuthRepository _repository;
  StreamSubscription<fb.User?>? _sub;

  AuthController(this._repository) : super(AuthState.initial()) {
    _sub = _repository.authStateChanges().listen((user) {
      state = state.copyWith(firebaseUser: user, errorMessage: null);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      await _repository.signInWithEmailPassword(
        email: email,
        password: password,
      );
      state = state.copyWith(isLoading: false, errorMessage: null);
      return true;
    } on fb.FirebaseAuthException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.message ?? 'Giriş başarısız',
      );
      return false;
    }
  }

  Future<bool> register(String email, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      await _repository.registerWithEmailPassword(
        email: email,
        password: password,
      );
      state = state.copyWith(isLoading: false, errorMessage: null);
      return true;
    } on fb.FirebaseAuthException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.message ?? 'Kayıt başarısız',
      );
      return false;
    }
  }

  Future<void> logout() async {
    await _repository.signOut();
    state = AuthState.initial();
  }

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      await _repository.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      state = state.copyWith(isLoading: false, errorMessage: null);
      return true;
    } on fb.FirebaseAuthException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.message ?? 'Şifre güncellenemedi',
      );
      return false;
    }
  }
}

final firebaseAuthProvider = Provider<fb.FirebaseAuth>((ref) {
  return fb.FirebaseAuth.instance;
});

final firebaseAuthRepositoryProvider = Provider<FirebaseAuthRepository>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  return FirebaseAuthRepository(auth);
});

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  final repo = ref.watch(firebaseAuthRepositoryProvider);
  return AuthController(repo);
});