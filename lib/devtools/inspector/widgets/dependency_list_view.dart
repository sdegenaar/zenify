// lib/devtools/inspector/widgets/dependency_list_view.dart
import 'package:flutter/material.dart';
import '../../../debug/zen_system_stats.dart';

/// Displays all registered dependencies across all scopes
class DependencyListView extends StatefulWidget {
  const DependencyListView({super.key});

  @override
  State<DependencyListView> createState() => _DependencyListViewState();
}

class _DependencyListViewState extends State<DependencyListView> {
  // String _searchQuery = ''; // TODO: Implement search functionality

  @override
  Widget build(BuildContext context) {
    final stats = ZenSystemStats.getSystemStats();
    final totalDependencies = stats['totalDependencies'] as int? ?? 0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Search bar
        _buildSearchBar(),

        // Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.grey[800]!)),
          ),
          child: Row(
            children: [
              Icon(Icons.extension, color: Colors.purple[400]),
              const SizedBox(width: 12),
              Text(
                'Total Dependencies: $totalDependencies',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),

        // Dependency list
        Expanded(
          child: totalDependencies == 0
              ? _buildEmptyState()
              : _buildDependencyList(stats),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[800]!)),
      ),
      child: TextField(
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Search dependencies...',
          hintStyle: TextStyle(color: Colors.grey[600]),
          prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
          filled: true,
          fillColor: Colors.grey[850],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
        onChanged: (value) {
          // TODO: Implement search
          setState(() {});
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.extension, size: 64, color: Colors.grey[600]),
          const SizedBox(height: 16),
          Text(
            'No dependencies found',
            style: TextStyle(color: Colors.grey[400], fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'Register dependencies with Zen.put() or scope.put()',
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildDependencyList(Map<String, dynamic> stats) {
    // This is a simplified view - full implementation would show actual dependencies
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildInfoCard(
          'Controllers',
          stats['totalControllers'] as int? ?? 0,
          Icons.gamepad,
          Colors.blue,
        ),
        const SizedBox(height: 12),
        _buildInfoCard(
          'Services',
          stats['totalServices'] as int? ?? 0,
          Icons.storage,
          Colors.green,
        ),
        const SizedBox(height: 12),
        _buildInfoCard(
          'Queries',
          stats['totalQueries'] as int? ?? 0,
          Icons.cached,
          Colors.purple,
        ),
        const SizedBox(height: 24),
        Text(
          'Detailed dependency inspection coming soon',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
            fontStyle: FontStyle.italic,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildInfoCard(String title, int count, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  count.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
