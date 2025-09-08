import 'package:flutter/material.dart';
import 'package:zenify/zenify.dart';
import '../../../shared/models/department.dart';
import '../../../shared/widgets/debug_dialog.dart';
import '../controllers/departments_controller.dart';

/// Departments page using ZenView pattern with ZenEffects showcase
class DepartmentsPage extends ZenView<DepartmentsController> {
  const DepartmentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: _buildBody(),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text('Departments'),
      backgroundColor: Colors.blue.shade700,
      foregroundColor: Colors.white,
      elevation: 2,
      actions: [
        // Enhanced ZenBuilder with error handling
        ZenBuilder<DepartmentsController>(
          builder: (context, controller) {
            final hasSearchQuery = controller.searchQuery.value.isNotEmpty;

            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(hasSearchQuery ? Icons.clear : Icons.search),
                  onPressed: hasSearchQuery
                      ? controller.clearSearch
                      : () => _showSearchDialog(context, controller),
                  tooltip:
                      hasSearchQuery ? 'Clear Search' : 'Search Departments',
                ),
                // Refresh button with ZenEffectBuilder
                ZenEffectBuilder<bool>(
                  effect: controller.refreshEffect,
                  onInitial: () => IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: controller.refreshDepartments,
                    tooltip: 'Refresh Departments',
                  ),
                  onLoading: () => IconButton(
                    icon: const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    onPressed: null,
                    tooltip: 'Refreshing...',
                  ),
                  onSuccess: (success) => IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: controller.refreshDepartments,
                    tooltip: 'Refresh Departments',
                  ),
                  onError: (error) => IconButton(
                    icon: Icon(Icons.refresh, color: Colors.red.shade300),
                    onPressed: controller.refreshDepartments,
                    tooltip: 'Refresh Failed - Retry',
                  ),
                ),
                // DEBUG BUTTON - Add this to AppBar
                IconButton(
                  icon: const Icon(Icons.developer_mode),
                  onPressed: () => _showDebugDialog(context),
                  tooltip: 'Debug Info',
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  // Add this method to show debug info in a dialog
  void _showDebugDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const DebugDialog(),
    );
  }

  // ... rest of your existing code remains the same
  Widget _buildBody() {
    return Column(
      children: [
        // Error banner using ZenBuilder
        ZenBuilder<DepartmentsController>(
          builder: (context, controller) {
            final errorMessage = controller.lastError.value;

            return errorMessage.isNotEmpty
                ? Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    color: Colors.red.shade100,
                    child: Row(
                      children: [
                        Icon(Icons.error_outline,
                            color: Colors.red.shade700, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            errorMessage,
                            style: TextStyle(
                              color: Colors.red.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close,
                              color: Colors.red.shade700, size: 18),
                          onPressed: () => controller.lastError.value = '',
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink();
          },
        ),

        // Search bar with ZenEffectBuilder for search state
        ZenBuilder<DepartmentsController>(
          builder: (context, controller) {
            final searchQuery = controller.searchQuery.value;

            return searchQuery.isNotEmpty
                ? Container(
                    padding: const EdgeInsets.all(16),
                    color: Colors.blue.shade50,
                    child: Row(
                      children: [
                        // Search effect status indicator
                        ZenEffectBuilder<String>(
                          effect: controller.searchEffect,
                          onInitial: () => Icon(Icons.search,
                              color: Colors.blue.shade700, size: 20),
                          onLoading: () => SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.blue.shade700,
                            ),
                          ),
                          onSuccess: (result) => Icon(Icons.search,
                              color: Colors.green.shade700, size: 20),
                          onError: (error) => Icon(Icons.search_off,
                              color: Colors.red.shade700, size: 20),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Searching for: "$searchQuery"',
                            style: TextStyle(
                              color: Colors.blue.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close,
                              color: Colors.blue.shade700, size: 20),
                          onPressed: controller.clearSearch,
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink();
          },
        ),

        // Main content with reactive departments list
        Expanded(
          child: ZenBuilder<DepartmentsController>(
            builder: (context, controller) {
              final isLoading = controller.isLoading.value;
              final departments = controller.filteredDepartments;
              final searchQuery = controller.searchQuery.value;

              if (isLoading) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Loading departments...'),
                    ],
                  ),
                );
              }

              if (departments.isEmpty) {
                final hasSearch = searchQuery.isNotEmpty;
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        hasSearch ? Icons.search_off : Icons.business_outlined,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        hasSearch
                            ? 'No departments found matching "$searchQuery"'
                            : 'No departments found',
                        style: const TextStyle(fontSize: 18),
                        textAlign: TextAlign.center,
                      ),
                      if (hasSearch) ...[
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: controller.clearSearch,
                          child: const Text('Clear Search'),
                        ),
                      ],
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: departments.length,
                itemBuilder: (context, index) {
                  final department = departments[index];
                  return _buildDepartmentCard(department, controller);
                },
              );
            },
          ),
        ),

        // Effect status bar at bottom
        _buildEffectStatusBar(),
      ],
    );
  }

  Widget _buildEffectStatusBar() {
    return ZenBuilder<DepartmentsController>(
      builder: (context, controller) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.grey.shade100,
          child: Row(
            children: [
              Text(
                'Effects:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(width: 8),
              _buildEffectIndicator('Search', controller.searchEffect),
              const SizedBox(width: 12),
              _buildEffectIndicator('Refresh', controller.refreshEffect),
              const SizedBox(width: 12),
              _buildEffectIndicator('Navigation', controller.navigationEffect),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEffectIndicator(String label, ZenEffect effect) {
    return Obx(() {
      Color color;
      IconData icon;

      if (effect.isLoading.value) {
        color = Colors.orange;
        icon = Icons.sync;
      } else if (effect.error.value != null) {
        color = Colors.red;
        icon = Icons.error_outline;
      } else if (effect.dataWasSet.value) {
        color = Colors.green;
        icon = Icons.check_circle_outline;
      } else {
        color = Colors.grey;
        icon = Icons.radio_button_unchecked;
      }

      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color,
            ),
          ),
        ],
      );
    });
  }

  Widget _buildDepartmentCard(
      Department department, DepartmentsController controller) {
    final teamCount = department.teams.length;
    final totalMembers = department.teams.fold<int>(
      0,
      (sum, team) => sum + team.members.length,
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: InkWell(
        onTap: () => controller.navigateToDepartmentDetail(department.id),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      department.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, size: 16),
                ],
              ),
              const SizedBox(height: 8),
              if (department.description.isNotEmpty) ...[
                Text(
                  department.description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Row(
                children: [
                  _buildInfoChip(
                    icon: Icons.groups,
                    label: '$teamCount ${teamCount == 1 ? 'team' : 'teams'}',
                    color: Colors.blue,
                  ),
                  const SizedBox(width: 8),
                  if (totalMembers > 0)
                    _buildInfoChip(
                      icon: Icons.person,
                      label:
                          '$totalMembers ${totalMembers == 1 ? 'member' : 'members'}',
                      color: Colors.green,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    return ZenBuilder<DepartmentsController>(
      builder: (context, controller) {
        return FloatingActionButton(
          onPressed: controller.isLoading.value
              ? null
              : () => _showAddDepartmentDialog(context, controller),
          backgroundColor:
              controller.isLoading.value ? Colors.grey : Colors.blue.shade700,
          child: const Icon(Icons.add),
        );
      },
    );
  }

  void _showSearchDialog(
      BuildContext context, DepartmentsController controller) {
    final textController = TextEditingController();
    textController.text = controller.searchQuery.value;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Search Departments'),
        content: TextField(
          controller: textController,
          decoration: const InputDecoration(
            hintText: 'Enter department name',
            prefixIcon: Icon(Icons.search),
          ),
          autofocus: true,
          onSubmitted: (value) {
            controller.search(value.trim());
            Navigator.pop(context);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () {
              controller.search(textController.text.trim());
              Navigator.pop(context);
            },
            child: const Text('SEARCH'),
          ),
        ],
      ),
    );
  }

  void _showAddDepartmentDialog(
      BuildContext context, DepartmentsController controller) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Department'),
        content: const Text('This would open a form to add a new department.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CLOSE'),
          ),
        ],
      ),
    );
  }
}
