
import 'package:zenify/zenify.dart';
import '../../shared/models/todo_model.dart';

/// Controller for managing the creation and editing of Todo items
class TodoDetailController extends ZenController {
  final Todo? initialTodo;

  // Constructor that accepts the todo
  TodoDetailController({this.initialTodo});

  // Reactive properties - these need .obs() because UI watches them
  final title = ''.obs();
  final priority = 2.obs();
  final dueDate = Rx<DateTime?>(null);
  final notes = ''.obs();
  final isEditMode = false.obs();

  // Computed properties - these don't need .obs()
  bool get isValid => title.value.trim().isNotEmpty;

  @override
  void onInit() {
    super.onInit();

    // Initialize based on whether we're editing or creating
    if (initialTodo != null) {
      _initForEdit(initialTodo!);
    } else {
      _initForCreate();
    }
  }

  void _initForEdit(Todo todo) {
    title.value = todo.title;
    priority.value = todo.priority;
    dueDate.value = todo.dueDate;
    notes.value = todo.notes ?? '';
    isEditMode.value = true;
  }

  void _initForCreate() {
    title.value = '';
    priority.value = 2; // Default to medium priority
    dueDate.value = null;
    notes.value = '';
    isEditMode.value = false;
  }

  // Setter methods for updating form values
  void setTitle(String value) {
    title.value = value;
  }

  void setPriority(int value) {
    priority.value = value;
  }

  void setDueDate(DateTime value) {
    dueDate.value = value;
  }

  void clearDueDate() {
    dueDate.value = null;
  }

  void setNotes(String value) {
    notes.value = value;
  }

  void resetForm() {
    _initForCreate();
  }

  Todo createTodoFromForm() {
    return Todo(
      id: initialTodo?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: title.value.trim(),
      priority: priority.value,
      dueDate: dueDate.value,
      notes: notes.value.trim().isEmpty ? null : notes.value.trim(),
      isCompleted: initialTodo?.isCompleted ?? false,
      createdAt: initialTodo?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
}