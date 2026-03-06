import 'package:flutter/material.dart';
import 'package:zenify_devtools/src/models/query_cache_data.dart';
import 'package:zenify_devtools/src/services/query_cache_service.dart';

/// Screen for inspecting ZenQuery cache
class QueryCacheScreen extends StatefulWidget {
  const QueryCacheScreen({super.key});

  @override
  State<QueryCacheScreen> createState() => _QueryCacheScreenState();
}

class _QueryCacheScreenState extends State<QueryCacheScreen> {
  final QueryCacheService _service = QueryCacheService();
  List<QueryCacheData> _queries = [];
  QueryCacheStats? _stats;
  bool _isLoading = true;
  String _searchQuery = '';
  String _filterStatus = 'all';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final queries = await _service.getQueries();
      final stats = await _service.getStats();
      setState(() {
        _queries = queries;
        _stats = stats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  List<QueryCacheData> get _filteredQueries {
    return _queries.where((q) {
      // Filter by search query
      if (_searchQuery.isNotEmpty &&
          !q.queryKey.toLowerCase().contains(_searchQuery.toLowerCase())) {
        return false;
      }

      // Filter by status
      if (_filterStatus != 'all') {
        if (_filterStatus == 'loading' && !q.isLoading) return false;
        if (_filterStatus == 'error' && !q.hasError) return false;
        if (_filterStatus == 'stale' && !q.isStale) return false;
        if (_filterStatus == 'fresh' && q.isStale) return false;
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        // Stats Header
        if (_stats != null) _buildStatsCard(),

        // Search and Filters
        _buildSearchAndFilters(),

        // Query List
        Expanded(
          child: _filteredQueries.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  itemCount: _filteredQueries.length,
                  itemBuilder: (context, index) {
                    return _buildQueryTile(_filteredQueries[index]);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildStatsCard() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Query Cache Statistics',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadData,
                  tooltip: 'Refresh',
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatChip(
                  'Total',
                  _stats!.totalQueries.toString(),
                  Colors.blue,
                ),
                _buildStatChip(
                  'Loading',
                  _stats!.loadingQueries.toString(),
                  Colors.orange,
                ),
                _buildStatChip(
                  'Success',
                  _stats!.successQueries.toString(),
                  Colors.green,
                ),
                _buildStatChip(
                  'Error',
                  _stats!.errorQueries.toString(),
                  Colors.red,
                ),
                _buildStatChip(
                  'Stale',
                  _stats!.staleQueries.toString(),
                  Colors.amber,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatChip(
                  'Global',
                  _stats!.globalQueries.toString(),
                  Colors.purple,
                ),
                _buildStatChip(
                  'Scoped',
                  _stats!.scopedQueries.toString(),
                  Colors.teal,
                ),
                _buildStatChip(
                  'Active Scopes',
                  _stats!.activeScopes.toString(),
                  Colors.indigo,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatChip(String label, String value, Color color) {
    return Chip(
      avatar: CircleAvatar(
        backgroundColor: color,
        child: Text(
          value,
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      ),
      label: Text(label),
    );
  }

  Widget _buildSearchAndFilters() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search queries...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 16),
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value);
              },
            ),
          ),
          const SizedBox(width: 16),
          DropdownButton<String>(
            value: _filterStatus,
            items: const [
              DropdownMenuItem(value: 'all', child: Text('All')),
              DropdownMenuItem(value: 'loading', child: Text('Loading')),
              DropdownMenuItem(value: 'error', child: Text('Error')),
              DropdownMenuItem(value: 'stale', child: Text('Stale')),
              DropdownMenuItem(value: 'fresh', child: Text('Fresh')),
            ],
            onChanged: (value) {
              setState(() => _filterStatus = value!);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.storage_outlined,
            size: 64,
            color: Theme.of(context).disabledColor,
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isEmpty
                ? 'No queries in cache'
                : 'No queries match your search',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildQueryTile(QueryCacheData query) {
    return ExpansionTile(
      leading: Text(query.statusIcon, style: const TextStyle(fontSize: 24)),
      title: Text(
        query.queryKey,
        style: const TextStyle(fontFamily: 'monospace'),
      ),
      subtitle: Row(
        children: [
          Text('Status: ${query.status}'),
          const SizedBox(width: 16),
          Text('Age: ${query.ageString}'),
          const SizedBox(width: 16),
          Text('Fetches: ${query.fetchCount}'),
          if (query.scopeId != null) ...[
            const SizedBox(width: 16),
            Chip(
              label: Text(query.scopeId!, style: const TextStyle(fontSize: 11)),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ],
      ),
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Query Key', query.queryKey),
              _buildDetailRow('Status', query.status),
              _buildDetailRow('Loading', query.isLoading.toString()),
              _buildDetailRow('Stale', query.isStale.toString()),
              _buildDetailRow('Has Error', query.hasError.toString()),
              if (query.errorMessage != null)
                _buildDetailRow('Error', query.errorMessage!),
              if (query.dataTimestamp != null)
                _buildDetailRow(
                  'Data Timestamp',
                  query.dataTimestamp!.toIso8601String(),
                ),
              if (query.lastFetch != null)
                _buildDetailRow(
                  'Last Fetch',
                  query.lastFetch!.toIso8601String(),
                ),
              _buildDetailRow('Fetch Count', query.fetchCount.toString()),
              if (query.scopeId != null)
                _buildDetailRow('Scope ID', query.scopeId!),
              const SizedBox(height: 16),
              Row(
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refetch'),
                    onPressed: () => _refetchQuery(query.queryKey),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.warning),
                    label: const Text('Invalidate'),
                    onPressed: () => _invalidateQuery(query.queryKey),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _refetchQuery(String queryKey) async {
    await _service.refetchQuery(queryKey);
    await _loadData();
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Refetched: $queryKey')));
    }
  }

  Future<void> _invalidateQuery(String queryKey) async {
    await _service.invalidateQuery(queryKey);
    await _loadData();
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Invalidated: $queryKey')));
    }
  }
}
