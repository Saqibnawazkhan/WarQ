import 'package:intl/intl.dart';

/// Number and text formatting helpers used across screens and PDF reports.
class Format {
  const Format._();

  static final NumberFormat _compact = NumberFormat.compact();

  /// Drops a trailing `.0` so `18.0` renders as `18` but `17.5` stays intact.
  static String marks(double value) {
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }

  static String marksOrDash(double? value) => value == null ? '—' : marks(value);

  /// `85.4%` — one decimal place, or none for whole numbers.
  static String percent(double value, {int decimals = 1}) {
    if (value.isNaN || value.isInfinite) return '—';
    if (value == value.roundToDouble()) return '${value.toStringAsFixed(0)}%';
    return '${value.toStringAsFixed(decimals)}%';
  }

  static String percentOrDash(double? value, {int decimals = 1}) =>
      value == null ? '—' : percent(value, decimals: decimals);

  /// `18 / 20`
  static String fraction(double? obtained, double total) =>
      '${marksOrDash(obtained)} / ${marks(total)}';

  static String count(int value) => value < 1000 ? '$value' : _compact.format(value);

  /// `AB` from `Ahmed Bilal`, `A` from `Ahmed`.
  static String initials(String name) {
    final List<String> parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((String p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      final String single = parts.first;
      return single.substring(0, single.length >= 2 ? 2 : 1).toUpperCase();
    }
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  /// Title-cases a name entered in any casing.
  static String titleCase(String value) {
    return value
        .trim()
        .split(RegExp(r'\s+'))
        .where((String p) => p.isNotEmpty)
        .map((String word) => word.length == 1
            ? word.toUpperCase()
            : word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  /// `3 students` / `1 student`
  static String plural(int count, String singular, [String? pluralForm]) {
    final String word = count == 1 ? singular : (pluralForm ?? '${singular}s');
    return '$count $word';
  }

  static String truncate(String value, int max) {
    if (value.length <= max) return value;
    return '${value.substring(0, max - 1).trimRight()}…';
  }

  /// Masks all but the last four digits: `••• ••• 4821`.
  static String maskedPhone(String phone) {
    final String digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length <= 4) return phone;
    return '••• ••• ${digits.substring(digits.length - 4)}';
  }

  /// Normalises whitespace inside free-text fields before persisting.
  static String clean(String value) => value.trim().replaceAll(RegExp(r'\s+'), ' ');

  static String? cleanOrNull(String? value) {
    if (value == null) return null;
    final String cleaned = clean(value);
    return cleaned.isEmpty ? null : cleaned;
  }
}
