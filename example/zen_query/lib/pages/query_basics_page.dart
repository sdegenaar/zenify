import 'package:flutter/material.dart';
import 'package:zenify/zenify.dart';
import '../controllers/query_basics_controller.dart';
import '../models/models.dart';

/// Demonstrates core ZenQuery features:
/// - Basic queries with caching
/// - Loading, error, and success states
/// - Refetching and invalidation
/// - Stale time and cache time
/// - Retry logic
/// - Placeholder data
/// - Query status tracking
class QueryBasicsPage extends ZenView<QueryBasicsController> {
  const QueryBasicsPage({super.key});

  @override
  QueryBasicsController Function()? get createController =>
      () => QueryBasicsController();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildInfoCard(),
        const SizedBox(height: 16),
        _buildUserQuerySection(),
        const SizedBox(height: 16),
        _buildPostsQuerySection(),
        const SizedBox(height: 16),
        _buildActionsSection(),
        const SizedBox(height: 16),
        _buildStatusSection(),
      ],
    );
  }

  Widget _buildInfoCard() {
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'ZenQuery Basics',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              'This tab demonstrates core ZenQuery features:\n'
              '• Automatic caching and deduplication\n'
              '• Loading, error, and success states\n'
              '• Stale time and cache time management\n'
              '• Manual refetching and invalidation\n'
              '• Automatic retry on failure\n'
              '• Placeholder data while loading',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserQuerySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'User Query (with caching)',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ZenQueryBuilder<User>(
          query: controller.userQuery,
          builder: (context, user) {
            return Card(
              child: Column(
                children: [
                  ListTile(
                    leading: CircleAvatar(
                      backgroundImage: NetworkImage(user.avatar),
                      onBackgroundImageError: (_, __) {},
                      child: const Icon(Icons.person),
                    ),
                    title: Text(user.name),
                    subtitle: Text(user.email),
                    trailing: controller.userQuery.isRefetching
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : null,
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      user.bio,
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ),
                  if (controller.userQuery.isStale)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      color: Colors.orange.shade100,
                      child: const Text(
                        '⚠️ Data is stale (> 30 seconds old)',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                ],
              ),
            );
          },
          loading: () => const Card(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
          error: (error, retry) => Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Icon(Icons.error, color: Colors.red, size: 48),
                  const SizedBox(height: 8),
                  Text(
                    'Error: $error',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: retry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPostsQuerySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Posts Query (with placeholder data)',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ZenQueryBuilder<List<Post>>(
          query: controller.postsQuery,
          showStaleData: true,
          builder: (context, posts) {
            return Card(
              child: Column(
                children: [
                  if (controller.postsQuery.isPlaceholderData.value)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      color: Colors.purple.shade100,
                      child: const Text(
                        '📋 Showing placeholder data',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: posts.length,
                    itemBuilder: (context, index) {
                      final post = posts[index];
                      return ListTile(
                        leading: CircleAvatar(
                          child: Text('${post.id}'),
                        ),
                        title: Text(post.title),
                        subtitle: Text(
                          post.content,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.favorite,
                                size: 16, color: Colors.red),
                            const SizedBox(width: 4),
                            Text('${post.likes}'),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            );
          },
          loading: () => const Card(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
          error: (error, retry) => Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Icon(Icons.error, color: Colors.red, size: 48),
                  const SizedBox(height: 8),
                  Text(
                    'Failed to load posts: $error',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(onPressed: retry, child: const Text('Retry')),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Actions',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: controller.refetchAll,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refetch All'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: controller.invalidateAll,
                    icon: const Icon(Icons.update),
                    label: const Text('Invalidate'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: controller.resetAll,
              icon: const Icon(Icons.restart_alt),
              label: const Text('Reset All Queries'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: controller.clearCache,
              icon: const Icon(Icons.delete_sweep),
              label: const Text('Clear Query Cache'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Obx(() {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Query Status',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const Divider(),
              _buildStatusRow('User Query Status',
                  controller.userQuery.status.value.toString().split('.').last),
              _buildStatusRow('User Loading',
                  controller.userQuery.isLoading.value.toString()),
              _buildStatusRow(
                  'User Has Data', controller.userQuery.hasData.toString()),
              _buildStatusRow(
                  'User Is Stale', controller.userQuery.isStale.toString()),
              _buildStatusRow('User Refetching',
                  controller.userQuery.isRefetching.toString()),
              const Divider(),
              _buildStatusRow(
                  'Posts Query Status',
                  controller.postsQuery.status.value
                      .toString()
                      .split('.')
                      .last),
              _buildStatusRow('Posts Loading',
                  controller.postsQuery.isLoading.value.toString()),
              _buildStatusRow(
                  'Posts Has Data', controller.postsQuery.hasData.toString()),
              _buildStatusRow('Posts Placeholder',
                  controller.postsQuery.isPlaceholderData.value.toString()),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildStatusRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
