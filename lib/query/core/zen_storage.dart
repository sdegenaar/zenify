import 'dart:async';

/// Interface for persisting query data.
///
/// Implement this to enable offline support and hydration for ZenQuery.
///
/// ## Important: the wire format is `Map<String, dynamic>`, not a JSON string
///
/// The [write] and [read] methods pass a plain Dart map — there is no
/// `jsonEncode`/`jsonDecode` anywhere in the ZenQuery cache layer itself.
/// Whether you encode that map to a string (e.g. for SharedPreferences) or
/// store it natively (e.g. SQLite/Drift columns) is entirely up to your adapter.
///
/// This also means `ZenQueryConfig.toJson` and `fromJson` return/accept
/// `Map<String, dynamic>` directly — Drift's `toMap()`/`fromMap()` work
/// without any JSON encoding step.
///
/// ## Copy-paste recipes
///
/// ### SharedPreferences (encodes map → JSON string)
/// ```dart
/// import 'dart:convert';
/// import 'package:shared_preferences/shared_preferences.dart';
/// import 'package:zenify/zenify.dart';
///
/// class SharedPreferencesStorage implements ZenStorage {
///   SharedPreferences? _prefs;
///   Future<SharedPreferences> get _instance async =>
///       _prefs ??= await SharedPreferences.getInstance();
///
///   @override
///   Future<void> write(String key, Map<String, dynamic> json) async =>
///       (await _instance).setString(key, jsonEncode(json));
///
///   @override
///   Future<Map<String, dynamic>?> read(String key) async {
///     final raw = (await _instance).getString(key);
///     return raw != null ? jsonDecode(raw) as Map<String, dynamic> : null;
///   }
///
///   @override
///   Future<void> delete(String key) async =>
///       (await _instance).remove(key);
/// }
/// ```
///
/// ### SQLite / Drift (stores map natively — no JSON encoding needed)
/// ```dart
/// import 'package:zenify/zenify.dart';
///
/// // Drift database with a simple key-value table:
/// // CREATE TABLE zen_cache (key TEXT PRIMARY KEY, data TEXT, timestamp INTEGER)
/// class DriftStorage implements ZenStorage {
///   final AppDatabase _db;
///   DriftStorage(this._db);
///
///   @override
///   Future<void> write(String key, Map<String, dynamic> json) =>
///       _db.zenCache.insertOrReplace(ZenCacheCompanion(
///         key: Value(key),
///         data: Value(jsonEncode(json['data'])), // encode only the data payload
///         timestamp: Value(json['timestamp'] as int),
///       ));
///
///   @override
///   Future<Map<String, dynamic>?> read(String key) async {
///     final row = await _db.zenCache.select()
///         .where((t) => t.key.equals(key)).getSingleOrNull();
///     if (row == null) return null;
///     return {'data': jsonDecode(row.data), 'timestamp': row.timestamp, 'version': 1};
///   }
///
///   @override
///   Future<void> delete(String key) =>
///       (_db.zenCache.delete()..where((t) => t.key.equals(key))).go();
/// }
///
/// // Usage — toMap()/fromMap() plug in directly, no extra encoding:
/// ZenQueryConfig<User>(
///   persist: true,
///   storage: DriftStorage(db),
///   toJson: (user) => user.toMap(),   // Drift's native Map — no jsonEncode
///   fromJson: User.fromMap,            // Drift's native Map — no jsonDecode
/// )
/// ```
abstract class ZenStorage {
  /// Write data to storage.
  ///
  /// [key] is the unique query key.
  /// [json] is a plain `Map<String, dynamic>` containing the serialized data
  /// and metadata (timestamp, version). It is NOT a JSON-encoded string.
  Future<void> write(String key, Map<String, dynamic> json);

  /// Read data from storage.
  ///
  /// Returns the plain `Map<String, dynamic>` previously passed to [write],
  /// or `null` if no data exists for [key].
  Future<Map<String, dynamic>?> read(String key);

  /// Delete data from storage.
  Future<void> delete(String key);
}
