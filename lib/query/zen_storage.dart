import 'dart:async';

/// Interface for persisting query data.
///
/// Implement this to enable offline support and hydration for ZenQuery.
///
/// Example with SharedPreferences:
/// ```dart
/// class SharedPrefsStorage implements ZenStorage {
///   @override
///   Future<void> write(String key, Map<String, dynamic> json) async {
///     final prefs = await SharedPreferences.getInstance();
///     await prefs.setString(key, jsonEncode(json));
///   }
///   // ... implement read and delete
/// }
/// ```
abstract class ZenStorage {
  /// Write data to storage.
  ///
  /// [key] is the unique key for the query.
  /// [json] is the serialized data and metadata.
  Future<void> write(String key, Map<String, dynamic> json);

  /// Read data from storage.
  ///
  /// Returns null if no data exists for the key.
  Future<Map<String, dynamic>?> read(String key);

  /// Delete data from storage.
  Future<void> delete(String key);
}
