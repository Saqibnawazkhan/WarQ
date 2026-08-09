import '../constants/app_constants.dart';

/// Form validators returning `null` when the value is acceptable.
class Validators {
  const Validators._();

  static final RegExp _emailPattern = RegExp(
    r'^[\w.!#$%&*+/=?^`{|}~-]+@[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?'
    r'(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?)+$',
  );

  /// Permissive on purpose: phone numbers are optional and international
  /// formats vary widely. We only reject values that clearly are not numbers.
  static final RegExp _phonePattern = RegExp(r'^\+?[0-9\s\-()]{7,20}$');

  static String? required(String? value, {String field = 'This field'}) {
    if (value == null || value.trim().isEmpty) return '$field is required.';
    return null;
  }

  static String? name(String? value, {String field = 'Name'}) {
    final String? empty = required(value, field: field);
    if (empty != null) return empty;
    final String trimmed = value!.trim();
    if (trimmed.length < 2) return '$field must be at least 2 characters.';
    if (trimmed.length > 80) return '$field must be 80 characters or fewer.';
    return null;
  }

  static String? email(String? value, {bool isRequired = true}) {
    final String trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return isRequired ? 'Email is required.' : null;
    }
    if (!_emailPattern.hasMatch(trimmed)) return 'Enter a valid email address.';
    return null;
  }

  /// Login accepts either an email address or a username.
  static String? emailOrUsername(String? value) {
    final String trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return 'Email or username is required.';
    if (trimmed.contains('@')) return email(trimmed);
    if (trimmed.length < 3) return 'Username must be at least 3 characters.';
    return null;
  }

  static String? username(String? value, {bool isRequired = false}) {
    final String trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return isRequired ? 'Username is required.' : null;
    if (trimmed.length < 3) return 'Username must be at least 3 characters.';
    if (!RegExp(r'^[a-zA-Z0-9._-]+$').hasMatch(trimmed)) {
      return 'Use only letters, numbers, dots, dashes and underscores.';
    }
    return null;
  }

  static String? password(String? value) {
    final String text = value ?? '';
    if (text.isEmpty) return 'Password is required.';
    if (text.length < AppConstants.minPasswordLength) {
      return 'Password must be at least ${AppConstants.minPasswordLength} characters.';
    }
    return null;
  }

  static String? confirmPassword(String? value, String original) {
    if (value == null || value.isEmpty) return 'Confirm your password.';
    if (value != original) return 'Passwords do not match.';
    return null;
  }

  static String? phone(String? value, {String field = 'Phone number'}) {
    final String trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return null; // Optional everywhere in Phase 1.
    if (!_phonePattern.hasMatch(trimmed)) return 'Enter a valid $field.';
    return null;
  }

  /// Total marks must be a positive number.
  static String? totalMarks(String? value) {
    final String trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return 'Total marks is required.';
    final double? parsed = double.tryParse(trimmed);
    if (parsed == null) return 'Enter a number.';
    if (parsed <= 0) return 'Total marks must be greater than zero.';
    if (parsed > 10000) return 'Total marks looks too large.';
    return null;
  }

  /// Obtained marks are optional (blank means "not graded yet") but when
  /// present must fall inside `[0, max]`.
  static String? obtainedMarks(String? value, double max) {
    final String trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return null;
    final double? parsed = double.tryParse(trimmed);
    if (parsed == null) return 'Enter a number.';
    if (parsed < 0) return 'Marks cannot be negative.';
    if (parsed > max) return 'Cannot exceed ${_trim(max)}.';
    return null;
  }

  static String? maxLength(String? value, int max, {String field = 'This field'}) {
    if (value == null) return null;
    if (value.trim().length > max) return '$field must be $max characters or fewer.';
    return null;
  }

  static String _trim(double value) {
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toStringAsFixed(2);
  }
}
