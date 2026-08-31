import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../shared/models/todo_model.dart';

/// Widget for displaying a single Todo item in a list
class TodoItem extends StatelessWidget {
  final Todo todo;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const TodoItem({
    super.key,
    required this.todo,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Color priorityColor;
    String priorityLabel;
    switch (todo.priority) {
      case 1:
        priorityColor = Colors.green;
        priorityLabel = 'Low';
        break;
      case 2:
        priorityColor = Colors.orange;
        priorityLabel = 'Medium';
        break;
      case 3:
        priorityColor = Colors.red;
        priorityLabel = 'High';
        break;
      default:
        priorityColor = Colors.grey;
        priorityLabel = 'Normal';
    }

    final isOverdue = todo.dueDate != null &&
        todo.dueDate!.isBefore(DateTime.now()) &&
        !todo.isCompleted;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color:
            isDark ? theme.colorScheme.surfaceContainerHighest : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: todo.isCompleted
              ? (isDark ? Colors.white12 : Colors.grey.shade200)
              : priorityColor.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Checkbox Toggle
              IconButton(
                icon: Icon(
                  todo.isCompleted
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: todo.isCompleted ? Colors.green : Colors.grey,
                  size: 24,
                ),
                onPressed: onToggle,
                tooltip: todo.isCompleted ? 'Mark incomplete' : 'Mark complete',
              ),
              const SizedBox(width: 8),

              // Todo Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      todo.title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: todo.isCompleted
                            ? FontWeight.normal
                            : FontWeight.w600,
                        decoration: todo.isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                        color: todo.isCompleted
                            ? Colors.grey
                            : (isDark ? Colors.white : Colors.black87),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        // Priority Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: priorityColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            priorityLabel,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: priorityColor,
                            ),
                          ),
                        ),

                        // Due date badge
                        if (todo.dueDate != null)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.event,
                                size: 12,
                                color: isOverdue ? Colors.red : Colors.grey,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                DateFormat.yMMMd().format(todo.dueDate!),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: isOverdue
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: isOverdue ? Colors.red : Colors.grey,
                                ),
                              ),
                            ],
                          ),

                        // Notes badge
                        if (todo.notes != null && todo.notes!.isNotEmpty)
                          const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.notes, size: 12, color: Colors.grey),
                              SizedBox(width: 3),
                              Text(
                                'Notes',
                                style:
                                    TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // Action buttons
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    tooltip: 'Edit',
                    visualDensity: VisualDensity.compact,
                    onPressed: onEdit,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        size: 20, color: Colors.red),
                    tooltip: 'Delete',
                    visualDensity: VisualDensity.compact,
                    onPressed: onDelete,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
