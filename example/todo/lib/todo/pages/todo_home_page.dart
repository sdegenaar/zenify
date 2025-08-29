import 'package:flutter/material.dart';
import 'package:todo/todo/pages/todo_detail_page.dart';
import 'package:zenify/zenify.dart';
import '../../shared/models/todo_model.dart';
import '../controllers/todo_controller.dart';
import '../widgets/todo_item.dart';
import '../widgets/todo_filter_bar.dart';

class TodoHomePage extends ZenView<TodoController> {
  const TodoHomePage({super.key});

  @override
  TodoController Function()? get createController => () => TodoController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Zenify Todo'),
        backgroundColor: Theme
            .of(context)
            .colorScheme
            .primaryContainer,
        actions: [
          // Search button
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _showSearchDialog(context),
          ),
          // Sort button
          IconButton(
            icon: const Icon(Icons.sort),
            onPressed: () => _showSortDialog(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter bar
          TodoFilterBar(controller: controller),

          // Status message
          Obx(() =>
          controller.statusMessage.value.isNotEmpty
              ? Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            color: Theme
                .of(context)
                .colorScheme
                .secondaryContainer,
            width: double.infinity,
            child: Text(
              controller.statusMessage.value,
              style: TextStyle(
                color: Theme
                    .of(context)
                    .colorScheme
                    .onSecondaryContainer,
              ),
            ),
          )
              : const SizedBox.shrink()),

          // Todo list
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value) {
                return const Center(child: CircularProgressIndicator());
              }

              final todos = controller.filteredTodos;

              if (todos.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 64,
                        color: Theme
                            .of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        controller.searchQuery.value.isNotEmpty
                            ? 'No todos match your search'
                            : controller.filterMode.value != 'all'
                            ? 'No ${controller.filterMode.value} todos'
                            : 'No todos yet',
                        style: Theme
                            .of(context)
                            .textTheme
                            .titleMedium,
                      ),
                      const SizedBox(height: 8),
                      if (controller.searchQuery.value.isEmpty &&
                          controller.filterMode.value == 'all')
                        ElevatedButton.icon(
                          onPressed: () => _navigateToDetailPage(context),
                          icon: const Icon(Icons.add),
                          label: const Text('Add your first todo'),
                        ),
                    ],
                  ),
                );
              }

              return ZenEffectBuilder<List<Todo>>(
                effect: controller.todoService.loadTodosEffect,
                onLoading: () =>
                const Center(child: CircularProgressIndicator()),
                onError: (error) =>
                    Center(
                      child: Text('Error: ${error.toString()}'),
                    ),
                onSuccess: (data) =>
                    ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: todos.length,
                      itemBuilder: (context, index) {
                        final todo = todos[index];
                        return TodoItem(
                          todo: todo,
                          onToggle: () => controller.toggleTodoStatus(todo.id),
                          onEdit: () =>
                              _navigateToDetailPage(context, todo: todo),
                          onDelete: () =>
                              _showDeleteConfirmation(context, todo),
                        );
                      },
                    ),
                onInitial: () =>
                    ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: todos.length,
                      itemBuilder: (context, index) {
                        final todo = todos[index];
                        return TodoItem(
                          todo: todo,
                          onToggle: () => controller.toggleTodoStatus(todo.id),
                          onEdit: () =>
                              _navigateToDetailPage(context, todo: todo),
                          onDelete: () =>
                              _showDeleteConfirmation(context, todo),
                        );
                      },
                    ),
              );
            }),
          ),

          // Bottom stats bar
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            color: Theme
                .of(context)
                .colorScheme
                .surfaceContainerHighest,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Todo counts
                Obx(() =>
                    Text(
                      '${controller.activeCount} active, ${controller
                          .completedCount} completed',
                      style: Theme
                          .of(context)
                          .textTheme
                          .bodySmall,
                    )),

                // Clear completed button
                Obx(() =>
                controller.completedCount > 0
                    ? TextButton(
                  onPressed: () => _showClearCompletedConfirmation(context),
                  child: const Text('Clear completed'),
                )
                    : const SizedBox.shrink()),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToDetailPage(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _navigateToDetailPage(BuildContext context, {Todo? todo}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TodoDetailPage(todo: todo),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, Todo todo) {
    showDialog(
      context: context,
      builder: (context) =>
          AlertDialog(
            title: const Text('Delete Todo'),
            content: Text('Are you sure you want to delete "${todo.title}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  controller.deleteTodo(todo.id);
                  Navigator.of(context).pop();
                },
                child: const Text('Delete'),
              ),
            ],
          ),
    );
  }

  void _showClearCompletedConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) =>
          AlertDialog(
            title: const Text('Clear Completed'),
            content: Text(
                'Are you sure you want to delete all ${controller
                    .completedCount} completed todos?'
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  controller.clearCompletedTodos();
                  Navigator.of(context).pop();
                },
                child: const Text('Clear'),
              ),
            ],
          ),
    );
  }

  void _showSearchDialog(BuildContext context) {
    final searchController = TextEditingController(
        text: controller.searchQuery.value);

    showDialog(
      context: context,
      builder: (context) =>
          AlertDialog(
            title: const Text('Search Todos'),
            content: TextField(
              controller: searchController,
              decoration: const InputDecoration(
                hintText: 'Enter search term',
                prefixIcon: Icon(Icons.search),
              ),
              autofocus: true,
            ),
            actions: [
              TextButton(
                onPressed: () {
                  controller.setSearchQuery('');
                  Navigator.of(context).pop();
                },
                child: const Text('Clear'),
              ),
              TextButton(
                onPressed: () {
                  controller.setSearchQuery(searchController.text);
                  Navigator.of(context).pop();
                },
                child: const Text('Search'),
              ),
            ],
          ),
    );
  }

  void _showSortDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sort Todos'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Obx(() => RadioGroup<String>(
              groupValue: controller.sortMode.value,
              onChanged: (value) {
                if (value != null) {
                  controller.setSortMode(value);
                  Navigator.of(context).pop();
                }
              },
              child: Column(
                children: [
                  ListTile(
                    leading: Radio<String>(
                      value: 'created',
                    ),
                    title: const Text('Creation Date'),
                    onTap: () {
                      controller.setSortMode('created');
                      Navigator.of(context).pop();
                    },
                  ),
                  ListTile(
                    leading: Radio<String>(
                      value: 'priority',
                    ),
                    title: const Text('Priority'),
                    onTap: () {
                      controller.setSortMode('priority');
                      Navigator.of(context).pop();
                    },
                  ),
                  ListTile(
                    leading: Radio<String>(
                      value: 'dueDate',
                    ),
                    title: const Text('Due Date'),
                    onTap: () {
                      controller.setSortMode('dueDate');
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }
}
