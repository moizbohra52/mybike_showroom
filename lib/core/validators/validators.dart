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
}
