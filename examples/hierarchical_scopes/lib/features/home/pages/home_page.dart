
import 'package:flutter/material.dart';
import 'package:zenify/zenify.dart';

import '../controllers/home_controller.dart';
import '../../../shared/widgets/debug_dialog.dart';

/// Home page using ZenView pattern with automatic controller binding
class HomePage extends ZenView<HomeController> {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: _buildAppBar(context, controller),
      body: _buildBody(controller),
      floatingActionButton: _buildFloatingActionButtons(controller),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, HomeController controller) {
    return AppBar(
      title: const Text('Company Management'),
      backgroundColor: Colors.blue.shade700,
      foregroundColor: Colors.white,
      elevation: 2,
      actions: [
        Obx(() => IconButton(
          icon: controller.isRefreshing.value
              ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          )
              : const Icon(Icons.refresh),
          onPressed: controller.isRefreshing.value
              ? null
              : () => controller.refreshData(),
          tooltip: 'Refresh Data',
        )),
        // DEBUG BUTTON - Add this to AppBar
        IconButton(
          icon: const Icon(Icons.developer_mode),
          onPressed: () => _showDebugDialog(context),
          tooltip: 'Debug Info',
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

  Widget _buildBody(HomeController controller) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome Section
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Welcome to Company Management',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'This application demonstrates hierarchical scoping with Zenify.',
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: controller.navigateToDepartments,
                    icon: const Icon(Icons.business),
                    label: const Text('View Departments'),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Debug Panel Info
          Card(
            elevation: 2,
            color: Colors.purple.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.developer_mode, color: Colors.purple.shade600),
                      const SizedBox(width: 8),
                      Text(
                        'Debug Panel Available',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.purple.shade800, // Darker for better contrast
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap the debug button in the app bar (top-right) to open the global debug panel. '
                        'It shows scope hierarchy, navigation state, and performance metrics across all pages.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.purple.shade700, // Better contrast
                      height: 1.4, // Better line spacing
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(
                        avatar: Icon(Icons.account_tree, size: 16, color: Colors.white),
                        label: const Text(
                            'Scope Info',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white, // White text for better contrast
                            )
                        ),
                        backgroundColor: Colors.purple.shade600, // Solid background
                        elevation: 2, // Add shadow for depth
                      ),
                      Chip(
                        avatar: Icon(Icons.navigation, size: 16, color: Colors.white),
                        label: const Text(
                            'Navigation',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            )
                        ),
                        backgroundColor: Colors.purple.shade600,
                        elevation: 2,
                      ),
                      Chip(
                        avatar: Icon(Icons.speed, size: 16, color: Colors.white),
                        label: const Text(
                            'Performance',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            )
                        ),
                        backgroundColor: Colors.purple.shade600,
                        elevation: 2,
                      ),
                      Chip(
                        avatar: Icon(Icons.schema, size: 16, color: Colors.white),
                        label: const Text(
                            'Hierarchy',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            )
                        ),
                        backgroundColor: Colors.purple.shade600,
                        elevation: 2,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Navigation Info
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Navigation',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Obx(() {
                    final breadcrumbs = controller.navigationService.breadcrumbs;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Current path: ${controller.navigationService.currentPath.value}'),
                        const SizedBox(height: 8),
                        Text('Navigation depth: ${breadcrumbs.length}'),
                        const SizedBox(height: 8),
                        Text('Total navigations: ${controller.navigationService.navigationCount.value}'),
                        const SizedBox(height: 16),
                        const Text('Breadcrumbs:'),
                        const SizedBox(height: 4),
                        if (breadcrumbs.isEmpty)
                          const Text('No breadcrumbs yet')
                        else
                          Column(
                            children: breadcrumbs
                                .map((item) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  const Icon(Icons.arrow_right, size: 16),
                                  const SizedBox(width: 4),
                                  Text('${item.title} (${item.route})'),
                                ],
                              ),
                            ))
                                .toList(),
                          ),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Feature Explanation
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Hierarchical Scoping Features',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    '🏗️ Hierarchical Dependency Injection',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Services flow from parent to child scopes automatically.',
                    style: TextStyle(fontSize: 13),
                  ),
                  SizedBox(height: 12),
                  Text(
                    '🔄 Automatic Cleanup',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Scopes are disposed automatically when no longer needed.',
                    style: TextStyle(fontSize: 13),
                  ),
                  SizedBox(height: 12),
                  Text(
                    '📊 Real-time Debugging',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Use the debug panel to see scope changes in real-time.',
                    style: TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingActionButtons(HomeController controller) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 16),
        // Departments Button
        FloatingActionButton(
          heroTag: "home_departments",
          onPressed: controller.navigateToDepartments,
          tooltip: 'View Departments',
          backgroundColor: Colors.blue.shade700,
          child: const Icon(Icons.business, color: Colors.white),
        ),
      ],
    );
  }
}