import 'package:firebase_auth/firebase_auth.dart' as fb;

class FirebaseAuthRepository {
  final fb.FirebaseAuth _auth;

  FirebaseAuthRepository(this._auth);

  Stream<fb.User?> authStateChanges() => _auth.authStateChanges();

  Future<fb.UserCredential> signInWithEmailPassword({
    required String email,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<fb.UserCredential> registerWithEmailPassword({
    required String email,
    required String password,
  }) {
    return _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() => _auth.signOut();

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      throw StateError('No authenticated user');
    }

    final credential = fb.EmailAuthProvider.credential(
      email: email,
      password: currentPassword,
    );

    await user.reauthenticateWithCredential(credential);
    await user.updatePassword(newPassword);
  }
}
