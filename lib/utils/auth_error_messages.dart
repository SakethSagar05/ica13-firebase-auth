import 'package:firebase_auth/firebase_auth.dart';

/// Which auth operation failed. The same Firebase code can deserve a
/// different message depending on what the user was doing.
enum AuthAction { signIn, register, updatePassword, reauthenticate, passwordReset, signOut }

/// Turns any auth error into safe, helpful text. Raw exception text is never
/// shown to the user.
String authErrorMessage(Object error, AuthAction action) {
  if (error is FirebaseAuthException) {
    return messageForCode(error.code, action);
  }
  if (error is StateError) {
    return 'Your session has ended. Please sign in again.';
  }
  return _fallback(action);
}

String messageForCode(String code, AuthAction action) {
  switch (code) {
    case 'invalid-email':
      return 'That email address doesn\'t look right. Check the format (name@example.com).';
    case 'missing-password':
      return 'Enter your password to continue.';
    // Sign-in failures share ONE message so the app never reveals whether
    // an email is registered (privacy-aware, avoids account enumeration).
    case 'user-not-found':
    case 'wrong-password':
    case 'invalid-credential':
    case 'INVALID_LOGIN_CREDENTIALS':
      if (action == AuthAction.reauthenticate) {
        return 'Your current password is incorrect. Try again.';
      }
      if (action == AuthAction.passwordReset) {
        return 'If an account exists for that email, a reset link is on its way.';
      }
      return 'Email or password is incorrect. Check both and try again.';
    case 'user-mismatch':
      return 'That password is for a different account. Enter the password for the account you\'re signed in with.';
    case 'user-disabled':
      return 'This account can\'t sign in right now. Contact support for help.';
    case 'email-already-in-use':
      return 'An account may already exist for this email. Try signing in, or use "Forgot password?" to reset it.';
    case 'weak-password':
      return 'That password is too weak. Use at least 6 characters (this project may require more).';
    case 'password-does-not-meet-requirements':
      return 'That password doesn\'t meet this app\'s password policy. Try a longer password with letters, numbers and symbols.';
    case 'requires-recent-login':
      return 'For your security, confirm your current password to continue.';
    case 'too-many-requests':
      return 'Too many attempts. Wait a few minutes and try again.';
    case 'network-request-failed':
      return 'Can\'t reach the server. Check your internet connection and try again.';
    case 'operation-not-allowed':
      return 'Email/password sign-in isn\'t enabled for this app yet.';
    case 'user-token-expired':
    case 'invalid-user-token':
      return 'Your session has expired. Please sign in again.';
    default:
      return _fallback(action);
  }
}

String _fallback(AuthAction action) {
  switch (action) {
    case AuthAction.signIn:
      return 'Sign-in didn\'t work. Please try again.';
    case AuthAction.register:
      return 'We couldn\'t create your account. Please try again.';
    case AuthAction.updatePassword:
      return 'Your password wasn\'t changed. Please try again.';
    case AuthAction.reauthenticate:
      return 'We couldn\'t confirm your identity. Please try again.';
    case AuthAction.passwordReset:
      return 'We couldn\'t send a reset email right now. Please try again.';
    case AuthAction.signOut:
      return 'Sign-out didn\'t finish. Please try again.';
  }
}
