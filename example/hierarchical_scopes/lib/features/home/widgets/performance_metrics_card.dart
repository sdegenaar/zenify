import 'package:flutter/material.dart';
import 'package:zenify/zenify.dart';

import '../controllers/home_controller.dart';

/// A card widget that displays performance metrics for various services
class PerformanceMetricsCard extends StatelessWidget {
  final HomeController controller;

  const PerformanceMetricsCard({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Service Performance Metrics',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Obx(() {
              final metrics = controller.performanceMetrics.value;
              final lastUpdated = metrics['lastUpdated'] as String? ?? 'Not available';
              final apiStats = metrics['api'] as Map<String, dynamic>? ?? {};
              final cacheStats = metrics['cache'] as Map<String, dynamic>? ?? {};
              final navStats = metrics['navigation'] as Map<String, dynamic>? ?? {};

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildMetricsSection(
                    'API Service',
                    Icons.cloud,
                    Colors.blue.shade700,
                    [
                      'Total Requests: ${apiStats['totalRequests'] ?? 0}',
                      'Successful: ${apiStats['successfulRequests'] ?? 0}',
                      'Failed: ${apiStats['failedRequests'] ?? 0}',
                      'Average Response Time: ${apiStats['averageResponseTime'] ?? 0} ms',
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildMetricsSection(
                    'Cache Service',
                    Icons.storage,
                    Colors.amber.shade700,
                    [
                      'Cache Hits: ${cacheStats['hits'] ?? 0}',
                      'Cache Misses: ${cacheStats['misses'] ?? 0}',
                      'Hit Rate: ${cacheStats['hitRate'] ?? 0}%',
                      'Items Stored: ${cacheStats['itemsStored'] ?? 0}',
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildMetricsSection(
                    'Navigation Service',
                    Icons.navigation,
                    Colors.green.shade700,
                    [
                      'Navigation Count: ${navStats['navigationCount'] ?? 0}',
                      'Current Depth: ${navStats['currentDepth'] ?? 0}',
                      'Max Depth: ${navStats['maxDepth'] ?? 0}',
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('Last Updated: $lastUpdated', 
                    style: const TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: Colors.grey,
                    ),
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsSection(
    String title,
    IconData icon,
    Color color,
    List<String> metrics,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...metrics.map((metric) => Padding(
              padding: const EdgeInsets.only(left: 28, bottom: 4),
              child: Text(metric),
            )),
      ],
    );
  }
}