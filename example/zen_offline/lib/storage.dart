import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zenify/zenify.dart';

/// A simple storage implementation using SharedPreferences
class PreferenceStorage implements ZenStorage {
  @override
  Future<void> write(String key, Map<String, dynamic> json) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(json));
  }

  @override
  Future<Map<String, dynamic>?> read(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(key);
    return str != null ? jsonDecode(str) : null;
  }

  @override
  Future<void> delete(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }
}
