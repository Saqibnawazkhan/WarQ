/// Defensive JSON readers.
///
/// Persisted documents can be written by an older build (or, in Phase 2, by the
/// backend), so every field is read tolerantly rather than force-cast.
class Json {
  const Json._();

  static String string(Map<String, dynamic> map, String key, {String fallback = ''}) {
    final Object? value = map[key];
    if (value == null) return fallback;
    return value.toString();
  }

  static String? stringOrNull(Map<String, dynamic> map, String key) {
    final Object? value = map[key];
    if (value == null) return null;
    final String text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static int integer(Map<String, dynamic> map, String key, {int fallback = 0}) {
    final Object? value = map[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  static double number(Map<String, dynamic> map, String key, {double fallback = 0}) {
    final Object? value = map[key];
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }

  static double? numberOrNull(Map<String, dynamic> map, String key) {
    final Object? value = map[key];
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) {
      if (value.trim().isEmpty) return null;
      return double.tryParse(value);
    }
    return null;
  }

  static bool boolean(Map<String, dynamic> map, String key, {bool fallback = false}) {
    final Object? value = map[key];
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final String lower = value.toLowerCase();
      if (lower == 'true' || lower == '1' || lower == 'yes') return true;
      if (lower == 'false' || lower == '0' || lower == 'no') return false;
    }
    return fallback;
  }

  static DateTime dateTime(Map<String, dynamic> map, String key, {DateTime? fallback}) {
    return dateTimeOrNull(map, key) ?? fallback ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  static DateTime? dateTimeOrNull(Map<String, dynamic> map, String key) {
    final Object? value = map[key];
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) {
      if (value.trim().isEmpty) return null;
      return DateTime.tryParse(value);
    }
    return null;
  }

  static List<String> stringList(Map<String, dynamic> map, String key) {
    final Object? value = map[key];
    if (value is List) {
      return value.map((Object? e) => e.toString()).toList(growable: false);
    }
    return const <String>[];
  }

  static List<Map<String, dynamic>> mapList(Map<String, dynamic> map, String key) {
    final Object? value = map[key];
    if (value is List) {
      return value
          .whereType<Map<Object?, Object?>>()
          .map(normalize)
          .toList(growable: false);
    }
    return const <Map<String, dynamic>>[];
  }

  /// Converts a decoded `Map<Object?, Object?>` into `Map<String, dynamic>`.
  static Map<String, dynamic> normalize(Map<Object?, Object?> raw) {
    return raw.map((Object? key, Object? value) =>
        MapEntry<String, dynamic>(key.toString(), value));
  }

  /// Reads an enum value by its `name`, falling back when unknown.
  static T enumValue<T extends Enum>(
    Map<String, dynamic> map,
    String key,
    List<T> values,
    T fallback,
  ) {
    final String? name = stringOrNull(map, key);
    if (name == null) return fallback;
    for (final T value in values) {
      if (value.name == name) return value;
    }
    return fallback;
  }

  static T? enumValueOrNull<T extends Enum>(
    Map<String, dynamic> map,
    String key,
    List<T> values,
  ) {
    final String? name = stringOrNull(map, key);
    if (name == null) return null;
    for (final T value in values) {
      if (value.name == name) return value;
    }
    return null;
  }

  /// Drops `null` entries so persisted documents stay compact.
  static Map<String, dynamic> compact(Map<String, dynamic> map) {
    final Map<String, dynamic> result = <String, dynamic>{};
    map.forEach((String key, dynamic value) {
      if (value != null) result[key] = value;
    });
    return result;
  }
}
