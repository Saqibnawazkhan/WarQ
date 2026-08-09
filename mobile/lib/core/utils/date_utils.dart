import 'package:intl/intl.dart';

/// Date helpers shared by attendance, assessments and reports.
///
/// Attendance is keyed by calendar day, so every date entering the data layer
/// is normalised to local midnight to avoid off-by-one bugs across time zones.
class AppDate {
  const AppDate._();

  static final DateFormat _iso = DateFormat('yyyy-MM-dd');
  static final DateFormat _display = DateFormat('d MMM yyyy');
  static final DateFormat _displayShort = DateFormat('d MMM');
  static final DateFormat _displayLong = DateFormat('EEEE, d MMMM yyyy');
  static final DateFormat _weekday = DateFormat('EEE');
  static final DateFormat _monthYear = DateFormat('MMMM yyyy');
  static final DateFormat _time = DateFormat('h:mm a');
  static final DateFormat _dateTime = DateFormat('d MMM yyyy, h:mm a');

  /// Strips the time component, keeping the local calendar day.
  static DateTime dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static DateTime today() => dateOnly(DateTime.now());

  static String toIso(DateTime value) => _iso.format(dateOnly(value));

  static DateTime? parseIso(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final DateTime? parsed = DateTime.tryParse(value);
    return parsed == null ? null : dateOnly(parsed);
  }

  static String format(DateTime value) => _display.format(value);

  static String formatShort(DateTime value) => _displayShort.format(value);

  static String formatLong(DateTime value) => _displayLong.format(value);

  static String formatWeekday(DateTime value) => _weekday.format(value);

  static String formatMonthYear(DateTime value) => _monthYear.format(value);

  static String formatTime(DateTime value) => _time.format(value);

  static String formatDateTime(DateTime value) => _dateTime.format(value);

  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static bool isToday(DateTime value) => isSameDay(value, DateTime.now());

  static bool isFuture(DateTime value) => dateOnly(value).isAfter(today());

  /// Inclusive range check on calendar days.
  static bool isWithin(DateTime value, DateTime? start, DateTime? end) {
    final DateTime day = dateOnly(value);
    if (start != null && day.isBefore(dateOnly(start))) return false;
    if (end != null && day.isAfter(dateOnly(end))) return false;
    return true;
  }

  /// "Today", "Yesterday", "3 days ago", or an absolute date beyond a week.
  static String relativeDay(DateTime value) {
    final DateTime day = dateOnly(value);
    final int diff = today().difference(day).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff == -1) return 'Tomorrow';
    if (diff > 1 && diff < 7) return '$diff days ago';
    if (diff < -1 && diff > -7) return 'In ${-diff} days';
    return format(day);
  }

  /// Compact "2h ago" style label used by activity feeds.
  static String relativeTime(DateTime value) {
    final Duration diff = DateTime.now().difference(value);
    if (diff.inSeconds.abs() < 60) return 'Just now';
    if (diff.inMinutes.abs() < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours.abs() < 24) return '${diff.inHours}h ago';
    if (diff.inDays.abs() < 7) return '${diff.inDays}d ago';
    return format(value);
  }

  /// The Monday-anchored start of the week containing [value].
  static DateTime startOfWeek(DateTime value) {
    final DateTime day = dateOnly(value);
    return day.subtract(Duration(days: day.weekday - DateTime.monday));
  }

  static DateTime startOfMonth(DateTime value) => DateTime(value.year, value.month);

  static DateTime endOfMonth(DateTime value) =>
      DateTime(value.year, value.month + 1, 0);

  /// Every calendar day in `[start, end]`, inclusive.
  static List<DateTime> daysBetween(DateTime start, DateTime end) {
    final DateTime from = dateOnly(start);
    final DateTime to = dateOnly(end);
    if (to.isBefore(from)) return <DateTime>[];
    final int count = to.difference(from).inDays;
    return List<DateTime>.generate(
      count + 1,
      (int i) => DateTime(from.year, from.month, from.day + i),
    );
  }

  /// Suggests an academic session label such as `2026` or `2026-2027`.
  static String currentSessionLabel() {
    final DateTime now = DateTime.now();
    // Academic years commonly start mid-year; before August we stay in the
    // current calendar year, after that we span into the next one.
    if (now.month >= DateTime.august) {
      return '${now.year}-${now.year + 1}';
    }
    return '${now.year}';
  }
}
