import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Salted SHA-256 hashing for on-device credentials.
///
/// This is appropriate for a local-only Phase 1 build: it keeps passwords out
/// of plain text on disk. Once the Phase 2 backend owns authentication, hashing
/// moves server-side to a slow KDF (bcrypt/argon2) and this class is retired.
class PasswordHasher {
  const PasswordHasher._();

  static final Random _random = Random.secure();

  static String generateSalt({int length = 16}) {
    final List<int> bytes =
        List<int>.generate(length, (_) => _random.nextInt(256));
    return base64Url.encode(bytes);
  }

  static String hash(String password, String salt) {
    final List<int> payload = utf8.encode('$salt::$password');
    return sha256.convert(payload).toString();
  }

  /// Constant-time comparison so a local attacker cannot time-guess the hash.
  static bool verify(String password, String salt, String expectedHash) {
    final String actual = hash(password, salt);
    if (actual.length != expectedHash.length) return false;
    int diff = 0;
    for (int i = 0; i < actual.length; i++) {
      diff |= actual.codeUnitAt(i) ^ expectedHash.codeUnitAt(i);
    }
    return diff == 0;
  }
}
