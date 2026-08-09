import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../core/error/failure.dart';
import '../../core/utils/json_utils.dart';
import 'key_value_store.dart';

/// A document collection persisted as a single JSON array.
///
/// Rows are held in memory for synchronous reads (the UI queries them
/// constantly) and flushed to the [KeyValueStore] after every mutation. The
/// API deliberately mirrors a remote collection so the Phase 2 swap to HTTP is
/// mechanical.
class CollectionStore<T> {
  CollectionStore({
    required this.key,
    required KeyValueStore store,
    required T Function(Map<String, dynamic> json) fromJson,
    required Map<String, dynamic> Function(T item) toJson,
    required String Function(T item) idOf,
  })  : _store = store,
        _fromJson = fromJson,
        _toJson = toJson,
        _idOf = idOf;

  final String key;
  final KeyValueStore _store;
  final T Function(Map<String, dynamic>) _fromJson;
  final Map<String, dynamic> Function(T) _toJson;
  final String Function(T) _idOf;

  /// Insertion-ordered map keeps iteration stable between launches.
  final Map<String, T> _items = <String, T>{};
  bool _loaded = false;

  bool get isLoaded => _loaded;

  int get length => _items.length;

  /// Snapshot of every row. Callers must not mutate the returned list.
  List<T> get all => List<T>.unmodifiable(_items.values);

  Iterable<T> where(bool Function(T item) test) => _items.values.where(test);

  T? byId(String? id) => id == null ? null : _items[id];

  T requireById(String id, {String label = 'Record'}) {
    final T? found = _items[id];
    if (found == null) throw AppFailure.notFound(label);
    return found;
  }

  bool contains(String id) => _items.containsKey(id);

  T? firstWhereOrNull(bool Function(T item) test) {
    for (final T item in _items.values) {
      if (test(item)) return item;
    }
    return null;
  }

  int countWhere(bool Function(T item) test) {
    int total = 0;
    for (final T item in _items.values) {
      if (test(item)) total++;
    }
    return total;
  }

  /// Reads the collection from disk. Corrupt payloads are dropped rather than
  /// crashing the app on launch — losing a cache is preferable to a boot loop.
  Future<void> load() async {
    if (_loaded) return;
    _items.clear();
    try {
      final String? raw = await _store.read(key);
      if (raw != null && raw.isNotEmpty) {
        final Object? decoded = jsonDecode(raw);
        if (decoded is List) {
          for (final Object? entry in decoded) {
            if (entry is Map) {
              try {
                final T item = _fromJson(Json.normalize(entry));
                _items[_idOf(item)] = item;
              } catch (error) {
                debugPrint('[$key] skipped malformed row: $error');
              }
            }
          }
        }
      }
    } catch (error) {
      debugPrint('[$key] failed to load, starting empty: $error');
      _items.clear();
    }
    _loaded = true;
  }

  Future<T> put(T item) async {
    _items[_idOf(item)] = item;
    await _flush();
    return item;
  }

  Future<List<T>> putAll(Iterable<T> items) async {
    final List<T> written = <T>[];
    for (final T item in items) {
      _items[_idOf(item)] = item;
      written.add(item);
    }
    if (written.isNotEmpty) await _flush();
    return written;
  }

  Future<bool> delete(String id) async {
    final bool removed = _items.remove(id) != null;
    if (removed) await _flush();
    return removed;
  }

  Future<int> deleteWhere(bool Function(T item) test) async {
    final List<String> doomed = <String>[
      for (final MapEntry<String, T> entry in _items.entries)
        if (test(entry.value)) entry.key,
    ];
    for (final String id in doomed) {
      _items.remove(id);
    }
    if (doomed.isNotEmpty) await _flush();
    return doomed.length;
  }

  Future<void> clear() async {
    if (_items.isEmpty) return;
    _items.clear();
    await _flush();
  }

  /// Replaces the whole collection in one write — used by the seeder.
  Future<void> replaceAll(Iterable<T> items) async {
    _items
      ..clear()
      ..addEntries(items.map((T e) => MapEntry<String, T>(_idOf(e), e)));
    await _flush();
  }

  Future<void> _flush() async {
    try {
      final String payload = jsonEncode(
        _items.values.map(_toJson).toList(growable: false),
      );
      await _store.write(key, payload);
    } catch (error) {
      throw AppFailure.storage(
        'Could not save changes. Please try again.',
        details: error,
      );
    }
  }
}
