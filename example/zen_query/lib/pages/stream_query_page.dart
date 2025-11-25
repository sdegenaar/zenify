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
  StreamQueryController Function()? get createController =>
      () => StreamQueryController();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildInfoCard(),
        const SizedBox(height: 16),
        _buildNotificationsSection(),
        const SizedBox(height: 16),
        _buildActiveUsersSection(),
        const SizedBox(height: 16),
        _buildPostUpdatesSection(),
        const SizedBox(height: 16),
        _buildStreamControlsSection(),
      ],
    );
  }

  Widget _buildInfoCard() {
    return Card(
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Row(
              children: [
                Icon(Icons.stream, color: Colors.orange),
                SizedBox(width: 8),
                Text(
                  'ZenStreamQuery',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
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
  }

  Widget _buildNotificationsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Real-time Notifications',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Obx(() {
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

          return Card(
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  color: Colors.green.shade100,
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Live • Receiving notifications',
                        style: TextStyle(fontWeight: FontWeight.bold),
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
                        leading: const Icon(Icons.notifications_active,
                            color: Colors.blue),
                        title: Text(notification),
                        trailing: Text(
                          'Just now',
                          style:
                              const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      );
                    },
                  ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildActiveUsersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Active Users Count',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Obx(() {
          final streamQuery = controller.activeUsersStream;

          return Card(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  const Icon(Icons.people, size: 64, color: Colors.blue),
                  const SizedBox(height: 16),
                  if (streamQuery.hasData)
                    Text(
                      '${streamQuery.data.value}',
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.circle, size: 8, color: Colors.green),
                        SizedBox(width: 4),
                        Text('Live', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildPostUpdatesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Live Post Updates',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Obx(() {
          final streamQuery = controller.postUpdatesStream;

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
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text('LIVE',
                              style: TextStyle(fontSize: 10)),
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
                        const Icon(Icons.favorite, color: Colors.red, size: 20),
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
        }),
      ],
    );
  }

  Widget _buildStreamControlsSection() {
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
            Obx(() {
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
            Obx(() {
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
