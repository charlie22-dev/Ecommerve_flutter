/// Shared field validation for the Login and Sign Up forms — kept in one
/// place so both modes (and the Forgot Password sheet) apply the same
/// rules instead of drifting apart.
abstract final class AuthValidators {
  static final _emailPattern = RegExp(r'^[\w.!#$%&*+/=?^`{|}~-]+@[\w-]+(?:\.[\w-]+)+$');

  /// Returns an error string if [value] is empty or doesn't match a basic
  /// RFC-5321-style email pattern; returns null when the value is valid.
  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Enter your email';
    if (!_emailPattern.hasMatch(v)) return 'Enter a valid email address';
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'Enter your password';
    if (value.length < 6) return 'At least 6 characters';
    return null;
  }

  static String? Function(String?) confirmPassword(String Function() getPassword) {
    return (value) {
      if (value == null || value.isEmpty) return 'Confirm your password';
      if (value != getPassword()) return "Passwords don't match";
      return null;
    };
  }

  static String? displayName(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Enter your name';
    if (v.length < 2) return 'Name is too short';
    return null;
  }
}
