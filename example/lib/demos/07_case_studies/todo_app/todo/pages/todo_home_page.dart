import 'package:flutter/material.dart';
import 'package:zenify/zenify.dart';
import '../../../../../shared/widgets/showcase_style.dart';
import '../../shared/models/todo_model.dart';
import '../controllers/todo_controller.dart';
import '../controllers/todo_detail_controller.dart';
import '../widgets/todo_filter_bar.dart';
import '../widgets/todo_item.dart';
import 'todo_detail_page.dart';

class TodoHomePage extends ZenView<TodoController> {
  const TodoHomePage({super.key});

  @override
  Widget build(BuildContext context, TodoController controller) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Zenify Tasks',
          style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5),
        ),
        backgroundColor: ShowcaseStyle.primaryColor,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back to Showcase',
          onPressed: () =>
              Navigator.of(context, rootNavigator: true).maybePop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search tasks',
            onPressed: () => _showSearchDialog(context, controller),
          ),
          IconButton(
            icon: const Icon(Icons.sort),
            tooltip: 'Sort tasks',
            onPressed: () => _showSortDialog(context, controller),
          ),
        ],
      ),
      body: Column(
        children: [
          // Modern Progress Dashboard Card
          ZenObserver(() {
            final total = controller.todos.length;
            final completed = controller.completedCount;
            final progress = total > 0 ? (completed / total) : 0.0;
            final percentage = (progress * 100).toInt();

            return Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? const [Color(0xFF1E1B4B), Color(0xFF31104B)]
                      : const [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: ShowcaseStyle.primaryColor.withValues(alpha: 0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Daily Progress',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            total == 0
                                ? 'No tasks today'
                                : '$completed of $total Completed',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          '$percentage%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFF4ADE80), // Emerald Green
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),

          // Filter bar
          TodoFilterBar(controller: controller),

          // Status message banner
          ZenObserver(() => controller.statusMessage.value.isNotEmpty
              ? Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  color: ShowcaseStyle.primaryColor.withValues(alpha: 0.1),
                  width: double.infinity,
                  child: Row(
                    children: [
                      Icon(Icons.info_outline,
                          size: 16, color: ShowcaseStyle.primaryColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          controller.statusMessage.value,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: ShowcaseStyle.primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink()),

          // Todo list
          Expanded(
            child: ZenObserver(() {
              if (controller.isLoading.value) {
                return const Center(child: CircularProgressIndicator());
              }

              final todos = controller.filteredTodos;

              if (todos.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: ShowcaseStyle.primaryColor
                                .withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.checklist_rounded,
                            size: 56,
                            color: ShowcaseStyle.primaryColor,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          controller.searchQuery.value.isNotEmpty
                              ? 'No tasks match "${controller.searchQuery.value}"'
                              : controller.filterMode.value != 'all'
                                  ? 'No ${controller.filterMode.value} tasks'
                                  : 'All clear for now!',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          controller.searchQuery.value.isNotEmpty
                              ? 'Try searching with a different keyword'
                              : 'Create a new task with due dates and priority tags',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        if (controller.searchQuery.value.isEmpty &&
                            controller.filterMode.value == 'all')
                          ElevatedButton.icon(
                            onPressed: () =>
                                _navigateToDetailPage(context, controller),
                            icon: const Icon(Icons.add),
                            label: const Text('Add your first task'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: ShowcaseStyle.primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 12),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.builder(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                itemCount: todos.length,
                itemBuilder: (context, index) {
                  final todo = todos[index];
                  return TodoItem(
                    key: ValueKey(todo.id),
                    todo: todo,
                    onToggle: () => controller.toggleTodoStatus(todo.id),
                    onEdit: () =>
                        _navigateToDetailPage(context, controller, todo: todo),
                    onDelete: () =>
                        _showDeleteConfirmation(context, controller, todo),
                  );
                },
              );
            }),
          ),

          // Bottom stats bar
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 18),
            decoration: BoxDecoration(
              color: isDark ? theme.colorScheme.surface : Colors.grey.shade100,
              border: Border(
                top: BorderSide(
                  color: isDark ? Colors.white12 : Colors.grey.shade300,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Todo counts
                ZenObserver(() => Text(
                      '${controller.activeCount} active • ${controller.completedCount} completed',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    )),

                // Clear completed button
                ZenObserver(() => controller.completedCount > 0
                    ? TextButton.icon(
                        onPressed: () => _showClearCompletedConfirmation(
                            context, controller),
                        icon: const Icon(Icons.delete_sweep_outlined,
                            size: 16, color: Colors.red),
                        label: const Text(
                          'Clear completed',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    : const SizedBox.shrink()),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToDetailPage(context, controller),
        backgroundColor: ShowcaseStyle.primaryColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_task_rounded),
        label: const Text('Add Task',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  void _navigateToDetailPage(BuildContext context, TodoController controller,
      {Todo? todo}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ZenProvider.create(
          create: () => TodoDetailController(
            todoController: controller,
            initialTodo: todo,
          ),
          child: TodoDetailPage(todo: todo),
        ),
      ),
    );
  }

  void _showDeleteConfirmation(
      BuildContext context, TodoController controller, Todo todo) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Task'),
        content: Text('Are you sure you want to delete "${todo.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              controller.deleteTodo(todo.id);
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showClearCompletedConfirmation(
      BuildContext context, TodoController controller) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Completed Tasks'),
        content: Text(
            'Are you sure you want to delete all ${controller.completedCount} completed tasks?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              controller.clearCompletedTodos();
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  void _showSearchDialog(BuildContext context, TodoController controller) {
    final searchController =
        TextEditingController(text: controller.searchQuery.value);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Search Tasks'),
        content: TextField(
          controller: searchController,
          decoration: const InputDecoration(
            hintText: 'Enter task keyword...',
            prefixIcon: Icon(Icons.search),
          ),
          autofocus: true,
          onSubmitted: (value) {
            controller.setSearchQuery(value);
            Navigator.of(context).pop();
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              controller.setSearchQuery('');
              Navigator.of(context).pop();
            },
            child: const Text('Clear'),
          ),
          ElevatedButton(
            onPressed: () {
              controller.setSearchQuery(searchController.text);
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: ShowcaseStyle.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Search'),
          ),
        ],
      ),
    );
  }

  void _showSortDialog(BuildContext context, TodoController controller) {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Sort Tasks By'),
        children: [
          SimpleDialogOption(
            onPressed: () {
              controller.setSortMode('created');
              Navigator.of(context).pop();
            },
            child: const Row(
              children: [
                Icon(Icons.access_time, size: 20),
                SizedBox(width: 12),
                Text('Creation Date (Newest First)'),
              ],
            ),
          ),
          SimpleDialogOption(
            onPressed: () {
              controller.setSortMode('priority');
              Navigator.of(context).pop();
            },
            child: const Row(
              children: [
                Icon(Icons.flag, size: 20),
                SizedBox(width: 12),
                Text('Priority (High to Low)'),
              ],
            ),
          ),
          SimpleDialogOption(
            onPressed: () {
              controller.setSortMode('dueDate');
              Navigator.of(context).pop();
            },
            child: const Row(
              children: [
                Icon(Icons.event, size: 20),
                SizedBox(width: 12),
                Text('Due Date (Earliest First)'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
