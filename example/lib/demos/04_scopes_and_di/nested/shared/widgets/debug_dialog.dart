import 'package:flutter/material.dart';
import 'package:zenify/zenify.dart';
import '../../app/services/navigation_service.dart';

/// Debug dialog showing scope hierarchy and dependencies
///
/// Simplified for the new widget tree-based architecture
class DebugDialog extends StatelessWidget {
  const DebugDialog({super.key});

  Map<String, dynamic> _collectDebugData(BuildContext context) {
    final data = <String, dynamic>{};

    try {
      // Get current scope from widget tree
      final currentScope = context.zenScope;
      if (currentScope != null) {
        data['currentScopeName'] = currentScope.name ?? 'unnamed';
        data['currentScopeId'] = currentScope.id;
        data['currentScopeDisposed'] = currentScope.isDisposed;

        // Get dependencies in current scope
        final breakdown =
            ZenScopeInspector.getDependencyBreakdown(currentScope);
        data['currentScopeBreakdown'] = breakdown;
        data['currentScopeDependencies'] = breakdown['controllers'].length +
            breakdown['services'].length +
            breakdown['others'].length;
      } else {
        data['currentScopeName'] = 'None (not in scope)';
      }

      // Get all scopes (from root hierarchy)
      final allScopes = ZenDebug.allScopes;
      data['totalScopes'] = allScopes.length;
      data['activeScopes'] = allScopes.where((s) => !s.isDisposed).length;
      data['disposedScopes'] = allScopes.where((s) => s.isDisposed).length;

      // Collect scope info
      data['allScopesInfo'] = allScopes.map((scope) {
        final breakdown = ZenScopeInspector.getDependencyBreakdown(scope);
        return {
          'name': scope.name,
          'id': scope.id,
          'disposed': scope.isDisposed,
          'dependencyCount': breakdown['controllers'].length +
              breakdown['services'].length +
              breakdown['others'].length,
          'breakdown': breakdown,
          'parent': scope.parent?.name ?? 'None',
          'childCount': scope.childScopes.length,
        };
      }).toList();

      // Get navigation info
      try {
        final navService = Zen.find<NavigationService>();
        data['currentRoute'] = navService.currentPath.value;
        data['navigationCount'] = navService.navigationCount.value;
      } catch (e) {
        data['navigationError'] = e.toString();
        data['currentRoute'] = 'NavigationService not accessible';
      }

      data['timestamp'] = DateTime.now().toString();
    } catch (e, stackTrace) {
      data['error'] = 'Failed to collect debug data: $e';
      data['stackTrace'] = stackTrace.toString();
    }

    return data;
  }

  @override
  Widget build(BuildContext context) {
    final debugData = _collectDebugData(context);

    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.developer_mode, color: Colors.purple),
                const SizedBox(width: 8),
                const Text(
                  'Zenify Debug Info',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () {
                    Navigator.pop(context);
                    showDialog(
                      context: context,
                      builder: (context) => const DebugDialog(),
                    );
                  },
                  tooltip: 'Refresh',
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(),

            // Content
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Info box about new architecture
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        border: Border.all(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.3),
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '✨ Widget Tree Architecture: Scopes are managed by Flutter\'s widget tree. Parent-child relationships are automatic!',
                              style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onPrimaryContainer,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Current Scope
                    _buildSection(context, 'Current Scope', [
                      _buildDataRow(context, 'Name',
                          debugData['currentScopeName']?.toString() ?? 'None'),
                      if (debugData['currentScopeId'] != null) ...[
                        _buildDataRow(context, 'ID',
                            debugData['currentScopeId']?.toString() ?? ''),
                        _buildDataRow(
                            context,
                            'Disposed',
                            debugData['currentScopeDisposed']?.toString() ??
                                'false'),
                        _buildDataRow(
                            context,
                            'Dependencies',
                            debugData['currentScopeDependencies']?.toString() ??
                                '0'),
                      ],
                      _buildDataRow(context, 'Route',
                          debugData['currentRoute']?.toString() ?? 'Unknown'),
                    ]),

                    const SizedBox(height: 16),

                    // Current Scope Dependencies
                    if (debugData['currentScopeBreakdown'] != null)
                      _buildCurrentScopeDependencies(context, debugData),

                    const SizedBox(height: 16),

                    // System Statistics
                    _buildSection(context, 'System Statistics', [
                      _buildDataRow(context, 'Total Scopes',
                          debugData['totalScopes']?.toString() ?? '0'),
                      _buildDataRow(context, 'Active Scopes',
                          debugData['activeScopes']?.toString() ?? '0'),
                      _buildDataRow(context, 'Disposed Scopes',
                          debugData['disposedScopes']?.toString() ?? '0'),
                      _buildDataRow(context, 'Navigation Count',
                          debugData['navigationCount']?.toString() ?? '0'),
                    ]),

                    const SizedBox(height: 16),

                    // All Scopes Hierarchy
                    _buildSection(
                        context,
                        'Scope Hierarchy',
                        (debugData['allScopesInfo'] as List<dynamic>? ?? [])
                            .map((scopeInfo) =>
                                _buildScopeCard(context, scopeInfo))
                            .toList()),

                    const SizedBox(height: 16),

                    // Errors
                    if (debugData['error'] != null ||
                        debugData['navigationError'] != null)
                      _buildSection(context, 'Errors', [
                        if (debugData['error'] != null)
                          _buildErrorRow(context, 'General Error',
                              debugData['error'].toString()),
                        if (debugData['navigationError'] != null)
                          _buildErrorRow(context, 'Navigation Error',
                              debugData['navigationError'].toString()),
                      ]),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentScopeDependencies(
      BuildContext context, Map<String, dynamic> debugData) {
    final breakdown =
        debugData['currentScopeBreakdown'] as Map<String, dynamic>?;
    if (breakdown == null) return const SizedBox.shrink();

    final controllers = breakdown['controllers'] as List<dynamic>? ?? [];
    final services = breakdown['services'] as List<dynamic>? ?? [];
    final others = breakdown['others'] as List<dynamic>? ?? [];

    return _buildSection(context, 'Current Scope Dependencies', [
      if (controllers.isEmpty && services.isEmpty && others.isEmpty)
        const Text('No local dependencies in this scope',
            style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey))
      else ...[
        if (controllers.isNotEmpty) ...[
          const Text('Controllers:',
              style:
                  TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
          const SizedBox(height: 4),
          ...controllers
              .map((c) => _buildDependencyItem(c.toString(), Colors.blue)),
          const SizedBox(height: 8),
        ],
        if (services.isNotEmpty) ...[
          const Text('Services:',
              style:
                  TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
          const SizedBox(height: 4),
          ...services
              .map((s) => _buildDependencyItem(s.toString(), Colors.green)),
          const SizedBox(height: 8),
        ],
        if (others.isNotEmpty) ...[
          const Text('Others:',
              style:
                  TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
          const SizedBox(height: 4),
          ...others
              .map((o) => _buildDependencyItem(o.toString(), Colors.orange)),
        ],
      ],
    ]);
  }

  Widget _buildDependencyItem(String name, Color color) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 2),
      child: Row(
        children: [
          Icon(Icons.circle, size: 6, color: color),
          const SizedBox(width: 8),
          Text(name, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildScopeCard(BuildContext context, Map<String, dynamic> scopeInfo) {
    final name = scopeInfo['name']?.toString() ?? 'Unknown';
    final parent = scopeInfo['parent']?.toString() ?? 'None';
    final disposed = scopeInfo['disposed'] == true;
    final depCount = scopeInfo['dependencyCount']?.toString() ?? '0';
    final childCount = scopeInfo['childCount']?.toString() ?? '0';

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = isDark ? Colors.green.shade300 : Colors.green.shade700;
    final disposedColor = isDark ? Colors.red.shade300 : Colors.red.shade700;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: disposed
            ? Colors.red.withValues(alpha: isDark ? 0.2 : 0.08)
            : Colors.green.withValues(alpha: isDark ? 0.2 : 0.08),
        border: Border.all(
          color: disposed
              ? Colors.red.withValues(alpha: isDark ? 0.5 : 0.3)
              : Colors.green.withValues(alpha: isDark ? 0.5 : 0.3),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                disposed ? Icons.cancel : Icons.check_circle,
                size: 16,
                color: disposed ? disposedColor : activeColor,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: disposed ? disposedColor : activeColor,
                  ),
                ),
              ),
              if (disposed)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: isDark ? 0.3 : 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'DISPOSED',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: disposedColor,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Parent: $parent  •  Deps: $depCount  •  Children: $childCount',
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
      BuildContext context, String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildDataRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontFamily: 'monospace',
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorRow(BuildContext context, String label, String error) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        border: Border.all(
          color: Theme.of(context).colorScheme.error.withValues(alpha: 0.3),
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onErrorContainer,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            error,
            style: TextStyle(
              fontSize: 12,
              fontFamily: 'monospace',
              color: Theme.of(context).colorScheme.onErrorContainer,
            ),
          ),
        ],
      ),
    );
  }
}
