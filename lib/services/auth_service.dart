import 'package:firebase_auth/firebase_auth.dart';

/// The "front desk" for every Firebase Authentication call.
///
/// Widgets never talk to FirebaseAuth directly; they call this service so
/// auth rules live in one place.
class AuthService {
  AuthService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  /// Created once and cached so a StreamBuilder is not re-subscribed to a
  /// brand-new stream on every rebuild. Emits a User when signed in and null
  /// when signed out (including the restored session on app start).
  late final Stream<User?> authStateChanges = _auth.authStateChanges();

  /// The currently signed-in user, or null.
  User? get currentUser => _auth.currentUser;

  /// Creates an account. Firebase signs the new user in automatically.
  Future<UserCredential> register(String email, String password) {
    return _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Signs in an existing email/password user.
  Future<UserCredential> signIn(String email, String password) {
    return _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Signs out. authStateChanges then emits null and AuthGate shows sign-in.
  Future<void> signOut() => _auth.signOut();

  /// Updates the signed-in user's password.
  ///
  /// May throw FirebaseAuthException(code: 'requires-recent-login') when the
  /// last sign-in is too old; the UI then calls
  /// [reauthenticateAndChangePassword].
  Future<void> changePassword(String newPassword) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('A signed-in user is required to change a password.');
    }
    await user.updatePassword(newPassword);
  }

  /// Confirms identity with the current password (re-authentication).
  Future<void> reauthenticate(String currentPassword) async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null || email.isEmpty) {
      throw StateError('A signed-in email/password user is required.');
    }
    final credential = EmailAuthProvider.credential(
      email: email,
      password: currentPassword,
    );
    await user.reauthenticateWithCredential(credential);
  }

  /// Recovery path for 'requires-recent-login': re-authenticate, then retry
  /// the password update once. Passwords are never logged or stored.
  Future<void> reauthenticateAndChangePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await reauthenticate(currentPassword);
    await changePassword(newPassword);
  }

  /// Optional stretch: sends a password-reset email.
  Future<void> sendPasswordResetEmail(String email) {
    return _auth.sendPasswordResetEmail(email: email.trim());
  }
}
