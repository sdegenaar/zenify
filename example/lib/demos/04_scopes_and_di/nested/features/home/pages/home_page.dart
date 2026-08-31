import 'package:flutter/material.dart';
import 'package:zenify/zenify.dart';

import '../controllers/home_controller.dart';

/// Home page using ZenView pattern with automatic controller binding
class HomePage extends ZenView<HomeController> {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, HomeController controller) {
    return Scaffold(
      appBar: _buildAppBar(context, controller),
      body: SafeArea(child: _buildBody(context, controller)),
      floatingActionButton: _buildFloatingActionButtons(controller),
    );
  }

  PreferredSizeWidget _buildAppBar(
      BuildContext context, HomeController controller) {
    return AppBar(
      title: const Text('Company Management'),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        tooltip: 'Back to Showcase',
        onPressed: () {
          Navigator.of(context, rootNavigator: true).pop();
        },
      ),
      backgroundColor: Theme.of(context).colorScheme.primary,
      foregroundColor: Theme.of(context).colorScheme.onPrimary,
      elevation: 2,
      actions: [
        ZenObserver(() => IconButton(
              icon: controller.isRefreshing.value
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                    )
                  : const Icon(Icons.refresh),
              onPressed: controller.isRefreshing.value
                  ? null
                  : () => controller.refreshData(),
              tooltip: 'Refresh Data',
            )),
      ],
    );
  }

  Widget _buildBody(BuildContext context, HomeController controller) {
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
            color: Theme.of(context)
                .colorScheme
                .primaryContainer
                .withValues(alpha: 0.35),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.developer_mode,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Zenify Inspector Available',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap the floating "Z" button (bottom-right) to open the Zenify Inspector. '
                    'It shows scope hierarchy, query cache, registered dependencies, and performance stats across all pages.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(
                        avatar: Icon(
                          Icons.account_tree,
                          size: 16,
                          color:
                              Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                        label: Text('Scopes',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer,
                            )),
                        backgroundColor:
                            Theme.of(context).colorScheme.primaryContainer,
                      ),
                      Chip(
                        avatar: Icon(
                          Icons.cached,
                          size: 16,
                          color:
                              Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                        label: Text('Queries',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer,
                            )),
                        backgroundColor:
                            Theme.of(context).colorScheme.primaryContainer,
                      ),
                      Chip(
                        avatar: Icon(
                          Icons.extension,
                          size: 16,
                          color:
                              Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                        label: Text('Dependencies',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer,
                            )),
                        backgroundColor:
                            Theme.of(context).colorScheme.primaryContainer,
                      ),
                      Chip(
                        avatar: Icon(
                          Icons.analytics,
                          size: 16,
                          color:
                              Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                        label: Text('Stats',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer,
                            )),
                        backgroundColor:
                            Theme.of(context).colorScheme.primaryContainer,
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
                  ZenObserver(() {
                    final breadcrumbs =
                        controller.navigationService.breadcrumbs;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            'Current path: ${controller.navigationService.currentPath.value}'),
                        const SizedBox(height: 8),
                        Text('Navigation depth: ${breadcrumbs.length}'),
                        const SizedBox(height: 8),
                        Text(
                            'Total navigations: ${controller.navigationService.navigationCount.value}'),
                        const SizedBox(height: 16),
                        const Text('Breadcrumbs:'),
                        const SizedBox(height: 4),
                        if (breadcrumbs.isEmpty)
                          const Text('No breadcrumbs yet')
                        else
                          Column(
                            children: breadcrumbs
                                .map((item) => Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 4),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.arrow_right,
                                              size: 16),
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
                    'Use the Zenify Inspector to see scope changes, query cache, and stats in real-time.',
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
