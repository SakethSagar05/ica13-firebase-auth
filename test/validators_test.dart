import 'package:flutter_test/flutter_test.dart';
import 'package:ica13_firebase_auth/utils/validators.dart';

void main() {
  group('validateEmail', () {
    test('rejects empty input', () {
      expect(validateEmail(''), 'Email is required');
      expect(validateEmail(null), 'Email is required');
    });
    test('rejects badly formatted emails', () {
      expect(validateEmail('student'), isNotNull);
      expect(validateEmail('student@'), isNotNull);
      expect(validateEmail('student@gsu'), isNotNull);
      expect(validateEmail('a b@test.com'), isNotNull);
    });
    test('accepts a valid email (trims spaces)', () {
      expect(validateEmail('ica13.tester@example.com'), isNull);
      expect(validateEmail('  ica13.tester@example.com  '), isNull);
    });
  });

  group('validatePassword', () {
    test('requires a value', () {
      expect(validatePassword(''), 'Password is required');
    });
    test('enforces the 6-character baseline', () {
      expect(validatePassword('12345'), 'Password must be at least 6 characters');
      expect(validatePassword('123456'), isNull);
    });
  });

  group('validateConfirmPassword', () {
    test('must match the original', () {
      expect(validateConfirmPassword('abcdef', 'abcdeg'), 'Passwords do not match');
      expect(validateConfirmPassword('abcdef', 'abcdef'), isNull);
    });
  });
}
