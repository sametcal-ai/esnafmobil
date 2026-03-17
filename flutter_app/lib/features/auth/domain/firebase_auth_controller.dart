import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FirebaseAuthState {
  final bool isLoading;
  final String? errorMessage;

  const FirebaseAuthState({
    required this.isLoading,
    required this.errorMessage,
  });

  factory FirebaseAuthState.initial() {
    return const FirebaseAuthState(isLoading: false, errorMessage: null);
  }

  FirebaseAuthState copyWith({
    bool? isLoading,
    String? errorMessage,
  }) {
    return FirebaseAuthState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class FirebaseAuthController extends Notifier<FirebaseAuthState> {
  late final fb.FirebaseAuth _auth;

  @override
  FirebaseAuthState build() {
    _auth = ref.watch(firebaseAuthProvider);
    return FirebaseAuthState.initial();
  }

  Future<bool> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      state = state.copyWith(isLoading: false, errorMessage: null);
      return true;
    } on fb.FirebaseAuthException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
      return false;
    }
  }

  Future<bool> registerWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      state = state.copyWith(isLoading: false, errorMessage: null);
      return true;
    } on fb.FirebaseAuthException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
      return false;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}

final firebaseAuthProvider = Provider<fb.FirebaseAuth>((ref) {
  return fb.FirebaseAuth.instance;
});

final authStateProvider = StreamProvider<fb.User?>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  return auth.authStateChanges();
});

final firebaseAuthControllerProvider =
    NotifierProvider<FirebaseAuthController, FirebaseAuthState>(
  FirebaseAuthController.new,
);
