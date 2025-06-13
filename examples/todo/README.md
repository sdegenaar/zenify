# Zenify Todo App Example

A comprehensive todo app example showcasing Zenify's core features with manual dependency injection patterns. This example demonstrates the foundational concepts of Zenify in a clean, understandable way.

## Why This Example?

This Todo app is designed as an introductory example that shows:

* Manual DI Approach: Clear demonstration of how Zenify eliminates boilerplate
* Core Concepts: Focus on essential Zenify features without complexity
* Before & After: Shows what traditional Flutter DI looks like vs. Zenify's approach

For Advanced Patterns: Check out the e-commerce example which demonstrates ZenScopeWidget, complex module hierarchies, and advanced architectural patterns.

## Manual vs Automatic Dependency Injection

### Traditional Flutter (What You'd Normally Write)

```dart
// Manual controller instantiation and lifecycle management
class TodoHomePage extends StatefulWidget {
  @override
  _TodoHomePageState createState() => _TodoHomePageState();
}

class _TodoHomePageState extends State<TodoHomePage> {
  late TodoController controller;
  late TodoService todoService;

  @override
  void initState() {
    super.initState();
    // Manual dependency creation and injection
    todoService = TodoService();
    controller = TodoController(todoService);
    controller.loadTodos();
  }

  @override
  void dispose() {
    // Manual cleanup
    controller.dispose();
    super.dispose();
  }
  // ... rest of implementation
}
```


### With Zenify (What This Example Shows)

```dart
// Automatic controller lifecycle and dependency injection
class TodoHomePage extends ZenView<TodoController> {
  const TodoHomePage({super.key});

  @override
  TodoController Function()? get createController => () => TodoController();

  @override
  Widget build(BuildContext context) {
    // Controller and dependencies automatically managed
    return Scaffold(/* ... */);
  }
  // No manual disposal needed - Zenify handles it!
}
```


Key Benefits Demonstrated:

* Eliminated Boilerplate: No manual controller instantiation or disposal
* Automatic Lifecycle: Controllers are created and disposed automatically
* Dependency Resolution: Services injected via Zen.get<TodoService>()
* Memory Safety: No memory leaks from forgotten disposals

## Project Structure

```
lib/
├── shared/
│   ├── models/
│   │   └── todo_model.dart       # Data model for Todo items
│   └── services/
│       └── todo_service.dart     # Service for persistence operations
├── todo/
│   ├── controllers/
│   │   ├── todo_controller.dart        # Main controller (shows manual DI)
│   │   └── todo_detail_controller.dart # Detail controller
│   ├── modules/
│   │   └── todo_module.dart      # Module registration
│   ├── pages/
│   │   ├── todo_home_page.dart   # ZenView implementation
│   │   └── todo_detail_page.dart # Form handling
│   └── widgets/
│       ├── todo_item.dart        # Reusable todo item
│       └── todo_filter_bar.dart  # Filter controls
└── main.dart                     # App setup and module registration
```


## Features

* Reactive State Management: Uses Zenify's reactive state (Rx types) for automatic UI updates
* Manual Dependency Injection: Clear, explicit dependency resolution patterns
* Async Operations: Uses ZenEffects for handling loading, error, and success states
* Reactive Workers: Implements debounce and ever workers for reactive side effects
* Persistent Storage: Stores todos using SharedPreferences
* Clean Architecture: Follows a modular, maintainable code structure
* Form Validation: Shows form validation with reactive state
* Filtering & Sorting: Implements filtering and sorting of todos
* Search Functionality: Provides search capability across todos

## Key Zenify Features Demonstrated

### 1. Manual Controller Creation

```dart
// In TodoHomePage
@override
TodoController Function()? get createController => () => TodoController();
```


### 2. Service Injection

```dart
// In TodoController
final TodoService todoService = Zen.find<TodoService>();
```


### 3. Reactive State

```dart
final RxList<Todo> todos = <Todo>[].obs();
final RxString searchQuery = ''.obs();
final RxBool isLoading = false.obs();
```


### 4. Module Registration

```dart
// In main.dart
Zen.registerModules([
  TodoModule(),
]);
```


## Usage

This example demonstrates a complete todo application with:

* Create, read, update, and delete todos
* Mark todos as complete/incomplete
* Filter todos by status (all, active, completed)
* Sort todos by creation date, priority, or due date
* Search todos by title or notes
* Set priority levels and due dates
* Add notes to todos
* Persist todos to device storage

## Learning Path

1. Start Here: Todo app (manual DI patterns)
2. Next: Counter example (reactive state deep dive)
3. Advanced: E-commerce example (ZenScopeWidget, complex modules)

## Best Practices Shown

1. Manual Dependency Resolution: Explicit Zen.find<T>() calls
2. Reactive Programming: State changes automatically update the UI
3. Error Handling: Proper error handling with ZenEffects
4. Resource Management: Automatic cleanup via ZenController lifecycle
5. Computed Properties: Derived state with getters
6. Immutable Updates: Using copyWith for immutable state updates
7. Consistent Logging: Using ZenLogger for debugging
8. Modular Design: Clear separation of concerns with modules

## Next Steps

Ready for more complex scenarios? Check out:

* E-commerce Example: Advanced patterns with ZenScopeWidget
* Counter Example: Deep dive into reactive workers and effects
* Zenify Documentation: Complete API reference

Pro Tip: This example prioritizes clarity and learning. For production apps with complex dependency hierarchies, consider the patterns shown in the e-commerce example.