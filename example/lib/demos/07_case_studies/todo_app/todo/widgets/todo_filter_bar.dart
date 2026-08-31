import 'package:flutter/material.dart';
import 'package:zenify/zenify.dart';
import '../../../../../shared/widgets/showcase_style.dart';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark
            ? Theme.of(context).colorScheme.surface
            : Colors.grey.shade50,
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white12 : Colors.grey.shade200,
          ),
        ),
      ),
      child: Column(
        children: [
          // Search indicator if active
          ZenObserver(() => controller.searchQuery.value.isNotEmpty
              ? Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: ShowcaseStyle.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.search,
                          size: 16, color: ShowcaseStyle.primaryColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Filter: "${controller.searchQuery.value}"',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: ShowcaseStyle.primaryColor,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        onPressed: () => controller.setSearchQuery(''),
                        tooltip: 'Clear search',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink()),

          // Filter Segmented Bar
          ZenObserver(() {
            final currentMode = controller.filterMode.value;
            return Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDark
                    ? Theme.of(context).colorScheme.surfaceContainerHighest
                    : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  _buildTab(
                    context,
                    label: 'All',
                    count: controller.todos.length,
                    selected: currentMode == 'all',
                    onTap: () => controller.setFilterMode('all'),
                  ),
                  _buildTab(
                    context,
                    label: 'Active',
                    count: controller.activeCount,
                    selected: currentMode == 'active',
                    onTap: () => controller.setFilterMode('active'),
                  ),
                  _buildTab(
                    context,
                    label: 'Done',
                    count: controller.completedCount,
                    selected: currentMode == 'completed',
                    onTap: () => controller.setFilterMode('completed'),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTab(
    BuildContext context, {
    required String label,
    required int count,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? (isDark
                    ? Theme.of(context).colorScheme.surface
                    : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  color: selected
                      ? ShowcaseStyle.primaryColor
                      : (isDark ? Colors.white70 : Colors.grey.shade700),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: selected
                      ? ShowcaseStyle.primaryColor
                      : (isDark ? Colors.white12 : Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: selected
                        ? Colors.white
                        : (isDark ? Colors.white70 : Colors.grey.shade700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
