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

  /// Optional check against a database pattern; the value is trimmed (and
  /// upper-cased when [upperCase]) first.
  static String? pattern(String? value, RegExp pattern, String message, {bool upperCase = true}) {
    final String raw = (value ?? '').trim();
    final String v = upperCase ? raw.toUpperCase() : raw;
    return v.isEmpty || pattern.hasMatch(v) ? null : message;
  }

  static final RegExp gstinPattern = RegExp(r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][1-9A-Z]Z[0-9A-Z]$');
  static final RegExp panPattern = RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$');

  static String? gstin(String? value) => pattern(value, gstinPattern, 'Enter the 15-character GSTIN.');

  static String? pan(String? value) => pattern(value, panPattern, 'Enter the 10-character PAN, e.g. ABCDE1234F.');

  static String? pincode(String? value) =>
      pattern(value, RegExp(r'^[1-9][0-9]{5}$'), 'Enter a 6-digit PIN code.', upperCase: false);

  static String? ifsc(String? value) =>
      pattern(value, RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$'), 'Enter the 11-character IFSC, e.g. HDFC0001234.');

  static String? bankAccountNumber(String? value) =>
      pattern(value, RegExp(r'^[0-9]{9,18}$'), 'Enter 9–18 digits.', upperCase: false);

  static String? upi(String? value) =>
      pattern(value, RegExp(r'^[A-Za-z0-9._-]{2,64}@[A-Za-z]{2,64}$'), 'Enter a UPI ID like name@bank.', upperCase: false);

  /// Optional rupee amount, up to 12 digits and 2 decimals. Kept as text and
  /// sent to Postgres numeric, never parsed to double (G5).
  static String? amount(String? value) => pattern(
        value,
        RegExp(r'^[0-9]{1,12}(\.[0-9]{1,2})?$'),
        'Enter an amount like 5000 or 5000.50.',
        upperCase: false,
      );

  /// Optional VIN: 17 characters without I, O or Q (ISO 3779), spaces ignored.
  static String? vin(String? value) => pattern(
        (value ?? '').replaceAll(RegExp(r'\s'), ''),
        RegExp(r'^[A-HJ-NPR-Z0-9]{17}$'),
        'A VIN has 17 letters and digits (no I, O or Q).',
      );

  /// Optional chassis / engine / motor / battery number, spaces ignored.
  static String? vehicleIdentifier(String? value) => pattern(
        (value ?? '').replaceAll(RegExp(r'\s'), ''),
        RegExp(r'^[A-Z0-9][A-Z0-9/-]{3,29}$'),
        'Use 4–30 letters, digits, / or -.',
      );

  /// Optional positive number with at most [digits] integer digits and
  /// [decimals] decimals (matches a numeric(p, s) column).
  static String? number(String? value, {int digits = 6, int decimals = 2}) {
    final String v = (value ?? '').trim();
    if (v.isEmpty) {
      return null;
    }
    final RegExp re = RegExp('^[0-9]{1,$digits}${decimals == 0 ? '' : '(\\.[0-9]{1,$decimals})?'}\$');
    return re.hasMatch(v) && RegExp('[1-9]').hasMatch(v)
        ? null
        : decimals == 0
            ? 'Enter a whole number above 0.'
            : 'Enter a number above 0 (up to $decimals decimals).';
  }

  /// Required whole number between [min] and [max].
  static String? wholeNumber(String? value, {required int min, required int max}) {
    final int? n = int.tryParse((value ?? '').trim());
    return n != null && n >= min && n <= max ? null : 'Enter a whole number from $min to $max.';
  }
}
