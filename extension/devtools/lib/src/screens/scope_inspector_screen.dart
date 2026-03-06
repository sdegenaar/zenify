import 'package:flutter/material.dart';
import 'package:zenify_devtools/src/services/scope_service.dart';
import 'package:zenify_devtools/src/models/scope_data.dart';

/// Screen for inspecting scope hierarchy and dependencies
class ScopeInspectorScreen extends StatefulWidget {
  const ScopeInspectorScreen({super.key});

  @override
  State<ScopeInspectorScreen> createState() => _ScopeInspectorScreenState();
}

class _ScopeInspectorScreenState extends State<ScopeInspectorScreen> {
  final ScopeService _scopeService = ScopeService();
  List<ScopeData>? _scopes;
  ScopeData? _selectedScope;
  final Set<String> _expandedScopes = {};
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadScopes();
  }

  Future<void> _loadScopes() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final scopes = await _scopeService.getAllScopes();
      setState(() {
        _scopes = scopes;
        _isLoading = false;
        // Auto-select root scope and expand it
        if (scopes.isNotEmpty) {
          _selectedScope = scopes.first;
          _expandedScopes.add(scopes.first.id);
        }
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _buildErrorState();
    }

    if (_scopes == null || _scopes!.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      children: [
        // Toolbar
        _buildToolbar(),

        // Main content
        Expanded(
          child: Row(
            children: [
              // Scope tree (left side)
              Expanded(
                flex: 2,
                child: Container(
                  color: const Color(0xFF1E1E1E),
                  child: ListView(
                    padding: const EdgeInsets.all(8),
                    children: [_buildScopeTree(_scopes!.first, 0)],
                  ),
                ),
              ),

              // Divider
              Container(width: 1, color: const Color(0xFF2D2D2D)),

              // Scope details (right side)
              Expanded(flex: 3, child: _buildScopeDetails()),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF2D2D2D),
        border: Border(bottom: BorderSide(color: Color(0xFF3D3D3D))),
      ),
      child: Row(
        children: [
          const Icon(Icons.account_tree, size: 18, color: Colors.blue),
          const SizedBox(width: 8),
          Text(
            'Scope Hierarchy (${_scopes?.length ?? 0} scopes)',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.refresh, size: 18),
            onPressed: _loadScopes,
            tooltip: 'Refresh',
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          const Text('Failed to load scopes', style: TextStyle(fontSize: 18)),
          const SizedBox(height: 8),
          Text(_error ?? 'Unknown error', style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadScopes,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
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
          const Icon(Icons.account_tree, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('No scopes found', style: TextStyle(fontSize: 16)),
          const SizedBox(height: 8),
          Text(
            'Initialize Zenify with Zen.init() in your app',
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadScopes,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
          ),
        ],
      ),
    );
  }

  Widget _buildScopeTree(ScopeData scope, int depth) {
    final isExpanded = _expandedScopes.contains(scope.id);
    final isSelected = _selectedScope?.id == scope.id;
    final hasChildren = scope.children.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Scope node
        InkWell(
          onTap: () => setState(() => _selectedScope = scope),
          child: Container(
            margin: EdgeInsets.only(left: depth * 16.0),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.blue.withValues(alpha:0.3)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                // Expand/collapse icon
                if (hasChildren)
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        if (isExpanded) {
                          _expandedScopes.remove(scope.id);
                        } else {
                          _expandedScopes.add(scope.id);
                        }
                      });
                    },
                    child: Icon(
                      isExpanded ? Icons.expand_more : Icons.chevron_right,
                      size: 18,
                      color: Colors.grey,
                    ),
                  )
                else
                  const SizedBox(width: 18),

                const SizedBox(width: 4),

                // Scope icon
                Icon(
                  scope.isRoot ? Icons.hub : Icons.folder,
                  size: 16,
                  color: scope.isRoot ? Colors.purple : Colors.blue,
                ),
                const SizedBox(width: 8),

                // Scope name
                Expanded(
                  child: Text(
                    scope.name,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.grey[300],
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                // Dependency count badge
                if (scope.dependencyCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3D3D3D),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${scope.dependencyCount}',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

        // Child scopes
        if (hasChildren && isExpanded)
          ...scope.children.map((child) => _buildScopeTree(child, depth + 1)),
      ],
    );
  }

  Widget _buildScopeDetails() {
    if (_selectedScope == null) {
      return Center(
        child: Text(
          'Select a scope to view details',
          style: TextStyle(color: Colors.grey[500]),
        ),
      );
    }

    final scope = _selectedScope!;

    return Container(
      color: const Color(0xFF1E1E1E),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Scope info
          _buildDetailSection('Scope Information', [
            _buildDetailRow('Name', scope.name),
            _buildDetailRow('ID', '${scope.id.substring(0, 12)}...'),
            _buildDetailRow('Parent', scope.parentName ?? 'None (Root)'),
            _buildDetailRow('Children', '${scope.children.length}'),
            _buildDetailRow(
              'Disposed',
              scope.isDisposed ? 'Yes' : 'No',
              valueColor: scope.isDisposed ? Colors.red : Colors.green,
            ),
          ]),

          const SizedBox(height: 16),

          // Dependencies
          _buildDependenciesSection(scope),
        ],
      ),
    );
  }

  Widget _buildDependenciesSection(ScopeData scope) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Dependencies (${scope.dependencyCount})',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF2D2D2D),
            borderRadius: BorderRadius.circular(8),
          ),
          child: scope.dependencyCount == 0
              ? Text(
                  'No dependencies in this scope',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (scope.controllers.isNotEmpty) ...[
                      _buildDependencyCategory(
                        'Controllers',
                        scope.controllers,
                        Colors.blue,
                        Icons.gamepad,
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (scope.services.isNotEmpty) ...[
                      _buildDependencyCategory(
                        'Services',
                        scope.services,
                        Colors.green,
                        Icons.storage,
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (scope.others.isNotEmpty)
                      _buildDependencyCategory(
                        'Others',
                        scope.others,
                        Colors.orange,
                        Icons.extension,
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildDependencyCategory(
    String title,
    List<String> items,
    Color color,
    IconData icon,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              '$title (${items.length})',
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(left: 20, top: 4),
            child: Row(
              children: [
                Icon(Icons.circle, size: 4, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item,
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 11,
                      fontFamily: 'Courier',
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF2D2D2D),
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

  Widget _buildDetailRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: valueColor ?? Colors.grey[300],
                fontSize: 12,
                fontFamily: 'Courier',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
