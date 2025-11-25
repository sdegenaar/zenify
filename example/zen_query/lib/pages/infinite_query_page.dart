import 'package:flutter/material.dart';
import 'package:zenify/zenify.dart';
import '../controllers/infinite_query_controller.dart';
import '../models/models.dart';

/// Demonstrates ZenInfiniteQuery features:
/// - Infinite scroll pagination
/// - Loading next/previous pages
/// - Tracking hasNextPage/hasPreviousPage
/// - Error handling for page loads
/// - Refetching all pages
class InfiniteQueryPage extends ZenView<InfiniteQueryController> {
  const InfiniteQueryPage({super.key});

  @override
  InfiniteQueryController Function()? get createController =>
      () => InfiniteQueryController();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildInfoCard(),
        Expanded(child: _buildPostsList()),
      ],
    );
  }

  Widget _buildInfoCard() {
    return Card(
      margin: const EdgeInsets.all(16),
      color: Colors.purple.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Row(
              children: [
                Icon(Icons.view_list, color: Colors.purple),
                SizedBox(width: 8),
                Text(
                  'ZenInfiniteQuery',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              'Demonstrates infinite scroll pagination:\n'
              '• Automatic page loading on scroll\n'
              '• hasNextPage tracking\n'
              '• Loading states for next page\n'
              '• Error handling per page\n'
              '• Pull to refresh all pages',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostsList() {
    return ZenQueryBuilder<List<PaginatedResponse<Post>>>(
      query: controller.infiniteQuery,
      builder: (context, pages) {
        // Flatten all pages into a single list
        final allPosts = pages.expand((page) => page.items).toList();

        return RefreshIndicator(
          onRefresh: () => controller.infiniteQuery.refetch(),
          child: Obx(() {
            return CustomScrollView(
              controller: controller.scrollController,
              slivers: [
                // Stats header
                SliverToBoxAdapter(
                  child: Card(
                    margin: const EdgeInsets.all(16),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Pagination Stats',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const Divider(),
                          _buildStatRow('Pages Loaded', '${pages.length}'),
                          _buildStatRow('Total Posts', '${allPosts.length}'),
                          _buildStatRow('Has Next Page',
                              '${controller.infiniteQuery.hasNextPage.value}'),
                          _buildStatRow('Fetching Next',
                              '${controller.infiniteQuery.isFetchingNextPage.value}'),
                          if (pages.isNotEmpty) ...[
                            const Divider(),
                            _buildStatRow('Current Page', '${pages.last.page}'),
                            _buildStatRow(
                                'Total Pages', '${pages.last.totalPages}'),
                            _buildStatRow(
                                'Total Items', '${pages.last.totalItems}'),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),

                // Posts list
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final post = allPosts[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Text('${post.id}'),
                          ),
                          title: Text(post.title),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                post.content,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.favorite,
                                      size: 16, color: Colors.red),
                                  const SizedBox(width: 4),
                                  Text('${post.likes}'),
                                  const SizedBox(width: 16),
                                  const Icon(Icons.access_time, size: 16),
                                  const SizedBox(width: 4),
                                  Text(
                                    _formatDate(post.createdAt),
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          isThreeLine: true,
                        ),
                      );
                    },
                    childCount: allPosts.length,
                  ),
                ),

                // Loading next page indicator
                if (controller.infiniteQuery.isFetchingNextPage.value)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(
                        child: Column(
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 8),
                            Text('Loading more posts...'),
                          ],
                        ),
                      ),
                    ),
                  ),

                // End of list indicator
                if (!controller.infiniteQuery.hasNextPage.value &&
                    !controller.infiniteQuery.isFetchingNextPage.value &&
                    allPosts.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Center(
                        child: Column(
                          children: [
                            const Icon(Icons.check_circle,
                                color: Colors.green, size: 48),
                            const SizedBox(height: 8),
                            const Text(
                              'You\'ve reached the end!',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Loaded ${allPosts.length} posts',
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // Manual load more button
                if (controller.infiniteQuery.hasNextPage.value &&
                    !controller.infiniteQuery.isFetchingNextPage.value)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: ElevatedButton.icon(
                        onPressed: controller.loadMore,
                        icon: const Icon(Icons.add),
                        label: const Text('Load More'),
                      ),
                    ),
                  ),

                // Bottom padding
                const SliverToBoxAdapter(
                  child: SizedBox(height: 16),
                ),
              ],
            );
          }),
        );
      },
      loading: () => const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading posts...'),
          ],
        ),
      ),
      error: (error, retry) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, color: Colors.red, size: 64),
            const SizedBox(height: 16),
            Text(
              'Failed to load posts',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: retry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
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

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }
}
