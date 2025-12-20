// lib/devtools/inspector/widgets/stats_view.dart
import 'package:flutter/material.dart';
import '../../../debug/zen_system_stats.dart';

/// Displays system statistics and performance metrics
class StatsView extends StatefulWidget {
  const StatsView({super.key});

  @override
  State<StatsView> createState() => _StatsViewState();
}

class _StatsViewState extends State<StatsView> {
  @override
  Widget build(BuildContext context) {
    final stats = ZenSystemStats.getSystemStats();
    final navInfo = stats['navigation'] as Map<String, dynamic>?;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // System Overview
        _buildSectionHeader('System Overview'),
        const SizedBox(height: 12),
        _buildStatsGrid([
          _StatItem(
            'Scopes',
            (stats['totalScopes'] as int? ?? 0).toString(),
            Icons.account_tree,
            Colors.purple,
          ),
          _StatItem(
            'Dependencies',
            (stats['totalDependencies'] as int? ?? 0).toString(),
            Icons.extension,
            Colors.blue,
          ),
          _StatItem(
            'Controllers',
            (stats['totalControllers'] as int? ?? 0).toString(),
            Icons.gamepad,
            Colors.green,
          ),
          _StatItem(
            'Queries',
            (stats['totalQueries'] as int? ?? 0).toString(),
            Icons.cached,
            Colors.orange,
          ),
        ]),

        const SizedBox(height: 16),

        // Navigation
        if (navInfo != null) ...[
          _buildSectionHeader('Navigation'),
          const SizedBox(height: 12),
          _buildNavigationInfo(navInfo),
          const SizedBox(height: 16),
        ],

        // Memory
        _buildSectionHeader('Memory'),
        const SizedBox(height: 12),
        _buildMemoryInfo(stats),

        const SizedBox(height: 16),

        // Query Cache
        _buildSectionHeader('Query Cache'),
        const SizedBox(height: 12),
        _buildQueryCacheInfo(stats),

        const SizedBox(height: 16),

        // System Report
        _buildSectionHeader('System Report'),
        const SizedBox(height: 12),
        _buildSystemReport(),
      ],
    );
  }

  Widget _buildNavigationInfo(Map<String, dynamic> navInfo) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Column(
        children: [
          _buildMemoryRow('Current Route', navInfo['currentRoute'] ?? '/'),
          const Divider(color: Colors.grey, height: 16),
          _buildMemoryRow(
              'Total Navigations', navInfo['navigationCount'] ?? '0'),
          const Divider(color: Colors.grey, height: 16),
          _buildMemoryRow('Breadcrumbs', navInfo['breadcrumbCount'] ?? '0'),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildStatsGrid(List<_StatItem> items) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 2.2,
      children: items.map((item) => _buildStatCard(item)).toList(),
    );
  }

  Widget _buildStatCard(_StatItem item) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Row(
        children: [
          Icon(item.icon, color: item.color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  item.value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.label,
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 11,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemoryInfo(Map<String, dynamic> stats) {
    final scopeCount = stats['totalScopes'] as int? ?? 0;
    final depCount = stats['totalDependencies'] as int? ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Column(
        children: [
          _buildMemoryRow('Active Scopes', scopeCount.toString()),
          const Divider(color: Colors.grey),
          _buildMemoryRow('Total Dependencies', depCount.toString()),
          const Divider(color: Colors.grey),
          _buildMemoryRow('Disposed Objects', '0'),
        ],
      ),
    );
  }

  Widget _buildMemoryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey[400], fontSize: 14),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQueryCacheInfo(Map<String, dynamic> stats) {
    final queryCount = stats['totalQueries'] as int? ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Column(
        children: [
          _buildMemoryRow('Cached Queries', queryCount.toString()),
          const Divider(color: Colors.grey),
          _buildMemoryRow('Active Fetches', '0'),
          const Divider(color: Colors.grey),
          _buildMemoryRow('Failed Queries', '0'),
        ],
      ),
    );
  }

  Widget _buildSystemReport() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Full System Report',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 14,
                ),
              ),
              TextButton.icon(
                onPressed: _generateReport,
                icon: const Icon(Icons.description, size: 16),
                label: const Text('Generate'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.purple[400],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Generate a detailed report of the current system state',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  void _generateReport() {
    final report = ZenSystemStats.generateSystemReport();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'System Report',
          style: TextStyle(color: Colors.white),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: SelectableText(
              report,
              style: TextStyle(
                color: Colors.green[300],
                fontSize: 11,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _StatItem {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  _StatItem(this.label, this.value, this.icon, this.color);
}
