import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zenify/zenify.dart';
import '../models/todo_model.dart';

/// Service responsible for managing Todo data persistence
class TodoService {
  static const String _todosKey = 'zenify_todos';

  /// Effect for loading todos from storage
  final ZenEffect<List<Todo>> loadTodosEffect =
      ZenEffect<List<Todo>>(name: 'loadTodos');

  /// Effect for saving todos to storage
  final ZenEffect<bool> saveTodosEffect = ZenEffect<bool>(name: 'saveTodos');

  /// Effect for clearing all todos from storage
  final ZenEffect<bool> clearTodosEffect = ZenEffect<bool>(name: 'clearTodos');

  /// Loads todos from SharedPreferences
  Future<List<Todo>> loadTodos() async {
    try {
      final result = await loadTodosEffect.run(() async {
        final prefs = await SharedPreferences.getInstance();
        final todosJson = prefs.getStringList(_todosKey);

        if (todosJson == null || todosJson.isEmpty) {
          return <Todo>[];
        }

        return todosJson
            .map((todoJson) => Todo.fromJson(jsonDecode(todoJson)))
            .toList();
      });

      return result ?? <Todo>[];
    } catch (e) {
      ZenLogger.logError('Failed to load todos', e);
      return <Todo>[];
    }
  }

  /// Saves todos to SharedPreferences
  Future<bool> saveTodos(List<Todo> todos) async {
    try {
      final result = await saveTodosEffect.run(() async {
        final prefs = await SharedPreferences.getInstance();

        final todosJson =
            todos.map((todo) => jsonEncode(todo.toJson())).toList();

        final success = await prefs.setStringList(_todosKey, todosJson);
        return success;
      });

      return result ?? false;
    } catch (e) {
      ZenLogger.logError('Failed to save todos', e);
      return false;
    }
  }

  /// Clears all todos from SharedPreferences
  Future<bool> clearAllTodos() async {
    try {
      final result = await clearTodosEffect.run(() async {
        final prefs = await SharedPreferences.getInstance();
        final success = await prefs.remove(_todosKey);
        return success;
      });

      return result ?? false;
    } catch (e) {
      ZenLogger.logError('Failed to clear todos', e);
      return false;
    }
  }
}
