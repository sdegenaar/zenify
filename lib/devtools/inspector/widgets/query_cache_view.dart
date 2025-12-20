// lib/devtools/inspector/widgets/query_cache_view.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../query/core/zen_query_cache.dart';
import '../../../query/logic/zen_query.dart';

/// Displays all cached queries and their status
class QueryCacheView extends StatefulWidget {
  const QueryCacheView({super.key});

  @override
  State<QueryCacheView> createState() => _QueryCacheViewState();
}

class _QueryCacheViewState extends State<QueryCacheView> {
  String _searchQuery = '';
  String? _selectedQueryKey;

  @override
  Widget build(BuildContext context) {
    final cache = ZenQueryCache.instance;
    final allQueries = cache.queries;

    // Filter queries based on search
    final filteredQueries = allQueries.where((query) {
      if (_searchQuery.isEmpty) return true;
      return query.queryKey.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Row(
      children: [
        // Query list (left side)
        Expanded(
          flex: 2,
          child: Column(
            children: [
              // Search bar
              _buildSearchBar(),

              // Query list
              Expanded(
                child: filteredQueries.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        itemCount: filteredQueries.length,
                        itemBuilder: (context, index) {
                          final query = filteredQueries[index];
                          return _buildQueryListItem(query);
                        },
                      ),
              ),
            ],
          ),
        ),

        // Divider
        Container(width: 1, color: Colors.grey[800]),

        // Query details (right side)
        Expanded(
          flex: 3,
          child: _buildQueryDetails(),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[800]!)),
      ),
      child: TextField(
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Search queries...',
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
        onChanged: (value) => setState(() => _searchQuery = value),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cached, size: 64, color: Colors.grey[600]),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isEmpty ? 'No queries found' : 'No matching queries',
            style: TextStyle(color: Colors.grey[400], fontSize: 16),
          ),
          if (_searchQuery.isEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Create a ZenQuery to see it here',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQueryListItem(ZenQuery query) {
    final isSelected = _selectedQueryKey == query.queryKey;

    return InkWell(
      onTap: () => setState(() => _selectedQueryKey = query.queryKey),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.purple[700] : Colors.transparent,
          border: Border(
            bottom: BorderSide(color: Colors.grey[800]!),
          ),
        ),
        child: Row(
          children: [
            // Status indicator
            _buildStatusIndicator(query),
            const SizedBox(width: 12),

            // Query info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    query.queryKey,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.grey[300],
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _buildStatusChip(
                          query.status.value.toString().split('.').last),
                      const SizedBox(width: 8),
                      if (query.hasData)
                        Icon(Icons.check_circle,
                            size: 12, color: Colors.green[400]),
                      if (query.hasError)
                        Icon(Icons.error, size: 12, color: Colors.red[400]),
                    ],
                  ),
                ],
              ),
            ),

            // Actions
            if (isSelected)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 18),
                    onPressed: () => _refetchQuery(query),
                    tooltip: 'Refetch',
                    color: Colors.grey[400],
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.delete, size: 18),
                    onPressed: () => _invalidateQuery(query),
                    tooltip: 'Invalidate',
                    color: Colors.grey[400],
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(ZenQuery query) {
    Color color;
    if (query.isLoading.value) {
      color = Colors.blue[400]!;
    } else if (query.hasError) {
      color = Colors.red[400]!;
    } else if (query.isStale) {
      color = Colors.orange[400]!;
    } else if (query.hasData) {
      color = Colors.green[400]!;
    } else {
      color = Colors.grey[600]!;
    }

    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status.toUpperCase(),
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildQueryDetails() {
    if (_selectedQueryKey == null) {
      return Center(
        child: Text(
          'Select a query to view details',
          style: TextStyle(color: Colors.grey[500]),
        ),
      );
    }

    final cache = ZenQueryCache.instance;
    final query = cache.getQuery(_selectedQueryKey!);

    if (query == null) {
      return Center(
        child: Text(
          'Query not found',
          style: TextStyle(color: Colors.grey[500]),
        ),
      );
    }

    return Container(
      color: Colors.grey[900],
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Query info
          _buildDetailSection(
            'Query Information',
            [
              _buildDetailRow('Key', query.queryKey),
              _buildDetailRow(
                'Status',
                query.status.value.toString().split('.').last,
              ),
              _buildDetailRow('Has Data', query.hasData ? 'Yes' : 'No'),
              _buildDetailRow('Has Error', query.hasError ? 'Yes' : 'No'),
              _buildDetailRow('Is Stale', query.isStale ? 'Yes' : 'No'),
              _buildDetailRow(
                  'Is Loading', query.isLoading.value ? 'Yes' : 'No'),
              _buildDetailRow('Enabled', query.enabled.value ? 'Yes' : 'No'),
            ],
          ),

          const SizedBox(height: 16),

          // Data preview
          if (query.hasData)
            _buildDetailSection(
              'Data Preview',
              [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: SelectableText(
                    query.data.value.toString(),
                    style: TextStyle(
                      color: Colors.green[300],
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: () =>
                      _copyToClipboard(query.data.value.toString()),
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('Copy Data'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[800],
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),

          const SizedBox(height: 16),

          // Error preview
          if (query.hasError)
            _buildDetailSection(
              'Error',
              [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: SelectableText(
                    query.error.value.toString(),
                    style: TextStyle(
                      color: Colors.red[300],
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ),

          const SizedBox(height: 16),

          // Actions
          _buildDetailSection(
            'Actions',
            [
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _refetchQuery(query),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Refetch'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple[700],
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _invalidateQuery(query),
                      icon: const Icon(Icons.delete, size: 18),
                      label: const Text('Invalidate'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[700],
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[850],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
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
            width: 90,
            child: Text(
              '$label:',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Colors.grey[300],
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _refetchQuery(ZenQuery query) {
    query.refetch();
    setState(() {});
    _showSnackBar('Refetching ${query.queryKey}...');
  }

  void _invalidateQuery(ZenQuery query) {
    ZenQueryCache.instance.invalidateQuery(query.queryKey);
    setState(() {});
    _showSnackBar('Invalidated ${query.queryKey}');
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    _showSnackBar('Copied to clipboard');
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.grey[800],
      ),
    );
  }
}
