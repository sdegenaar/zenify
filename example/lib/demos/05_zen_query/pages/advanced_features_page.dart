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
  Widget build(BuildContext context, AdvancedFeaturesController controller) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildInfoCard(controller),
        const SizedBox(height: 16),
        _buildQuerySelectionSection(controller),
        const SizedBox(height: 16),
        _buildDependentQueriesSection(controller),
        const SizedBox(height: 16),
        _buildConditionalQuerySection(controller),
        const SizedBox(height: 16),
        _buildCancellationSection(controller),
        const SizedBox(height: 16),
        _buildDeduplicationSection(controller),
        const SizedBox(height: 16),
        _buildBatchOperationsSection(controller),
      ],
    );
  }

  Widget _buildInfoCard(AdvancedFeaturesController controller) {
    return Builder(builder: (context) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return Card(
        color: isDark
            ? Colors.teal.shade900.withValues(alpha: 0.3)
            : Colors.teal.shade50,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.code,
                      color: isDark ? Colors.tealAccent : Colors.teal),
                  const SizedBox(width: 8),
                  const Text(
                    'Advanced Features',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'This tab demonstrates advanced ZenQuery features:\n'
                '• Query selection (derived queries)\n'
                '• Dependent queries (wait for other queries)\n'
                '• Conditional queries (enable/disable)\n'
                '• Request cancellation\n'
                '• Automatic deduplication\n'
                '• Batch cache operations (ZenQueryFilter)',
                style: TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildQuerySelectionSection(AdvancedFeaturesController controller) {
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
                ZenObserver(() {
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
                ZenObserver(() {
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

  Widget _buildDependentQueriesSection(AdvancedFeaturesController controller) {
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
                    ZenObserver(() {
                      final user = controller.userQuery.data.value;
                      if (user == null) {
                        return const Text('Loading user...');
                      }
                      return Text('User loaded (ID: ${user.id})');
                    }),
                    const SizedBox(width: 8),
                    ZenObserver(() => Icon(
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
                    ZenObserver(() {
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
                    ZenObserver(() => Icon(
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
                ZenObserver(() {
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

  Widget _buildConditionalQuerySection(AdvancedFeaturesController controller) {
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
                ZenObserver(() {
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
                ZenObserver(() {
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

  Widget _buildCancellationSection(AdvancedFeaturesController controller) {
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
                ZenObserver(() {
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

  Widget _buildDeduplicationSection(AdvancedFeaturesController controller) {
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
                ZenObserver(() {
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
                ZenObserver(() {
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

  Widget _buildBatchOperationsSection(AdvancedFeaturesController controller) {
    return Builder(builder: (context) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final theme = Theme.of(context);

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Batch Cache Operations (ZenQueryFilter) ✨',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Target multiple queries across the cache simultaneously by key glob patterns, tags, or lifecycle states.',
            style: TextStyle(fontSize: 12, color: theme.hintColor),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Live Queries in Cache:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  _buildQueryStateTile(
                    context: context,
                    title: 'Feed Post #1',
                    keyName: 'batch:feed:1',
                    tags: const ['feed', 'batch'],
                    query: controller.batchFeed1,
                  ),
                  const SizedBox(height: 8),
                  _buildQueryStateTile(
                    context: context,
                    title: 'Feed Post #2',
                    keyName: 'batch:feed:2',
                    tags: const ['feed', 'batch'],
                    query: controller.batchFeed2,
                  ),
                  const SizedBox(height: 8),
                  _buildQueryStateTile(
                    context: context,
                    title: 'Profile #1',
                    keyName: 'batch:profile:1',
                    tags: const ['profile', 'batch'],
                    query: controller.batchProfile,
                  ),
                  const Divider(height: 28),
                  const Text(
                    'Batch Actions:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: controller.batchIncrementFeedLikes,
                        icon: const Icon(Icons.thumb_up, size: 16),
                        label:
                            const Text('Like All Feed Posts (setQueriesData)'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: () => controller.batchRefetchFeed(),
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text(
                            'Refetch Feed (refetchQueries tags: [feed])'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: controller.batchInvalidateAll,
                        icon: const Icon(Icons.sync, size: 16),
                        label: const Text('Invalidate All (pattern: batch:*)'),
                      ),
                      ElevatedButton.icon(
                        onPressed: controller.batchResetAll,
                        icon: const Icon(Icons.clear_all, size: 16),
                        label: const Text('Reset All (resetQueries)'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark
                              ? Colors.orange.shade900.withValues(alpha: 0.4)
                              : Colors.orange.shade50,
                          foregroundColor: isDark
                              ? Colors.orangeAccent
                              : Colors.orange.shade900,
                          side: BorderSide(
                              color: isDark
                                  ? Colors.orange.shade700
                                  : Colors.orange.shade300),
                        ),
                      ),
                      ZenObserver(() {
                        final anyFetching = [
                          controller.batchFeed1,
                          controller.batchFeed2,
                          controller.batchProfile,
                        ].any((q) => q.isFetching);
                        return ElevatedButton.icon(
                          onPressed:
                              anyFetching ? controller.batchCancelAll : null,
                          icon: const Icon(Icons.cancel, size: 16),
                          label: const Text('Cancel In-Flight (cancelQueries)'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDark
                                ? Colors.red.shade900.withValues(alpha: 0.4)
                                : Colors.red.shade50,
                            foregroundColor:
                                isDark ? Colors.redAccent : Colors.red.shade900,
                            side: BorderSide(
                                color: isDark
                                    ? Colors.red.shade700
                                    : Colors.red.shade300),
                          ),
                        );
                      }),
                      OutlinedButton.icon(
                        onPressed: () => controller.batchFetchAll(),
                        icon: const Icon(Icons.download, size: 16),
                        label: const Text('Reload All'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Activity Log:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  ZenObserver(() {
                    final logBoxBg = isDark
                        ? const Color(0xFF14171C)
                        : const Color(0xFF1E232A);
                    if (controller.batchActionLog.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: logBoxBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: isDark ? Colors.white10 : Colors.black12),
                        ),
                        child: const Text(
                          'Tap an action button above to see batch operations in real-time.',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.white54,
                              fontFamily: 'monospace'),
                        ),
                      );
                    }
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: logBoxBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: isDark ? Colors.white10 : Colors.black12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: controller.batchActionLog
                            .map((log) => Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 2),
                                  child: Text(
                                    log,
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 11,
                                      color: Colors.greenAccent,
                                      height: 1.4,
                                    ),
                                  ),
                                ))
                            .toList(),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      );
    });
  }

  Widget _buildQueryStateTile({
    required BuildContext context,
    required String title,
    required String keyName,
    required List<String> tags,
    required ZenQuery<Map<String, dynamic>> query,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    return ZenObserver(() {
      final isLoading = query.isLoading.value;
      final data = query.data.value;
      final status = query.status.value;

      final tileBg = isLoading
          ? (isDark ? Colors.blue.withValues(alpha: 0.18) : Colors.blue.shade50)
          : (isDark ? const Color(0xFF222831) : const Color(0xFFF8F9FA));

      final tileBorder = isLoading
          ? Colors.blue.shade400
          : (isDark ? const Color(0xFF393E46) : Colors.grey.shade300);

      final textColor = theme.textTheme.bodyMedium?.color ??
          (isDark ? Colors.white : Colors.black87);

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: tileBorder),
          borderRadius: BorderRadius.circular(8),
          color: tileBg,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: textColor),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        keyName,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade600,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      ...tags.map((t) => Container(
                            margin: const EdgeInsets.only(right: 4),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.teal.withValues(alpha: 0.2)
                                  : Colors.teal.shade50,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: isDark
                                    ? Colors.teal.withValues(alpha: 0.4)
                                    : Colors.teal.shade300,
                              ),
                            ),
                            child: Text(
                              '#$t',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? Colors.tealAccent
                                    : Colors.teal.shade800,
                              ),
                            ),
                          )),
                      const SizedBox(width: 6),
                      if (data != null)
                        Text(
                          data.containsKey('likes')
                              ? '❤️ ${data['likes']} likes ("${data['title']}")'
                              : '👤 ${data['name']} (${data['role']})',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: textColor),
                        )
                      else if (status == ZenQueryStatus.idle)
                        Text(
                          'Idle (cleared)',
                          style: TextStyle(
                              fontSize: 12,
                              color: theme.hintColor,
                              fontStyle: FontStyle.italic),
                        )
                      else if (status == ZenQueryStatus.error)
                        const Text(
                          'Error',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.redAccent,
                              fontWeight: FontWeight.bold),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            if (isLoading)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(
                status == ZenQueryStatus.success
                    ? Icons.check_circle
                    : (status == ZenQueryStatus.idle
                        ? Icons.circle_outlined
                        : Icons.error),
                color: status == ZenQueryStatus.success
                    ? Colors.greenAccent
                    : (status == ZenQueryStatus.idle
                        ? theme.hintColor
                        : Colors.redAccent),
                size: 20,
              ),
          ],
        ),
      );
    });
  }
}
