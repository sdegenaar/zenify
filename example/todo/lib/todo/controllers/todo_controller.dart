import 'package:zenify/zenify.dart';
import 'package:intl/intl.dart';
import '../../shared/models/todo_model.dart';
import '../../shared/services/todo_service.dart';

/// Controller for managing Todo items and their state
class TodoController extends ZenController {
  // Dependency injection
  final TodoService todoService = Zen.find<TodoService>();

  // Reactive state
  final RxList<Todo> todos = <Todo>[].obs();
  final RxBool isLoading = false.obs();
  final RxString filterMode = 'all'.obs(); // 'all', 'active', 'completed'
  final RxString sortMode = 'created'.obs(); // 'created', 'priority', 'dueDate'
  final RxString searchQuery = ''.obs();
  final RxBool isEditing = false.obs();
  final RxString statusMessage = ''.obs();

  // Effects for async operations
  late final ZenEffect<Todo> addTodoEffect;
  late final ZenEffect<Todo> updateTodoEffect;
  late final ZenEffect<String> deleteTodoEffect;

  // Worker group for cleanup
  late final ZenWorkerGroup workerGroup;

  // Computed properties
  List<Todo> get filteredTodos {
    var filtered = todos.value.toList(); // Create a copy

    // Apply search filter
    if (searchQuery.value.isNotEmpty) {
      filtered = filtered.where((todo) => 
        todo.title.toLowerCase().contains(searchQuery.value.toLowerCase()) ||
        (todo.notes?.toLowerCase().contains(searchQuery.value.toLowerCase()) ?? false)
      ).toList();
    }

    // Apply status filter
    switch (filterMode.value) {
      case 'active':
        filtered = filtered.where((todo) => !todo.isCompleted).toList();
        break;
      case 'completed':
        filtered = filtered.where((todo) => todo.isCompleted).toList();
        break;
    }

    // Apply sorting
    switch (sortMode.value) {
      case 'created':
        filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case 'priority':
        filtered.sort((a, b) => b.priority.compareTo(a.priority));
        break;
      case 'dueDate':
        filtered.sort((a, b) {
          if (a.dueDate == null && b.dueDate == null) return 0;
          if (a.dueDate == null) return 1;
          if (b.dueDate == null) return -1;
          return a.dueDate!.compareTo(b.dueDate!);
        });
        break;
    }

    return filtered;
  }

  int get activeCount => todos.where((todo) => !todo.isCompleted).length;
  int get completedCount => todos.where((todo) => todo.isCompleted).length;

  TodoController() {
    // Initialize effects
    addTodoEffect = createEffect<Todo>(name: 'addTodo');
    updateTodoEffect = createEffect<Todo>(name: 'updateTodo');
    deleteTodoEffect = createEffect<String>(name: 'deleteTodo');

    // Create worker group
    workerGroup = createWorkerGroup();

    // Set up workers
    _setupWorkers();
  }

  void _setupWorkers() {
    // Watch todos list for changes and save to storage
    workerGroup.add(debounce(
      todos,
      (todosList) {
        _saveTodos();
      },
      const Duration(milliseconds: 500),
    ));

    // Watch filter mode changes
    workerGroup.add(ever(
      filterMode,
      (mode) {
        ZenLogger.logDebug('Filter mode changed to: $mode');
      },
    ));

    // Watch sort mode changes
    workerGroup.add(ever(
      sortMode,
      (mode) {
        ZenLogger.logDebug('Sort mode changed to: $mode');
      },
    ));
  }

  @override
  void onReady() {
    super.onReady();
    loadTodos();
  }

  /// Loads todos from storage
  Future<void> loadTodos() async {
    isLoading.value = true;

    try {
      final loadedTodos = await todoService.loadTodos();
      todos.value = loadedTodos;

      if (loadedTodos.isEmpty) {
        statusMessage.value = 'No todos yet. Add your first one!';
      } else {
        statusMessage.value = 'Loaded ${loadedTodos.length} todos';
      }
    } catch (e) {
      statusMessage.value = 'Error loading todos';
      ZenLogger.logError('Failed to load todos', e);
    } finally {
      isLoading.value = false;
    }
  }

  /// Saves todos to storage
  Future<void> _saveTodos() async {
    try {
      final success = await todoService.saveTodos(todos.value);
      if (success) {
        ZenLogger.logDebug('Todos saved successfully');
      } else {
        ZenLogger.logWarning('Failed to save todos');
      }
    } catch (e) {
      ZenLogger.logError('Error saving todos', e);
    }
  }

  /// Adds a new todo
  Future<void> addTodo(String title, {int priority = 1, DateTime? dueDate, String? notes}) async {
    if (title.trim().isEmpty) return;

    try {
      await addTodoEffect.run(() async {
        final newTodo = Todo(
          title: title.trim(),
          priority: priority,
          dueDate: dueDate,
          notes: notes,
        );

        todos.add(newTodo);
        statusMessage.value = 'Todo added';
        return newTodo;
      });
    } catch (e) {
      statusMessage.value = 'Failed to add todo';
      ZenLogger.logError('Error adding todo', e);
    }
  }

  /// Updates an existing todo
  Future<void> updateTodo(Todo todo) async {
    try {
      await updateTodoEffect.run(() async {
        final index = todos.value.indexWhere((t) => t.id == todo.id);
        if (index >= 0) {
          todos[index] = todo.copyWith(updatedAt: DateTime.now());
          statusMessage.value = 'Todo updated';
        }
        return todo;
      });
    } catch (e) {
      statusMessage.value = 'Failed to update todo';
      ZenLogger.logError('Error updating todo', e);
    }
  }

  /// Toggles the completion status of a todo
  void toggleTodoStatus(String id) {
    final index = todos.value.indexWhere((todo) => todo.id == id);
    if (index >= 0) {
      final todo = todos[index];
      todos[index] = todo.copyWith(
        isCompleted: !todo.isCompleted,
        updatedAt: DateTime.now(),
      );
      statusMessage.value = todo.isCompleted ? 'Todo marked as active' : 'Todo completed';
    }
  }

  /// Deletes a todo
  Future<void> deleteTodo(String id) async {
    try {
      await deleteTodoEffect.run(() async {
        final index = todos.value.indexWhere((todo) => todo.id == id);
        if (index >= 0) {
          todos.value.removeAt(index);
          todos.refresh();
          statusMessage.value = 'Todo deleted';
        }
        return id;
      });
    } catch (e) {
      statusMessage.value = 'Failed to delete todo';
      ZenLogger.logError('Error deleting todo', e);
    }
  }

  /// Clears all completed todos
  Future<void> clearCompletedTodos() async {
    try {
      final completedCount = todos.where((todo) => todo.isCompleted).length;
      todos.value.removeWhere((todo) => todo.isCompleted);
      statusMessage.value = 'Cleared $completedCount completed todos';
    } catch (e) {
      statusMessage.value = 'Failed to clear completed todos';
      ZenLogger.logError('Error clearing completed todos', e);
    }
  }

  /// Sets the filter mode
  void setFilterMode(String mode) {
    filterMode.value = mode;
  }

  /// Sets the sort mode
  void setSortMode(String mode) {
    sortMode.value = mode;
  }

  /// Sets the search query
  void setSearchQuery(String query) {
    searchQuery.value = query;
  }

  /// Formats a date for display
  String formatDate(DateTime? date) {
    if (date == null) return 'No date';
    return DateFormat.yMMMd().format(date);
  }

  @override
  void onDispose() {
    workerGroup.dispose();
    super.onDispose();
  }
}
