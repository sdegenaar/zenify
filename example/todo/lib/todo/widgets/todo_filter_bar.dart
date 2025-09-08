import 'package:flutter/material.dart';
import 'package:zenify/zenify.dart';
import '../controllers/todo_controller.dart';

/// Widget for filtering todos by status (all, active, completed)
class TodoFilterBar extends StatelessWidget {
  final TodoController controller;

  const TodoFilterBar({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Column(
        children: [
          // Search indicator
          Obx(() => controller.searchQuery.value.isNotEmpty
              ? Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.search, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Search: "${controller.searchQuery.value}"',
                          style: const TextStyle(fontStyle: FontStyle.italic),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () => controller.setSearchQuery(''),
                        tooltip: 'Clear search',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink()),

          // Filter buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: Obx(() => _buildFilterButton(
                      context,
                      label: 'All',
                      value: 'all',
                      count: controller.todos.length,
                      isSelected: controller.filterMode.value == 'all',
                    )),
              ),
              Expanded(
                child: Obx(() => _buildFilterButton(
                      context,
                      label: 'Active',
                      value: 'active',
                      count: controller.activeCount,
                      isSelected: controller.filterMode.value == 'active',
                    )),
              ),
              Expanded(
                child: Obx(() => _buildFilterButton(
                      context,
                      label: 'Completed',
                      value: 'completed',
                      count: controller.completedCount,
                      isSelected: controller.filterMode.value == 'completed',
                    )),
              ),
            ],
          ),

          // Sort indicator
          Obx(() => Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.sort, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      'Sorted by: ${_getSortLabel(controller.sortMode.value)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildFilterButton(
    BuildContext context, {
    required String label,
    required String value,
    required int count,
    required bool isSelected,
  }) {
    return TextButton(
      onPressed: () => controller.setFilterMode(value),
      style: TextButton.styleFrom(
        backgroundColor: isSelected
            ? Theme.of(context).colorScheme.primaryContainer
            : Colors.transparent,
        foregroundColor: isSelected
            ? Theme.of(context).colorScheme.onPrimaryContainer
            : Theme.of(context).colorScheme.onSurface,
        padding: const EdgeInsets.symmetric(vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            count.toString(),
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  String _getSortLabel(String sortMode) {
    switch (sortMode) {
      case 'created':
        return 'Creation Date';
      case 'priority':
        return 'Priority';
      case 'dueDate':
        return 'Due Date';
      default:
        return 'Default';
    }
  }
}
