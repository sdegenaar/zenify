import 'package:flutter/material.dart';
import 'package:zenify/zenify.dart';

import '../controllers/home_controller.dart';

/// A card widget that displays information about the hierarchical scope structure
class HierarchyInfoCard extends StatelessWidget {
  final HomeController controller;

  const HierarchyInfoCard({
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
              'Scope Hierarchy Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Obx(() {
              final stats = controller.hierarchyStats.value;
              final lastUpdated =
                  stats['lastUpdated'] as String? ?? 'Not available';
              final depth = stats['depth'] as int? ?? 0;
              final serviceCount = stats['serviceCount'] as int? ?? 0;
              final services = stats['services'] as List<dynamic>? ?? [];

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoRow('Hierarchy Depth', '$depth levels'),
                  _buildInfoRow('Total Services', '$serviceCount services'),
                  _buildInfoRow('Last Updated', lastUpdated),
                  const SizedBox(height: 16),
                  const Text(
                    'Available Services:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (services.isEmpty)
                    const Text('No services available')
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: services
                          .map((service) => Chip(
                                label: Text(
                                  service.toString().split('.').last,
                                  style: const TextStyle(fontSize: 12),
                                ),
                                backgroundColor: Colors.blue.shade100,
                              ))
                          .toList(),
                    ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(value),
        ],
      ),
    );
  }
}
