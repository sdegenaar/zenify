/// Zenify Storage Adapters
///
/// Zenify ships zero third-party dependencies. The [ZenStorage] interface is
/// intentionally minimal so you can plug in any persistence backend.
///
/// ## Built-in (zero-dep) adapters
///
/// - [InMemoryStorage] — Stores data in-memory for the current session.
///   Ideal for testing, CI, and debug builds.
///
/// ## Platform adapters (implement yourself — it's 10 lines)
///
/// Zenify deliberately does NOT bundle `shared_preferences`, `hive`,
/// `sqflite`, etc. as dependencies. Instead, implement [ZenStorage] yourself:
///
/// ### SharedPreferences (copy-paste recipe):
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
/// See also `example/zen_offline/lib/storage.dart` for a full production example.
library;

export 'zen_in_memory_storage.dart';
// Re-export the base interface for convenience
export '../query/core/zen_storage.dart';
