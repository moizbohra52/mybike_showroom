/// Form validators shared by every screen (return an error message or null).
abstract final class Validators {
  static final RegExp emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static String? required(String? value, {String field = 'This field'}) {
    return (value == null || value.trim().isEmpty) ? '$field is required.' : null;
  }

  static String? email(String? value) {
    final String? missing = required(value, field: 'Email');
    if (missing != null) {
      return missing;
    }
    return emailPattern.hasMatch(value!.trim()) ? null : 'Enter a valid email address.';
  }

  /// Same rule as supabase/config.toml and the admin-users Edge Function.
  static String? password(String? value) {
    final String v = value ?? '';
    final bool ok = v.length >= 10 &&
        v.length <= 72 &&
        v.contains(RegExp('[a-z]')) &&
        v.contains(RegExp('[A-Z]')) &&
        v.contains(RegExp('[0-9]'));
    return ok ? null : 'Use 10–72 characters with a lowercase letter, an uppercase letter and a digit.';
  }

  /// Optional; matches the profiles_phone_format constraint.
  static String? phone(String? value) {
    final String v = (value ?? '').trim();
    return v.isEmpty || RegExp(r'^\+?[0-9]{10,15}$').hasMatch(v) ? null : 'Enter 10–15 digits, optionally starting with +.';
  }

  /// Optional; matches profiles_employee_code_format (stored upper-case).
  static String? employeeCode(String? value) {
    final String v = (value ?? '').trim().toUpperCase();
    return v.isEmpty || RegExp(r'^[A-Z0-9][A-Z0-9-]{1,19}$').hasMatch(v)
        ? null
        : 'Use 2–20 letters, digits or dashes.';
  }
}
