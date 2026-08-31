import 'package:flutter/material.dart';
import 'package:zenify/zenify.dart';
import '../../shared/models/todo_model.dart';
import 'todo_controller.dart';

/// Controller for managing the creation and editing of Todo items
class TodoDetailController extends ZenController {
  final TodoController todoController;
  final Todo? initialTodo;

  // Constructor that accepts the parent controller and optional initial todo
  TodoDetailController({
    required this.todoController,
    this.initialTodo,
  });

  // Reactive properties
  final title = ''.obs();
  final priority = 2.obs(); // 1 = Low, 2 = Medium, 3 = High
  final dueDate = Rx<DateTime?>(null);
  final notes = ''.obs();
  final isEditMode = false.obs();

  // Persistent text controllers to prevent keystroke resets
  late final TextEditingController titleController;
  late final TextEditingController notesController;

  // Computed properties
  bool get isValid => title.value.trim().isNotEmpty;

  @override
  void onInit() {
    super.onInit();
    titleController = TextEditingController();
    notesController = TextEditingController();

    titleController.addListener(() {
      title.value = titleController.text;
    });

    notesController.addListener(() {
      notes.value = notesController.text;
    });

    // Initialize based on whether we're editing or creating
    if (initialTodo != null) {
      _initForEdit(initialTodo!);
    } else {
      _initForCreate();
    }
  }

  void _initForEdit(Todo todo) {
    titleController.text = todo.title;
    notesController.text = todo.notes ?? '';
    title.value = todo.title;
    priority.value = todo.priority;
    dueDate.value = todo.dueDate;
    notes.value = todo.notes ?? '';
    isEditMode.value = true;
  }

  void _initForCreate() {
    titleController.clear();
    notesController.clear();
    title.value = '';
    priority.value = 2; // Default to medium priority
    dueDate.value = null;
    notes.value = '';
    isEditMode.value = false;
  }

  // Setter methods for updating form values
  void setPriority(int value) {
    priority.value = value;
  }

  void setDueDate(DateTime value) {
    dueDate.value = value;
  }

  void clearDueDate() {
    dueDate.value = null;
  }

  void resetForm() {
    _initForCreate();
  }

  Todo createTodoFromForm() {
    return Todo(
      id: initialTodo?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: titleController.text.trim(),
      priority: priority.value,
      dueDate: dueDate.value,
      notes: notesController.text.trim().isEmpty
          ? null
          : notesController.text.trim(),
      isCompleted: initialTodo?.isCompleted ?? false,
      createdAt: initialTodo?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  @override
  void onClose() {
    titleController.dispose();
    notesController.dispose();
    super.onClose();
  }
}
