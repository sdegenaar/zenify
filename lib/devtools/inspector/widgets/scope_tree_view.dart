// lib/devtools/inspector/widgets/scope_tree_view.dart
import 'package:flutter/material.dart';
import '../../../core/zen_scope.dart';
import '../../../debug/zen_debug.dart';
import '../../../di/zen_di.dart';
import '../../../utils/zen_scope_inspector.dart';
import '../../../widgets/scope/zen_scope_widget.dart';

/// Displays the hierarchical scope tree
class ScopeTreeView extends StatefulWidget {
  const ScopeTreeView({super.key});

  @override
  State<ScopeTreeView> createState() => _ScopeTreeViewState();
}

class _ScopeTreeViewState extends State<ScopeTreeView> {
  ZenScope? _selectedScope;
  final Set<String> _expandedScopes = {};

  @override
  void initState() {
    super.initState();
    // Start with root scope selected
    _selectedScope = Zen.rootScope;
    _expandedScopes.add(Zen.rootScope.id);
  }

  @override
  Widget build(BuildContext context) {
    final allScopes = ZenDebug.allScopes;

    if (allScopes.isEmpty) {
      return _buildEmptyState();
    }

    // Try to get current scope from context
    final currentScope = _getCurrentScope(context);

    return Column(
      children: [
        // Current scope indicator
        if (currentScope != null) _buildCurrentScopeIndicator(currentScope),

        // Main content
        Expanded(
          child: Row(
            children: [
              // Scope tree (left side)
              Expanded(
                flex: 2,
                child: Container(
                  color: Colors.grey[850],
                  child: ListView(
                    padding: const EdgeInsets.all(8),
                    children: [
                      _buildScopeTree(Zen.rootScope, 0),
                    ],
                  ),
                ),
              ),

              // Divider
              Container(width: 1, color: Colors.grey[800]),

              // Scope details (right side)
              Expanded(
                flex: 3,
                child: _buildScopeDetails(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  ZenScope? _getCurrentScope(BuildContext context) {
    try {
      return context.mayFindScope();
    } catch (e) {
      return null;
    }
  }

  Widget _buildCurrentScopeIndicator(ZenScope scope) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.purple[900]!.withValues(alpha: 0.3),
        border: Border(
          bottom: BorderSide(color: Colors.purple[700]!, width: 2),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.my_location, size: 16, color: Colors.purple[300]),
          const SizedBox(width: 8),
          Text(
            'Current Scope:',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            scope.name ?? 'Unnamed',
            style: TextStyle(
              color: Colors.purple[300],
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '(${scope.id.substring(0, 8)}...)',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 10,
              fontFamily: 'monospace',
            ),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: () {
              setState(() {
                _selectedScope = scope;
                // Expand parent scopes to show this scope
                var parent = scope.parent;
                while (parent != null) {
                  _expandedScopes.add(parent.id);
                  parent = parent.parent;
                }
              });
            },
            icon: Icon(Icons.visibility, size: 14, color: Colors.purple[300]),
            label: Text(
              'View',
              style: TextStyle(color: Colors.purple[300], fontSize: 11),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
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
          Icon(Icons.account_tree, size: 64, color: Colors.grey[600]),
          const SizedBox(height: 16),
          Text(
            'No scopes found',
            style: TextStyle(color: Colors.grey[400], fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'Initialize Zenify with Zen.init()',
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildScopeTree(ZenScope scope, int depth) {
    final isExpanded = _expandedScopes.contains(scope.id);
    final isSelected = _selectedScope?.id == scope.id;
    final hasChildren = scope.childScopes.isNotEmpty;

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
              color: isSelected ? Colors.purple[700] : Colors.transparent,
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
                      size: 20,
                      color: Colors.grey[400],
                    ),
                  )
                else
                  const SizedBox(width: 20),

                const SizedBox(width: 4),

                // Scope icon
                Icon(
                  scope.parent == null ? Icons.hub : Icons.folder,
                  size: 16,
                  color: scope.parent == null
                      ? Colors.purple[400]
                      : Colors.blue[400],
                ),
                const SizedBox(width: 8),

                // Scope name
                Expanded(
                  child: Text(
                    scope.name ?? 'Unnamed',
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.grey[300],
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                // Dependency count badge
                _buildBadge(scope),
              ],
            ),
          ),
        ),

        // Child scopes
        if (hasChildren && isExpanded)
          ...scope.childScopes
              .map((child) => _buildScopeTree(child, depth + 1)),
      ],
    );
  }

  Widget _buildBadge(ZenScope scope) {
    // Get actual dependency count
    final breakdown = ZenScopeInspector.getDependencyBreakdown(scope);
    final summary = breakdown['summary'] as Map<String, dynamic>? ?? {};
    final count = summary['grandTotal'] as int? ?? 0;

    if (count == 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.grey[700],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
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
      color: Colors.grey[900],
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Scope info
          _buildDetailSection(
            'Scope Information',
            [
              _buildDetailRow('Name', scope.name ?? 'Unnamed'),
              _buildDetailRow('ID', scope.id),
              _buildDetailRow(
                'Parent',
                scope.parent?.name ?? 'None (Root)',
              ),
              _buildDetailRow(
                'Children',
                '${scope.childScopes.length}',
              ),
              _buildDetailRow(
                'Disposed',
                scope.isDisposed ? 'Yes' : 'No',
                valueColor: scope.isDisposed ? Colors.red : Colors.green,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Dependencies
          _buildDependenciesSection(scope),
        ],
      ),
    );
  }

  Widget _buildDependenciesSection(ZenScope scope) {
    final breakdown = ZenScopeInspector.getDependencyBreakdown(scope);
    final controllers = breakdown['controllers'] as List<dynamic>? ?? [];
    final services = breakdown['services'] as List<dynamic>? ?? [];
    final others = breakdown['others'] as List<dynamic>? ?? [];
    final summary = breakdown['summary'] as Map<String, dynamic>? ?? {};
    final total = summary['grandTotal'] as int? ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Dependencies ($total)',
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
            children: [
              if (total == 0)
                Text(
                  'No dependencies in this scope',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                )
              else ...[
                // Controllers
                if (controllers.isNotEmpty) ...[
                  _buildDependencyCategory(
                    'Controllers',
                    controllers,
                    Colors.blue,
                    Icons.gamepad,
                  ),
                  if (services.isNotEmpty || others.isNotEmpty)
                    const SizedBox(height: 12),
                ],
                // Services
                if (services.isNotEmpty) ...[
                  _buildDependencyCategory(
                    'Services',
                    services,
                    Colors.green,
                    Icons.storage,
                  ),
                  if (others.isNotEmpty) const SizedBox(height: 12),
                ],
                // Others
                if (others.isNotEmpty) ...[
                  _buildDependencyCategory(
                    'Others',
                    others,
                    Colors.orange,
                    Icons.extension,
                  ),
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDependencyCategory(
    String title,
    List<dynamic> items,
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
        ...items.map((item) => Padding(
              padding: const EdgeInsets.only(left: 20, top: 4),
              child: Row(
                children: [
                  Icon(Icons.circle, size: 4, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.toString(),
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            )),
      ],
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
                color: valueColor ?? Colors.grey[300],
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
