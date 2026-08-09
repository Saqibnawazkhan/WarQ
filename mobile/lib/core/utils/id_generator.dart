import 'dart:math';

/// Generates sortable, collision-resistant string identifiers.
///
/// The format is `<prefix>_<base36 timestamp><random>` which keeps ids readable
/// in debug output while remaining safe to use as a primary key once the data
/// moves to a shared backend.
class IdGenerator {
  IdGenerator._();

  static final Random _random = Random.secure();
  static int _counter = 0;

  static String generate([String prefix = 'id']) {
    final int now = DateTime.now().microsecondsSinceEpoch;
    _counter = (_counter + 1) & 0xFFF;
    final String time = now.toRadixString(36);
    final String seq = _counter.toRadixString(36).padLeft(3, '0');
    final String rand = _random.nextInt(1 << 32).toRadixString(36).padLeft(6, '0');
    return '${prefix}_$time$seq$rand';
  }

  /// Human friendly code used for organisation join codes and invitation
  /// tokens. Ambiguous characters (0/O, 1/I) are excluded.
  static String code({int length = 8}) {
    const String alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    return String.fromCharCodes(
      Iterable<int>.generate(
        length,
        (_) => alphabet.codeUnitAt(_random.nextInt(alphabet.length)),
      ),
    );
  }

  /// Numeric code used for the Phase 1 password reset flow.
  static String numericCode({int length = 6}) {
    final StringBuffer buffer = StringBuffer();
    for (int i = 0; i < length; i++) {
      buffer.write(_random.nextInt(10));
    }
    return buffer.toString();
  }
}
