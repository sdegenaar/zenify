import 'package:flutter/material.dart';
import 'package:zenify/zenify.dart';
import 'package:intl/intl.dart';
import '../../shared/models/todo_model.dart';
import '../controllers/todo_controller.dart';
import '../controllers/todo_detail_controller.dart';

/// Todo Detail Page with manual controller cleanup
///
/// NOTE: This example shows manual controller management for educational purposes.
/// For a more advanced approach using automatic cleanup with scoped modules,
/// see the e-commerce example which demonstrates full navigation with ZenModulePage.
///
/// ZenModulePage provides:
/// - Automatic scope creation and disposal
/// - Module-based dependency injection
/// - Clean separation of concerns
/// - No manual cleanup required
class TodoDetailPage extends ZenView<TodoDetailController> {
  final Todo? todo;
  const TodoDetailPage({super.key, this.todo});

  @override
  TodoDetailController Function()? get createController =>
          () => TodoDetailController(initialTodo: todo);

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Handle back navigation to clean up the controller
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          // Manually delete the controller when navigating back
          // This ensures proper cleanup and prevents memory leaks
          Zen.delete<TodoDetailController>();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Obx(() => Text(
              controller.isEditMode.value ? 'Edit Todo' : 'Create Todo'
          )),
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          // Override the back button to ensure cleanup
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              // Delete controller before popping
              Zen.delete<TodoDetailController>();
              Navigator.of(context).pop();
            },
          ),
          actions: [
            // Reset button for create mode
            Obx(() => !controller.isEditMode.value &&
                (controller.title.value.isNotEmpty ||
                    controller.notes.value.isNotEmpty ||
                    controller.priority.value != 2 ||
                    controller.dueDate.value != null)
                ? IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                controller.resetForm();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Form reset')),
                );
              },
              tooltip: 'Reset form',
            )
                : const SizedBox.shrink()),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title field
              _buildSectionLabel('Title'),
              const SizedBox(height: 8),
              Obx(() => TextField(
                controller: TextEditingController(text: controller.title.value)
                  ..selection = TextSelection.fromPosition(
                    TextPosition(offset: controller.title.value.length),
                  ),
                decoration: InputDecoration(
                  hintText: 'Enter todo title',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  errorText: controller.title.value.isEmpty &&
                      controller.title.value != controller.initialTodo?.title
                      ? 'Title is required'
                      : null,
                ),
                onChanged: controller.setTitle,
                textCapitalization: TextCapitalization.sentences,
                autofocus: !controller.isEditMode.value,
              )),
              const SizedBox(height: 24),

              // Priority selection
              _buildSectionLabel('Priority'),
              const SizedBox(height: 8),
              Obx(() => Card(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: SegmentedButton<int>(
                    segments: const [
                      ButtonSegment<int>(
                        value: 1,
                        label: Text('Low'),
                        icon: Icon(Icons.low_priority, color: Colors.green),
                      ),
                      ButtonSegment<int>(
                        value: 2,
                        label: Text('Medium'),
                        icon: Icon(Icons.priority_high, color: Colors.orange),
                      ),
                      ButtonSegment<int>(
                        value: 3,
                        label: Text('High'),
                        icon: Icon(Icons.warning_rounded, color: Colors.red),
                      ),
                    ],
                    selected: {controller.priority.value},
                    onSelectionChanged: (Set<int> selection) {
                      if (selection.isNotEmpty) {
                        controller.setPriority(selection.first);
                      }
                    },
                  ),
                ),
              )),
              const SizedBox(height: 24),

              // Due date selection
              _buildSectionLabel('Due Date (Optional)'),
              const SizedBox(height: 8),
              Obx(() => Card(
                child: ListTile(
                  leading: const Icon(Icons.calendar_today),
                  title: Text(
                    controller.dueDate.value != null
                        ? DateFormat.yMMMd().format(controller.dueDate.value!)
                        : 'No due date set',
                    style: TextStyle(
                      color: controller.dueDate.value != null
                          ? null
                          : Colors.grey.shade600,
                    ),
                  ),
                  trailing: controller.dueDate.value != null
                      ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: controller.clearDueDate,
                    tooltip: 'Clear due date',
                  )
                      : null,
                  onTap: () => _selectDate(context),
                ),
              )),
              const SizedBox(height: 24),

              // Notes field
              _buildSectionLabel('Notes (Optional)'),
              const SizedBox(height: 8),
              Obx(() => TextField(
                controller: TextEditingController(text: controller.notes.value)
                  ..selection = TextSelection.fromPosition(
                    TextPosition(offset: controller.notes.value.length),
                  ),
                decoration: InputDecoration(
                  hintText: 'Add notes, details, or reminders...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignLabelWithHint: true,
                ),
                onChanged: controller.setNotes,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
              )),
              const SizedBox(height: 32),

              // Form validation summary (helpful feedback)
              Obx(() => !controller.isValid
                  ? Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  border: Border.all(color: Colors.orange.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange.shade700),
                    const SizedBox(width: 8),
                    Text(
                      'Please enter a title to continue',
                      style: TextStyle(color: Colors.orange.shade700),
                    ),
                  ],
                ),
              )
                  : const SizedBox.shrink()),

              // Save button
              SizedBox(
                width: double.infinity,
                child: Obx(() => ElevatedButton(
                  onPressed: controller.isValid ? () => _saveTodo(context) : null,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    controller.isEditMode.value ? 'Update Todo' : 'Create Todo',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                )),
              ),

              // Cancel button
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    // Delete controller before popping
                    Zen.delete<TodoDetailController>();
                    Navigator.of(context).pop();
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 16,
      ),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: controller.dueDate.value ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      helpText: 'Select due date',
      cancelText: 'Cancel',
      confirmText: 'Set Date',
    );

    if (picked != null) {
      controller.setDueDate(picked);
    }
  }

  void _saveTodo(BuildContext context) {
    try {
      final todoController = Zen.find<TodoController>();
      final todo = controller.createTodoFromForm();

      if (controller.isEditMode.value) {
        todoController.updateTodo(todo);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Todo updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        todoController.addTodo(
          todo.title,
          priority: todo.priority,
          dueDate: todo.dueDate,
          notes: todo.notes,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Todo created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Delete controller before navigating back
      Zen.delete<TodoDetailController>();
      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving todo: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}