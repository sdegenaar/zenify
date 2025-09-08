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
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: ListTile(
          leading: _buildPriorityIndicator(),
          title: Text(
            todo.title,
            style: TextStyle(
              decoration: todo.isCompleted ? TextDecoration.lineThrough : null,
              color: todo.isCompleted ? Colors.grey : null,
              fontWeight:
                  todo.isCompleted ? FontWeight.normal : FontWeight.bold,
            ),
          ),
          subtitle: _buildSubtitle(context),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(
                  todo.isCompleted ? Icons.check_circle : Icons.circle_outlined,
                  color: todo.isCompleted ? Colors.green : Colors.grey,
                ),
                onPressed: onToggle,
                tooltip: todo.isCompleted
                    ? 'Mark as incomplete'
                    : 'Mark as complete',
              ),
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: onEdit,
                tooltip: 'Edit',
              ),
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: onDelete,
                tooltip: 'Delete',
              ),
            ],
          ),
          onTap: onEdit,
        ),
      ),
    );
  }

  Widget _buildPriorityIndicator() {
    Color color;
    IconData icon;

    switch (todo.priority) {
      case 1:
        color = Colors.green;
        icon = Icons.low_priority;
        break;
      case 2:
        color = Colors.orange;
        icon = Icons.priority_high;
        break;
      case 3:
        color = Colors.red;
        icon = Icons.warning_rounded;
        break;
      default:
        color = Colors.grey;
        icon = Icons.circle;
    }

    return CircleAvatar(
      backgroundColor: color.withValues(alpha: 0.2),
      child: Icon(icon, color: color),
    );
  }

  Widget _buildSubtitle(BuildContext context) {
    final List<Widget> subtitleItems = [];

    // Add due date if available
    if (todo.dueDate != null) {
      final bool isOverdue =
          todo.dueDate!.isBefore(DateTime.now()) && !todo.isCompleted;

      subtitleItems.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.event,
              size: 14,
              color: isOverdue ? Colors.red : Colors.grey,
            ),
            const SizedBox(width: 4),
            Text(
              'Due: ${DateFormat.yMMMd().format(todo.dueDate!)}',
              style: TextStyle(
                color: isOverdue ? Colors.red : null,
                fontWeight: isOverdue ? FontWeight.bold : null,
              ),
            ),
          ],
        ),
      );
    }

    // Add notes indicator if available
    if (todo.notes != null && todo.notes!.isNotEmpty) {
      if (subtitleItems.isNotEmpty) {
        subtitleItems.add(const SizedBox(width: 12));
      }

      subtitleItems.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.notes, size: 14, color: Colors.grey),
            const SizedBox(width: 4),
            const Text('Has notes'),
          ],
        ),
      );
    }

    return subtitleItems.isEmpty
        ? const Text('No additional details')
        : Wrap(spacing: 8, children: subtitleItems);
  }
}
