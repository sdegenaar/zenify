import 'package:flutter/material.dart';
import 'package:zenify/zenify.dart';
import '../controllers/advanced_features_controller.dart';

/// Demonstrates advanced ZenQuery features:
/// - Query selection (derived queries)
/// - Dependent queries
/// - Conditional queries (enabled/disabled)
/// - Query cancellation
/// - Query deduplication
class AdvancedFeaturesPage extends ZenView<AdvancedFeaturesController> {
  const AdvancedFeaturesPage({super.key});

  @override
  AdvancedFeaturesController Function()? get createController =>
      () => AdvancedFeaturesController();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildInfoCard(),
        const SizedBox(height: 16),
        _buildQuerySelectionSection(),
        const SizedBox(height: 16),
        _buildDependentQueriesSection(),
        const SizedBox(height: 16),
        _buildConditionalQuerySection(),
        const SizedBox(height: 16),
        _buildCancellationSection(),
        const SizedBox(height: 16),
        _buildDeduplicationSection(),
      ],
    );
  }

  Widget _buildInfoCard() {
    return Card(
      color: Colors.teal.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Row(
              children: [
                Icon(Icons.code, color: Colors.teal),
                SizedBox(width: 8),
                Text(
                  'Advanced Features',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              'This tab demonstrates advanced ZenQuery features:\n'
              '• Query selection (derived queries)\n'
              '• Dependent queries (wait for other queries)\n'
              '• Conditional queries (enable/disable)\n'
              '• Request cancellation\n'
              '• Automatic deduplication',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuerySelectionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Query Selection (Derived Queries)',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Select only the data you need from a query. The derived query only updates when the selected value changes.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Source Query (Full User)',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Obx(() {
                  final user = controller.userQuery.data.value;
                  if (user == null) {
                    return const CircularProgressIndicator();
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ID: ${user.id}'),
                      Text('Name: ${user.name}'),
                      Text('Email: ${user.email}'),
                      Text('Bio: ${user.bio}'),
                    ],
                  );
                }),
                const Divider(),
                const Text(
                  'Derived Query (Email Only)',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Obx(() {
                  final email = controller.userEmailQuery.data.value;
                  if (email == null) {
                    return const CircularProgressIndicator();
                  }
                  return Row(
                    children: [
                      const Icon(Icons.email, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        email,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  );
                }),
                const SizedBox(height: 12),
                const Text(
                  '💡 The email query only rebuilds when the email changes, not when other user properties change!',
                  style: TextStyle(fontSize: 12, color: Colors.blue),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDependentQueriesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Dependent Queries',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'One query waits for data from another query before executing.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('Step 1: ',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Obx(() {
                      final user = controller.userQuery.data.value;
                      if (user == null) {
                        return const Text('Loading user...');
                      }
                      return Text('User loaded (ID: ${user.id})');
                    }),
                    const SizedBox(width: 8),
                    Obx(() => Icon(
                          controller.userQuery.hasData
                              ? Icons.check_circle
                              : Icons.pending,
                          color: controller.userQuery.hasData
                              ? Colors.green
                              : Colors.orange,
                          size: 16,
                        )),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Step 2: ',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Obx(() {
                      if (!controller.userQuery.hasData) {
                        return const Text('Waiting for user...');
                      }
                      if (!controller.userPostsQuery.hasData) {
                        return const Text('Loading user posts...');
                      }
                      return Text(
                          'Posts loaded (${controller.userPostsQuery.data.value?.length ?? 0} posts)');
                    }),
                    const SizedBox(width: 8),
                    Obx(() => Icon(
                          controller.userPostsQuery.hasData
                              ? Icons.check_circle
                              : Icons.pending,
                          color: controller.userPostsQuery.hasData
                              ? Colors.green
                              : Colors.orange,
                          size: 16,
                        )),
                  ],
                ),
                const SizedBox(height: 12),
                Obx(() {
                  if (!controller.userPostsQuery.hasData) {
                    return const SizedBox.shrink();
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'User Posts:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      ...controller.userPostsQuery.data.value!.take(3).map(
                            (post) => Padding(
                              padding: const EdgeInsets.only(left: 16, top: 4),
                              child: Text('• ${post.title}'),
                            ),
                          ),
                    ],
                  );
                }),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConditionalQuerySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Conditional Query',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Enable or disable queries dynamically based on conditions.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Obx(() {
                  return SwitchListTile(
                    title: const Text('Enable Search Query'),
                    subtitle: Text(
                      controller.searchEnabled.value
                          ? 'Query is active'
                          : 'Query is disabled',
                    ),
                    value: controller.searchEnabled.value,
                    onChanged: controller.toggleSearch,
                  );
                }),
                const Divider(),
                TextField(
                  controller: controller.searchController,
                  decoration: const InputDecoration(
                    labelText: 'Search Users',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: controller.onSearchChanged,
                ),
                const SizedBox(height: 12),
                Obx(() {
                  if (!controller.searchEnabled.value) {
                    return const Center(
                      child: Text(
                        'Search is disabled',
                        style: TextStyle(color: Colors.grey),
                      ),
                    );
                  }

                  final query = controller.searchQuery;
                  if (query.isLoading.value) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!query.hasData) {
                    return const Center(
                      child: Text(
                        'Enter a search term',
                        style: TextStyle(color: Colors.grey),
                      ),
                    );
                  }

                  final users = query.data.value!;
                  if (users.isEmpty) {
                    return const Center(
                      child: Text('No users found'),
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Found ${users.length} users:',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      ...users.map((user) => ListTile(
                            dense: true,
                            leading: const Icon(Icons.person),
                            title: Text(user.name),
                            subtitle: Text(user.email),
                          )),
                    ],
                  );
                }),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCancellationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Query Cancellation',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Cancel slow queries before they complete. New fetches automatically cancel previous ones.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Obx(() {
                  final query = controller.slowQuery;
                  return Column(
                    children: [
                      if (query.isLoading.value)
                        const Column(
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 8),
                            Text('Fetching slow data...'),
                          ],
                        )
                      else if (query.hasData)
                        Text(
                          'Data: ${query.data.value}',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        )
                      else
                        const Text(
                          'Click "Fetch" to start a slow query',
                          style: TextStyle(color: Colors.grey),
                        ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: controller.fetchSlow,
                              icon: const Icon(Icons.download),
                              label: const Text('Fetch (Slow)'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: query.isLoading.value
                                  ? controller.cancelSlow
                                  : null,
                              icon: const Icon(Icons.cancel),
                              label: const Text('Cancel'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                }),
                const SizedBox(height: 8),
                const Text(
                  '💡 Try clicking Fetch multiple times quickly - older requests are automatically cancelled!',
                  style: TextStyle(fontSize: 12, color: Colors.blue),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDeduplicationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Query Deduplication',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Multiple requests with the same key share a single fetch.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Click "Fetch 5 Times" to make 5 simultaneous requests. Watch as only 1 network request is made!',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 12),
                Obx(() {
                  return Text(
                    'Fetch Count: ${controller.fetchCount.value}',
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.bold),
                  );
                }),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: controller.fetchMultiple,
                  icon: const Icon(Icons.filter_5),
                  label: const Text('Fetch 5 Times Simultaneously'),
                ),
                const SizedBox(height: 8),
                Obx(() {
                  if (controller.dedupeQuery.isLoading.value) {
                    return const Center(
                      child: Column(
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 8),
                          Text('Making request...'),
                        ],
                      ),
                    );
                  }
                  if (controller.dedupeQuery.hasData) {
                    return Text(
                      'Result: ${controller.dedupeQuery.data.value}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 14),
                    );
                  }
                  return const SizedBox.shrink();
                }),
                const SizedBox(height: 8),
                const Text(
                  '💡 Check your dev console - you\'ll see only 1 API call was made!',
                  style: TextStyle(fontSize: 12, color: Colors.blue),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
