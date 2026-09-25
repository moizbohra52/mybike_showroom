/// Trimmed text, or null when empty (empty form fields are stored as NULL).
String? blankToNull(String? value) {
  final String v = (value ?? '').trim();
  return v.isEmpty ? null : v;
}
