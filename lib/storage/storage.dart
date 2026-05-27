/// Zenify Storage Adapters
///
/// Zenify ships zero third-party dependencies. The [ZenStorage] interface is
/// intentionally minimal so you can plug in any persistence backend.
///
/// ## Important: the wire format is `Map<String, dynamic>`, not a JSON string
///
/// `ZenStorage.write()` and `read()` pass a plain Dart map. There is no
/// `jsonEncode`/`jsonDecode` anywhere in the ZenQuery cache layer itself.
/// This means `ZenQueryConfig.toJson`/`fromJson` are actually
/// `Map<String, dynamic>` converters — Drift's `toMap()`/`fromMap()` plug in
/// directly without any extra encoding step.
///
/// ## Built-in (zero-dep) adapters
///
/// - [InMemoryStorage] — Stores data in-memory for the current session.
///   Ideal for testing, CI, and debug builds.
///
/// ## Platform adapters (implement yourself — it's ~10 lines)
///
/// Zenify deliberately does NOT bundle `shared_preferences`, `hive`,
/// `sqflite`, etc. as dependencies. Instead, implement [ZenStorage] yourself:
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
/// class DriftStorage implements ZenStorage {
///   final AppDatabase _db;
///   DriftStorage(this._db);
///
///   @override
///   Future<void> write(String key, Map<String, dynamic> json) =>
///       _db.zenCache.insertOrReplace(ZenCacheCompanion(
///         key: Value(key),
///         data: Value(jsonEncode(json['data'])),
///         timestamp: Value(json['timestamp'] as int),
///       ));
///
///   @override
///   Future<Map<String, dynamic>?> read(String key) async {
///     final row = await _db.zenCache
///         .select().where((t) => t.key.equals(key)).getSingleOrNull();
///     if (row == null) return null;
///     return {'data': jsonDecode(row.data), 'timestamp': row.timestamp, 'version': 1};
///   }
///
///   @override
///   Future<void> delete(String key) =>
///       (_db.zenCache.delete()..where((t) => t.key.equals(key))).go();
/// }
///
/// // toMap()/fromMap() plug in directly — no JSON encoding needed:
/// ZenQueryConfig<User>(
///   persist: true,
///   storage: DriftStorage(db),
///   toJson: (user) => user.toMap(),
///   fromJson: User.fromMap,
/// )
/// ```
///
/// See also `example/zen_offline/lib/storage.dart` for a full production example.
library;

export 'zen_in_memory_storage.dart';
// Re-export the base interface for convenience
export '../query/core/zen_storage.dart';
