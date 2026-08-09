import 'package:shared_preferences/shared_preferences.dart';

/// Minimal persistence contract.
///
/// Abstracting the key-value engine keeps [SharedPreferencesStore] swappable
/// for an in-memory implementation in tests, and later for a SQLite or secure
/// storage backend without touching repositories.
abstract class KeyValueStore {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);

  Future<void> clear();

  Future<Set<String>> keys();
}

/// Production implementation backed by `shared_preferences`.
class SharedPreferencesStore implements KeyValueStore {
  SharedPreferencesStore(this._prefs);

  static Future<SharedPreferencesStore> create() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return SharedPreferencesStore(prefs);
  }

  final SharedPreferences _prefs;

  @override
  Future<String?> read(String key) async => _prefs.getString(key);

  @override
  Future<void> write(String key, String value) async {
    await _prefs.setString(key, value);
  }

  @override
  Future<void> delete(String key) async {
    await _prefs.remove(key);
  }

  @override
  Future<void> clear() async {
    for (final String key in _prefs.getKeys().toList(growable: false)) {
      await _prefs.remove(key);
    }
  }

  @override
  Future<Set<String>> keys() async => _prefs.getKeys();
}

/// Volatile implementation used by unit and widget tests.
class InMemoryKeyValueStore implements KeyValueStore {
  final Map<String, String> _data = <String, String>{};

  @override
  Future<String?> read(String key) async => _data[key];

  @override
  Future<void> write(String key, String value) async {
    _data[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _data.remove(key);
  }

  @override
  Future<void> clear() async => _data.clear();

  @override
  Future<Set<String>> keys() async => _data.keys.toSet();
}
