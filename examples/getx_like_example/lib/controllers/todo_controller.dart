import 'package:zen_state/zen_state.dart';
import '../models/todo.dart';

class TodoController extends ZenController {
  // Reactive list of todos
  final RxList<Todo> todos = <Todo>[].obs();

  // Text editing controller for the new todo input
  final newTodoText = ''.obs();

  // Add a new todo
  void addTodo() {
    if (newTodoText.value.trim().isEmpty) return;

    final newTodo = Todo(
      id: DateTime.now().millisecondsSinceEpoch,
      title: newTodoText.value.trim(),
    );

    // Update the list (creates a new list internally)
    todos.value = [...todos.value, newTodo];

    // Clear the input
    newTodoText.value = '';
  }

  // Toggle a todo's completed status
  void toggleTodo(int id) {
    final updatedTodos = todos.value.map((todo) {
      if (todo.id == id) {
        return todo.copyWith(completed: !todo.completed);
      }
      return todo;
    }).toList();

    todos.value = updatedTodos;
  }

  // Remove a todo
  void removeTodo(int id) {
    todos.value = todos.value.where((todo) => todo.id != id).toList();
  }

  // Example of a worker to log changes
  @override
  void onInit() {
    super.onInit();

    // This will now work with the RxList<Todo>
    everRx(todos, (todoList) {
      ZenLogger.logInfo('Todos list updated. Count: ${todoList.length}');
    });
  }

}