import 'dart:async';
import 'package:flutter/material.dart';
import 'package:zenify_devtools/src/models/metrics_data.dart';
import 'package:zenify_devtools/src/services/metrics_service.dart';

/// Screen for Zenify system metrics and performance monitoring
class MetricsScreen extends StatefulWidget {
  const MetricsScreen({super.key});

  @override
  State<MetricsScreen> createState() => _MetricsScreenState();
}

class _MetricsScreenState extends State<MetricsScreen> {
  final MetricsService _service = MetricsService();
  ZenifyMetrics? _metrics;
  bool _isLoading = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadMetrics();
    // Auto-refresh every 2 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _loadMetrics();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadMetrics() async {
    try {
      final metrics = await _service.getMetrics();
      if (mounted) {
        setState(() {
          _metrics = metrics;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _metrics == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_metrics == null) {
      return const Center(child: Text('Failed to load metrics'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 24),
          _buildScopeMetrics(),
          const SizedBox(height: 16),
          _buildQueryMetrics(),
          const SizedBox(height: 16),
          _buildDependencyMetrics(),
          if (_metrics!.memory != null) ...[
            const SizedBox(height: 16),
            _buildMemoryMetrics(),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Zenify System Metrics',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        Row(
          children: [
            Icon(
              Icons.circle,
              size: 12,
              color: _isLoading ? Colors.orange : Colors.green,
            ),
            const SizedBox(width: 8),
            Text(_isLoading ? 'Updating...' : 'Live'),
            const SizedBox(width: 16),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadMetrics,
              tooltip: 'Refresh metrics',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildScopeMetrics() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.account_tree, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'Scope Hierarchy',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    'Total Scopes',
                    _metrics!.totalScopes.toString(),
                    Colors.blue,
                    Icons.layers,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricTile(
                    'Active',
                    _metrics!.activeScopes.toString(),
                    Colors.green,
                    Icons.check_circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricTile(
                    'Disposed',
                    _metrics!.disposedScopes.toString(),
                    Colors.grey,
                    Icons.delete_outline,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQueryMetrics() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.storage, color: Colors.purple),
                const SizedBox(width: 8),
                Text(
                  'Query Cache',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    'Total Queries',
                    _metrics!.totalQueries.toString(),
                    Colors.purple,
                    Icons.data_object,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricTile(
                    'Active',
                    _metrics!.activeQueries.toString(),
                    Colors.blue,
                    Icons.play_arrow,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricTile(
                    'Cached',
                    _metrics!.cachedQueries.toString(),
                    Colors.green,
                    Icons.cached,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    'Global',
                    _metrics!.globalQueries.toString(),
                    Colors.indigo,
                    Icons.public,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricTile(
                    'Scoped',
                    _metrics!.scopedQueries.toString(),
                    Colors.teal,
                    Icons.folder,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    'Loading',
                    _metrics!.loadingQueries.toString(),
                    Colors.orange,
                    Icons.hourglass_bottom,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricTile(
                    'Errors',
                    _metrics!.errorQueries.toString(),
                    Colors.red,
                    Icons.error,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricTile(
                    'Stale',
                    _metrics!.staleQueries.toString(),
                    Colors.amber,
                    Icons.warning,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDependencyMetrics() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.widgets, color: Colors.orange),
                const SizedBox(width: 8),
                Text(
                  'Dependencies',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    'Total',
                    _metrics!.totalDependencies.toString(),
                    Colors.orange,
                    Icons.category,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricTile(
                    'Controllers',
                    _metrics!.totalControllers.toString(),
                    Colors.blue,
                    Icons.desktop_windows,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricTile(
                    'Services',
                    _metrics!.totalServices.toString(),
                    Colors.green,
                    Icons.settings,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemoryMetrics() {
    final memory = _metrics!.memory!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.memory, color: Colors.deepPurple),
                const SizedBox(width: 8),
                Text(
                  'Memory Usage',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    'RSS',
                    memory.formatBytes(memory.currentRss),
                    Colors.deepPurple,
                    Icons.memory,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricTile(
                    'Heap Size',
                    memory.formatBytes(memory.currentHeapSize),
                    Colors.purple,
                    Icons.storage,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricTile(
                    'Heap Used',
                    memory.formatBytes(memory.currentHeapUsed),
                    Colors.pink,
                    Icons.pie_chart,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile(
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha:0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
