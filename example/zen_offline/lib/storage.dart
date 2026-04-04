import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zenify/zenify.dart';

/// A production-ready [ZenStorage] adapter backed by [SharedPreferences].
///
/// This is a **reference implementation** you can copy into any project.
/// Zenify deliberately does not bundle platform packages as dependencies,
/// so you own this adapter — customise it as you see fit.
///
/// ## Features
/// - Instance caching (only calls `getInstance()` once per app lifecycle)
/// - Key prefixing to avoid collisions with other SharedPreferences keys
/// - Error-safe: storage failures never crash the app (asserts in debug mode)
/// - `clearAll()` to wipe only Zenify's keys, leaving your other prefs intact
///
/// ## Usage
/// ```dart
/// await Zen.init(
///   storage: SharedPreferencesStorage(),
/// );
/// ```
class SharedPreferencesStorage implements ZenStorage {
  /// Prefix applied to all keys to avoid collisions with other app prefs.
  final String prefix;

  SharedPreferences? _prefs;

  SharedPreferencesStorage({this.prefix = 'zen_query_'});

  Future<SharedPreferences> get _instance async =>
      _prefs ??= await SharedPreferences.getInstance();

  String _key(String key) => '$prefix$key';

  @override
  Future<void> write(String key, Map<String, dynamic> json) async {
    try {
      await (await _instance).setString(_key(key), jsonEncode(json));
    } catch (e, st) {
      assert(false, 'ZenStorage.write("$key") failed: $e\n$st');
    }
  }

  @override
  Future<Map<String, dynamic>?> read(String key) async {
    try {
      final raw = (await _instance).getString(_key(key));
      if (raw == null) return null;
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (e, st) {
      assert(false, 'ZenStorage.read("$key") failed: $e\n$st');
      return null;
    }
  }

  @override
  Future<void> delete(String key) async {
    try {
      await (await _instance).remove(_key(key));
    } catch (e, st) {
      assert(false, 'ZenStorage.delete("$key") failed: $e\n$st');
    }
  }

  /// Removes all Zenify query keys from SharedPreferences.
  /// Does NOT touch any other keys in your app's preferences.
  Future<void> clearAll() async {
    final prefs = await _instance;
    final toRemove = prefs
        .getKeys()
        .where((k) => k.startsWith(prefix))
        .toList();
    for (final k in toRemove) {
      await prefs.remove(k);
    }
  }
}
