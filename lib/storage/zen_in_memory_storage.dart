import '../query/core/zen_storage.dart';

/// An in-memory [ZenStorage] implementation.
///
/// Useful for:
/// - **Testing**: Inject as a mock without file I/O or platform dependencies.
/// - **Development**: Fast iteration without worrying about stale persisted data.
/// - **Session caching**: Persist data for the duration of an app session only.
///
/// ## Usage
///
/// ```dart
/// // In tests:
/// final storage = InMemoryStorage();
/// ZenQueryCache.instance.setStorage(storage);
///
/// // In development builds:
/// await Zen.init(
///   storage: kDebugMode ? InMemoryStorage() : SharedPreferencesStorage(),
/// );
/// ```
class InMemoryStorage implements ZenStorage {
  final Map<String, Map<String, dynamic>> _store = {};

  @override
  Future<void> write(String key, Map<String, dynamic> json) async {
    _store[key] = Map.unmodifiable(json);
  }

  @override
  Future<Map<String, dynamic>?> read(String key) async {
    final value = _store[key];
    return value != null ? Map<String, dynamic>.from(value) : null;
  }

  @override
  Future<void> delete(String key) async {
    _store.remove(key);
  }

  /// Removes all entries from the in-memory store.
  void clear() => _store.clear();

  /// Returns all keys currently in the store.
  List<String> get keys => List.unmodifiable(_store.keys);

  /// Returns the number of entries in the store.
  int get length => _store.length;

  /// Returns true if the store contains an entry for [key].
  bool containsKey(String key) => _store.containsKey(key);
}
