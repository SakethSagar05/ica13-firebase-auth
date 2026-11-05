/// Client-side form checks. These give fast feedback only; Firebase
/// Authentication (and the project's password policy) stays authoritative.
library;

const int minPasswordLength = 6;

final RegExp _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

String? validateEmail(String? value) {
  final email = value?.trim() ?? '';
  if (email.isEmpty) return 'Email is required';
  if (!_emailPattern.hasMatch(email)) {
    return 'Enter a valid email address (e.g. name@example.com)';
  }
  return null;
}

String? validatePassword(String? value) {
  if (value == null || value.isEmpty) return 'Password is required';
  if (value.length < minPasswordLength) {
    return 'Password must be at least $minPasswordLength characters';
  }
  return null;
}

String? validateConfirmPassword(String? value, String original) {
  if (value == null || value.isEmpty) return 'Please confirm the password';
  if (value != original) return 'Passwords do not match';
  return null;
}

String? validateRequired(String? value, String fieldName) {
  if (value == null || value.isEmpty) return '$fieldName is required';
  return null;
}
