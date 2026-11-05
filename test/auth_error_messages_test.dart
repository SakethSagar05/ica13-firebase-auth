import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ica13_firebase_auth/utils/auth_error_messages.dart';

void main() {
  test('sign-in failures share one privacy-aware message', () {
    final notFound = messageForCode('user-not-found', AuthAction.signIn);
    final wrong = messageForCode('wrong-password', AuthAction.signIn);
    final invalid = messageForCode('invalid-credential', AuthAction.signIn);
    expect(notFound, wrong);
    expect(wrong, invalid);
    expect(invalid.toLowerCase(), isNot(contains('not found')));
  });

  test('re-authentication with a wrong password says so clearly', () {
    expect(
      messageForCode('invalid-credential', AuthAction.reauthenticate),
      contains('current password is incorrect'),
    );
  });

  test('email-already-in-use points to sign-in / reset', () {
    expect(
      messageForCode('email-already-in-use', AuthAction.register),
      contains('signing in'),
    );
  });

  test('raw exception text is never shown', () {
    final error = FirebaseAuthException(
      code: 'some-internal-code',
      message: 'INTERNAL STACK DETAILS',
    );
    final text = authErrorMessage(error, AuthAction.signIn);
    expect(text, isNot(contains('INTERNAL')));
    expect(text, 'Sign-in didn\'t work. Please try again.');
  });

  test('missing user maps to a session message', () {
    expect(
      authErrorMessage(StateError('no user'), AuthAction.updatePassword),
      'Your session has ended. Please sign in again.',
    );
  });
}
