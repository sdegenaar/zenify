import 'package:flutter/material.dart';
import 'package:zenify/zenify.dart';
import '../controllers/stream_query_controller.dart';

/// Demonstrates ZenStreamQuery features:
/// - Real-time data updates via streams
/// - Automatic subscription management
/// - Error handling for streams
/// - Multiple concurrent streams
/// - Pause/resume functionality
class StreamQueryPage extends ZenView<StreamQueryController> {
  const StreamQueryPage({super.key});

  @override
  Widget build(BuildContext context, StreamQueryController controller) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildInfoCard(controller),
        const SizedBox(height: 16),
        _buildNotificationsSection(controller),
        const SizedBox(height: 16),
        _buildActiveUsersSection(controller),
        const SizedBox(height: 16),
        _buildPostUpdatesSection(controller),
        const SizedBox(height: 16),
        _buildStreamControlsSection(controller),
      ],
    );
  }

  Widget _buildInfoCard(StreamQueryController controller) {
    return Builder(builder: (context) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return Card(
        color: isDark
            ? Colors.orange.shade900.withValues(alpha: 0.3)
            : Colors.orange.shade50,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.stream,
                      color: isDark ? Colors.orangeAccent : Colors.orange),
                  const SizedBox(width: 8),
                  const Text(
                    'ZenStreamQuery',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Demonstrates real-time stream handling:\n'
                '• Automatic subscription to streams\n'
                '• Real-time data updates\n'
                '• Error handling and recovery\n'
                '• Multiple concurrent streams\n'
                '• Subscribe/unsubscribe controls',
                style: TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildNotificationsSection(StreamQueryController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Real-time Notifications',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ZenObserver(() {
          final streamQuery = controller.notificationStream;

          if (streamQuery.isLoading.value) {
            return const Card(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Center(
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 8),
                      Text('Connecting to notification stream...'),
                    ],
                  ),
                ),
              ),
            );
          }

          if (streamQuery.hasError) {
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Icon(Icons.error, color: Colors.red, size: 48),
                    const SizedBox(height: 8),
                    Text(
                      'Stream Error: ${streamQuery.error.value}',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          final notifications = controller.allNotifications;

          return Builder(builder: (context) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return Card(
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    color: isDark
                        ? Colors.green.shade900.withValues(alpha: 0.3)
                        : Colors.green.shade100,
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.greenAccent : Colors.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Live • Receiving notifications',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? Colors.greenAccent
                                : Colors.green.shade900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (notifications.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        'Waiting for notifications...',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: notifications.length,
                      itemBuilder: (context, index) {
                        final notification =
                            notifications[notifications.length - 1 - index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.blue.shade100,
                            child: const Icon(Icons.notifications_active,
                                color: Colors.blue),
                          ),
                          title: Text(notification),
                          trailing: const Text(
                            'Just now',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        );
                      },
                    ),
                ],
              ),
            );
          });
        }),
      ],
    );
  }

  Widget _buildActiveUsersSection(StreamQueryController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Active Users Counter',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ZenObserver(() {
          final count = controller.activeUsersStream.data.value;

          return Builder(builder: (context) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Icon(Icons.people, size: 64, color: Colors.blue),
                    const SizedBox(height: 16),
                    if (count != null)
                      Text(
                        '$count',
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.blueAccent : Colors.blue,
                        ),
                      )
                    else
                      const CircularProgressIndicator(),
                    const SizedBox(height: 8),
                    const Text(
                      'Users Online',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.green.shade900.withValues(alpha: 0.3)
                            : Colors.green.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.circle,
                              size: 8,
                              color:
                                  isDark ? Colors.greenAccent : Colors.green),
                          const SizedBox(width: 4),
                          Text(
                            'Live',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? Colors.greenAccent
                                  : Colors.green.shade900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          });
        }),
      ],
    );
  }

  Widget _buildPostUpdatesSection(StreamQueryController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Live Post Updates',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ZenObserver(() {
          final streamQuery = controller.postUpdatesStream;

          return Builder(builder: (context) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.article, color: Colors.purple),
                        const SizedBox(width: 8),
                        const Text(
                          'Watching Post #1',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        if (streamQuery.hasData)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.green.shade900.withValues(alpha: 0.3)
                                  : Colors.green.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'LIVE',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? Colors.greenAccent
                                    : Colors.green.shade900,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (streamQuery.isLoading.value)
                      const Center(child: CircularProgressIndicator())
                    else if (streamQuery.hasData) ...[
                      Text(
                        streamQuery.data.value!.title,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(streamQuery.data.value!.content),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.favorite,
                              color: Colors.red, size: 20),
                          const SizedBox(width: 4),
                          Text(
                            '${streamQuery.data.value!.likes} likes',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 16),
                          const Text(
                            '(Updates every 5s)',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ] else
                      const Text('No data yet',
                          style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            );
          });
        }),
      ],
    );
  }

  Widget _buildStreamControlsSection(StreamQueryController controller) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Stream Controls',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ZenObserver(() {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton.icon(
                    onPressed: controller.isSubscribed.value
                        ? null
                        : controller.subscribeAll,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Subscribe All Streams'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: !controller.isSubscribed.value
                        ? null
                        : controller.unsubscribeAll,
                    icon: const Icon(Icons.stop),
                    label: const Text('Unsubscribe All Streams'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: controller.clearNotifications,
                    icon: const Icon(Icons.clear_all),
                    label: const Text('Clear Notifications'),
                  ),
                ],
              );
            }),
            const SizedBox(height: 12),
            ZenObserver(() {
              return Text(
                controller.isSubscribed.value
                    ? '✓ All streams active'
                    : '⚠ Streams paused',
                style: TextStyle(
                  color: controller.isSubscribed.value
                      ? Colors.green
                      : Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
