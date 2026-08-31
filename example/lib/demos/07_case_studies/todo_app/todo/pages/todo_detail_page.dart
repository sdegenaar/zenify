import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:zenify/zenify.dart';
import '../../../../../shared/widgets/showcase_style.dart';
import '../../shared/models/todo_model.dart';
import '../controllers/todo_detail_controller.dart';

/// Todo Detail Page with automatic controller cleanup via ZenProvider
class TodoDetailPage extends ZenView<TodoDetailController> {
  final Todo? todo;
  const TodoDetailPage({super.key, this.todo});

  @override
  Widget build(BuildContext context, TodoDetailController controller) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: ZenObserver(() => Text(
              controller.isEditMode.value ? 'Edit Todo' : 'Create Todo',
              style: const TextStyle(fontWeight: FontWeight.bold),
            )),
        backgroundColor: ShowcaseStyle.primaryColor,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          // Reset button for create mode
          ZenObserver(() => !controller.isEditMode.value &&
                  (controller.title.value.isNotEmpty ||
                      controller.notes.value.isNotEmpty ||
                      controller.priority.value != 2 ||
                      controller.dueDate.value != null)
              ? IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Reset form',
                  onPressed: () {
                    controller.resetForm();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Form reset')),
                    );
                  },
                )
              : const SizedBox.shrink()),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Mode Banner
            ZenObserver(() {
              final isEdit = controller.isEditMode.value;
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: ShowcaseStyle.containerDecoration(
                  context,
                  color: isEdit ? Colors.teal : Colors.blue,
                  radius: 12,
                ),
                child: Row(
                  children: [
                    Icon(
                      isEdit ? Icons.edit_note : Icons.add_task,
                      color: ShowcaseStyle.accentHeader(
                          context, isEdit ? Colors.teal : Colors.blue),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isEdit
                            ? 'Editing task: "${todo?.title}"'
                            : 'Add a new task to your list with priority and optional due date.',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: ShowcaseStyle.accentHeader(
                              context, isEdit ? Colors.teal : Colors.blue),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 24),

            // Title section
            _buildSectionHeader('Task Title', Icons.title, isDark),
            const SizedBox(height: 8),
            TextField(
              controller: controller.titleController,
              decoration: InputDecoration(
                hintText: 'What needs to be done?',
                prefixIcon: const Icon(Icons.edit_outlined),
                filled: true,
                fillColor: isDark
                    ? theme.colorScheme.surfaceContainerHighest
                    : Colors.grey.shade50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDark ? Colors.white24 : Colors.grey.shade300,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDark ? Colors.white12 : Colors.grey.shade300,
                  ),
                ),
              ),
              textCapitalization: TextCapitalization.sentences,
              autofocus: !controller.isEditMode.value,
            ),
            const SizedBox(height: 24),

            // Priority selection
            _buildSectionHeader('Priority Level', Icons.flag_outlined, isDark),
            const SizedBox(height: 8),
            ZenObserver(() {
              final current = controller.priority.value;
              return Row(
                children: [
                  _buildPriorityCard(
                    context,
                    label: 'Low',
                    value: 1,
                    selected: current == 1,
                    color: Colors.green,
                    icon: Icons.low_priority,
                    onTap: () => controller.setPriority(1),
                  ),
                  const SizedBox(width: 10),
                  _buildPriorityCard(
                    context,
                    label: 'Medium',
                    value: 2,
                    selected: current == 2,
                    color: Colors.orange,
                    icon: Icons.priority_high,
                    onTap: () => controller.setPriority(2),
                  ),
                  const SizedBox(width: 10),
                  _buildPriorityCard(
                    context,
                    label: 'High',
                    value: 3,
                    selected: current == 3,
                    color: Colors.red,
                    icon: Icons.warning_amber_rounded,
                    onTap: () => controller.setPriority(3),
                  ),
                ],
              );
            }),
            const SizedBox(height: 24),

            // Due Date selection
            _buildSectionHeader(
                'Due Date (Optional)', Icons.calendar_month_outlined, isDark),
            const SizedBox(height: 8),
            ZenObserver(() {
              final date = controller.dueDate.value;
              final hasDate = date != null;
              return InkWell(
                onTap: () => _selectDate(context, controller),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: isDark
                        ? theme.colorScheme.surfaceContainerHighest
                        : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: hasDate
                          ? ShowcaseStyle.primaryColor
                          : (isDark ? Colors.white12 : Colors.grey.shade300),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 20,
                        color:
                            hasDate ? ShowcaseStyle.primaryColor : Colors.grey,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          hasDate
                              ? DateFormat.yMMMEd().format(date)
                              : 'Tap to select due date',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight:
                                hasDate ? FontWeight.bold : FontWeight.normal,
                            color: hasDate ? null : Colors.grey,
                          ),
                        ),
                      ),
                      if (hasDate)
                        IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          tooltip: 'Clear due date',
                          visualDensity: VisualDensity.compact,
                          onPressed: controller.clearDueDate,
                        )
                      else
                        const Icon(Icons.chevron_right, color: Colors.grey),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 24),

            // Notes field
            _buildSectionHeader(
                'Notes & Details (Optional)', Icons.notes_outlined, isDark),
            const SizedBox(height: 8),
            TextField(
              controller: controller.notesController,
              decoration: InputDecoration(
                hintText: 'Add details, instructions, or sub-tasks...',
                filled: true,
                fillColor: isDark
                    ? theme.colorScheme.surfaceContainerHighest
                    : Colors.grey.shade50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDark ? Colors.white24 : Colors.grey.shade300,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDark ? Colors.white12 : Colors.grey.shade300,
                  ),
                ),
                alignLabelWithHint: true,
              ),
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 32),

            // Action Buttons
            ZenObserver(() {
              final isValid = controller.isValid;
              final isEdit = controller.isEditMode.value;

              return Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed:
                          isValid ? () => _saveTodo(context, controller) : null,
                      icon: Icon(isEdit ? Icons.check : Icons.add_task),
                      label: Text(
                        isEdit ? 'Save Changes' : 'Create Task',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ShowcaseStyle.primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: isValid ? 2 : 0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child:
                          const Text('Cancel', style: TextStyle(fontSize: 15)),
                    ),
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, bool isDark) {
    return Row(
      children: [
        Icon(icon, size: 18, color: isDark ? Colors.white70 : Colors.black87),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildPriorityCard(
    BuildContext context, {
    required String label,
    required int value,
    required bool selected,
    required Color color,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: isDark ? 0.3 : 0.15)
                : (isDark
                    ? Theme.of(context).colorScheme.surfaceContainerHighest
                    : Colors.grey.shade100),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? color : Colors.transparent,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: selected ? color : Colors.grey, size: 20),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  color: selected ? color : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectDate(
      BuildContext context, TodoDetailController controller) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: controller.dueDate.value ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      helpText: 'Select task due date',
    );

    if (picked != null) {
      controller.setDueDate(picked);
    }
  }

  void _saveTodo(BuildContext context, TodoDetailController controller) {
    try {
      final todo = controller.createTodoFromForm();

      if (controller.isEditMode.value) {
        controller.todoController.updateTodo(todo);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Updated "${todo.title}"'),
            backgroundColor: Colors.teal,
          ),
        );
      } else {
        controller.todoController.addTodo(
          todo.title,
          priority: todo.priority,
          dueDate: todo.dueDate,
          notes: todo.notes,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Created task "${todo.title}"'),
            backgroundColor: Colors.green,
          ),
        );
      }

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
