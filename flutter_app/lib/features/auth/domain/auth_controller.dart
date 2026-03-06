import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/local_auth_repository.dart';
import 'user.dart';

class AuthState {
  final bool isAuthenticated;
  final User? currentUser;
  final bool isLoading;
  final String? errorMessage;

  const AuthState({
    required this.isAuthenticated,
    required this.currentUser,
    required this.isLoading,
    required this.errorMessage,
  });

  factory AuthState.initial() {
    return const AuthState(
      isAuthenticated: false,
      currentUser: null,
      isLoading: false,
      errorMessage: null,
    );
  }

  AuthState copyWith({
    bool? isAuthenticated,
    User? currentUser,
    bool? isLoading,
    String? errorMessage,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      currentUser: currentUser ?? this.currentUser,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class AuthController extends StateNotifier<AuthState> {
  final LocalAuthRepository _repository;

  AuthController(this._repository) : super(AuthState.initial()) {
    _initialize();
  }

  Future<void> _initialize() async {
    await _repository.ensureDefaultAdminUser();
    final user = await _repository.getCurrentUser();
    if (user != null) {
      state = state.copyWith(
        isAuthenticated: true,
        currentUser: user,
        errorMessage: null,
      );
    }
  }

  Future<bool> login(String username, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    final user = await _repository.authenticate(username, password);
    if (user == null) {
      state = state.copyWith(
        isLoading: false,
        isAuthenticated: false,
        currentUser: null,
        errorMessage: 'Kullanıcı adı veya şifre hatalı',
      );
      return false;
    }

    state = state.copyWith(
      isLoading: false,
      isAuthenticated: true,
      currentUser: user,
      errorMessage: null,
    );
    return true;
  }

  Future<void> logout() async {
    await _repository.clearSession();
    state = AuthState.initial();
  }

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = state.currentUser;
    if (user == null) return false;

    final updated = await _repository.changePassword(
      userId: user.id,
      currentPassword: currentPassword,
      newPassword: newPassword,
    );

    if (updated == null) {
      return false;
    }

    state = state.copyWith(currentUser: updated, errorMessage: null);
    return true;
  }
}

final localAuthRepositoryProvider = Provider<LocalAuthRepository>((ref) {
  return LocalAuthRepository();
});

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  final repo = ref.watch(localAuthRepositoryProvider);
  return AuthController(repo);
});