
import 'package:flutter/material.dart';
import 'package:zenify/debug/zen_system_stats.dart';
import 'package:zenify/zenify.dart';
import '../../app/services/navigation_service.dart';

class DebugDialog extends StatefulWidget {
  const DebugDialog({super.key});

  @override
  State<DebugDialog> createState() => _DebugDialogState();
}

class _DebugDialogState extends State<DebugDialog> {
  bool _showAvailableDependencies = true; // State for the toggle

  Map<String, dynamic> _collectDebugDataFromZen() {
    final data = <String, dynamic>{};

    try {
      // Get scope stack info - this is the CORRECT current scope
      final stackInfo = ZenScopeStackTracker.getDebugInfo();
      data['scopeStack'] = stackInfo['stack'];
      data['stackSize'] = stackInfo['stackSize'];
      data['stackCurrentScope'] = stackInfo['currentScope']; // This is the REAL current scope

      // Get what Zen.currentScope thinks (might be wrong)
      final zenCurrentScope = Zen.currentScope;
      data['zenCurrentScopeName'] = zenCurrentScope.name ?? 'unnamed';
      data['zenCurrentScopeId'] = zenCurrentScope.id;

      // The ACTUAL current scope should be from the stack
      final actualCurrentScopeName = stackInfo['currentScope'] as String?;
      data['actualCurrentScopeName'] = actualCurrentScopeName ?? 'None';

      // Find the actual current scope instance
      ZenScope? actualCurrentScope;
      if (actualCurrentScopeName != null) {
        actualCurrentScope = ZenScopeManager.getScope(actualCurrentScopeName);
      }

      if (actualCurrentScope != null) {
        final actualScopeInfo = ZenScopeInspector.toDebugMap(actualCurrentScope);
        final scopeInfo = actualScopeInfo['scopeInfo'] as Map<String, dynamic>?;
        final dependencies = actualScopeInfo['dependencies'] as Map<String, dynamic>?;

        data['actualCurrentScopeId'] = scopeInfo?['id'] ?? 'Unknown';
        data['actualCurrentScopeDisposed'] = scopeInfo?['disposed'] ?? false;
        data['actualCurrentScopeDependencies'] = dependencies?['totalDependencies'] ?? 0;

        // Get dependency breakdown for actual current scope
        final breakdown = ZenScopeInspector.getDependencyBreakdown(actualCurrentScope);
        data['actualCurrentScopeBreakdown'] = breakdown;
      } else {
        data['actualCurrentScopeId'] = 'Not Found';
        data['actualCurrentScopeDisposed'] = 'Unknown';
        data['actualCurrentScopeDependencies'] = 0;
      }

      // Use ZenSystemStats for comprehensive system info
      final systemStats = ZenSystemStats.getSystemStats();
      data['systemStats'] = systemStats;

      // Extract key stats
      final scopes = systemStats['scopes'] as Map<String, dynamic>?;
      data['totalScopes'] = scopes?['total'] ?? 0;
      data['activeScopes'] = scopes?['active'] ?? 0;
      data['disposedScopes'] = scopes?['disposed'] ?? 0;

      final deps = systemStats['dependencies'] as Map<String, dynamic>?;
      data['totalDependencies'] = deps?['total'] ?? 0;
      data['totalControllers'] = deps?['controllers'] ?? 0;
      data['totalServices'] = deps?['services'] ?? 0;

      // Get all scopes using ZenScopeManager
      final allScopes = ZenScopeManager.getAllScopes();
      data['allScopesInfo'] = allScopes.map((scope) {
        final scopeDebugInfo = ZenScopeInspector.toDebugMap(scope);
        final scopeData = scopeDebugInfo['scopeInfo'] as Map<String, dynamic>;
        final dependencies = scopeDebugInfo['dependencies'] as Map<String, dynamic>;

        return {
          'name': scopeData['name'],
          'id': scopeData['id'],
          'disposed': scopeData['disposed'],
          'dependencyCount': dependencies['totalDependencies'],
          'breakdown': ZenScopeInspector.getDependencyBreakdown(scope),
          'isZenCurrentScope': scope == Zen.currentScope,
          'isActualCurrentScope': scope.name == actualCurrentScopeName,
        };
      }).toList();

      // Check if Zen.currentScope matches stack current scope
      data['scopeMismatch'] = zenCurrentScope.name != actualCurrentScopeName;

      // Try to get NavigationService info
      try {
        final navService = Zen.find<NavigationService>();
        data['currentRoute'] = navService.currentPath.value;
        data['navigationCount'] = navService.navigationCount.value;
      } catch (e) {
        data['navigationError'] = e.toString();
        data['currentRoute'] = 'NavigationService not accessible';
        data['navigationCount'] = 0;
      }

      // Add timestamp (just for reference, not for auto-refresh)
      data['timestamp'] = DateTime.now().toString();

    } catch (e, stackTrace) {
      data['error'] = 'Failed to collect debug data: $e';
      data['stackTrace'] = stackTrace.toString();
    }

    return data;
  }

  @override
  Widget build(BuildContext context) {
    // Get debug data once when building
    final debugData = _collectDebugDataFromZen();

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
                  'Zen Framework Debug Info',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                // Manual refresh button (rebuilds the dialog)
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () {
                    // Close and reopen to refresh data
                    Navigator.pop(context);
                    showDialog(
                      context: context,
                      builder: (context) => const DebugDialog(),
                    );
                  },
                  tooltip: 'Refresh Data',
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
                    // Scope Mismatch Warning
                    if (debugData['scopeMismatch'] == true)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          border: Border.all(color: Colors.orange.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.warning, color: Colors.orange.shade700),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Scope Mismatch Detected!',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange.shade700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Zen.currentScope ≠ Stack Current Scope',
                                    style: TextStyle(color: Colors.orange.shade700),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Current Scope Status
                    _buildSection('Current Scope Status', [
                      _buildDataRow('ACTUAL Current (from Stack)', debugData['actualCurrentScopeName']?.toString() ?? 'None'),
                      _buildDataRow('Zen.currentScope Says', debugData['zenCurrentScopeName']?.toString() ?? 'Unknown'),
                      const Divider(),
                      _buildDataRow('Actual Scope ID', debugData['actualCurrentScopeId']?.toString() ?? 'Unknown'),
                      _buildDataRow('Actual Is Disposed', debugData['actualCurrentScopeDisposed']?.toString() ?? 'Unknown'),
                      _buildDataRow('Actual Dependencies', debugData['actualCurrentScopeDependencies']?.toString() ?? '0'),
                      _buildDataRow('Current Route', debugData['currentRoute']?.toString() ?? 'Unknown'),
                    ]),

                    const SizedBox(height: 16),

                    // Actual Current Scope Dependencies
                    if (debugData['actualCurrentScopeBreakdown'] != null)
                      _buildCurrentScopeDependencies(debugData),

                    const SizedBox(height: 16),

                    // System Statistics
                    _buildSection('System Statistics', [
                      _buildDataRow('Total Scopes', debugData['totalScopes']?.toString() ?? '0'),
                      _buildDataRow('Active Scopes', debugData['activeScopes']?.toString() ?? '0'),
                      _buildDataRow('Disposed Scopes', debugData['disposedScopes']?.toString() ?? '0'),
                      _buildDataRow('Total Dependencies', debugData['totalDependencies']?.toString() ?? '0'),
                      _buildDataRow('Controllers', debugData['totalControllers']?.toString() ?? '0'),
                      _buildDataRow('Services', debugData['totalServices']?.toString() ?? '0'),
                      _buildDataRow('Navigation Count', debugData['navigationCount']?.toString() ?? '0'),
                    ]),

                    const SizedBox(height: 16),

                    // Scope Stack
                    _buildSection('Scope Stack (Navigation Order)', [
                      _buildDataRow('Stack Size', debugData['stackSize']?.toString() ?? '0'),
                      if (debugData['scopeStack'] != null) ...[
                        const SizedBox(height: 8),
                        const Text(
                          'Stack Order (bottom to top):',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 4),
                        ...((debugData['scopeStack'] as List<dynamic>?) ?? []).asMap().entries.map((entry) {
                          final index = entry.key;
                          final scopeName = entry.value.toString();
                          final isTop = index == ((debugData['scopeStack'] as List?)?.length ?? 0) - 1;

                          return Padding(
                            padding: const EdgeInsets.only(left: 16, bottom: 2),
                            child: Row(
                              children: [
                                Text('${index + 1}.'),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    scopeName,
                                    style: TextStyle(
                                      fontWeight: isTop ? FontWeight.bold : FontWeight.normal,
                                      color: isTop ? Colors.green.shade700 : Colors.black,
                                    ),
                                  ),
                                ),
                                if (isTop)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      'CURRENT',
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ]),

                    const SizedBox(height: 16),

                    // All Scopes
                    _buildSection('All Scopes',
                        (debugData['allScopesInfo'] as List<dynamic>? ?? []).map((scopeInfo) {
                          final name = scopeInfo['name']?.toString() ?? 'Unknown';
                          final id = scopeInfo['id']?.toString() ?? 'Unknown';
                          final disposed = scopeInfo['disposed'] == true;
                          final depCount = scopeInfo['dependencyCount']?.toString() ?? '0';
                          final isZenCurrent = scopeInfo['isZenCurrentScope'] == true;
                          final isActualCurrent = scopeInfo['isActualCurrentScope'] == true;

                          return _buildScopeRow(name, id, disposed, depCount, isZenCurrent, isActualCurrent);
                        }).toList()
                    ),

                    const SizedBox(height: 16),

                    // Errors (if any)
                    if (debugData['error'] != null || debugData['navigationError'] != null)
                      _buildSection('Errors', [
                        if (debugData['error'] != null)
                          _buildErrorRow('General Error', debugData['error'].toString()),
                        if (debugData['navigationError'] != null)
                          _buildErrorRow('Navigation Error', debugData['navigationError'].toString()),
                      ]),

                    const SizedBox(height: 16),

                    // Debug Info
                    _buildSection('Debug Info', [
                      _buildDataRow('Captured At', debugData['timestamp']?.toString().substring(11, 19) ?? 'Unknown'),
                      _buildDataRow('Refresh', 'Manual (click refresh button)'),
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

  Widget _buildCurrentScopeDependencies(Map<String, dynamic> debugData) {
    final breakdown = debugData['actualCurrentScopeBreakdown'] as Map<String, dynamic>?;
    if (breakdown == null) return const SizedBox.shrink();

    final controllers = breakdown['controllers'] as List<dynamic>? ?? [];
    final services = breakdown['services'] as List<dynamic>? ?? [];
    final others = breakdown['others'] as List<dynamic>? ?? [];

    return _buildSection('Current Scope Dependencies', [
      // Toggle between Local vs Available
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blue.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.blue.shade700, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _showAvailableDependencies ? 'Available Dependencies' : 'Local Dependencies',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                  Text(
                    _showAvailableDependencies
                        ? 'All dependencies accessible from this scope (local + inherited)'
                        : 'Dependencies registered directly in this scope only',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.blue.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: _showAvailableDependencies,
              onChanged: (value) => setState(() => _showAvailableDependencies = value),
              activeColor: Colors.blue.shade700,
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),

      if (_showAvailableDependencies)
        ..._buildAvailableDependencies(debugData)
      else
        ..._buildLocalDependencies(controllers, services, others),
    ]);
  }

  List<Widget> _buildLocalDependencies(List<dynamic> controllers, List<dynamic> services, List<dynamic> others) {
    final widgets = <Widget>[];

    if (controllers.isEmpty && services.isEmpty && others.isEmpty) {
      widgets.add(
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.warning_amber, color: Colors.orange.shade700, size: 16),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'No dependencies registered locally in this scope',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      );
      return widgets;
    }

    if (controllers.isNotEmpty) {
      widgets.addAll([
        const Text('Controllers:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
        const SizedBox(height: 4),
        ...controllers.map((controller) => Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 2),
          child: Row(
            children: [
              Icon(Icons.settings, size: 12, color: Colors.blue.shade600),
              const SizedBox(width: 6),
              Text('$controller', style: const TextStyle(fontSize: 12)),
            ],
          ),
        )),
        const SizedBox(height: 8),
      ]);
    }

    if (services.isNotEmpty) {
      widgets.addAll([
        const Text('Services:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
        const SizedBox(height: 4),
        ...services.map((service) => Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 2),
          child: Row(
            children: [
              Icon(Icons.build, size: 12, color: Colors.green.shade600),
              const SizedBox(width: 6),
              Text('$service', style: const TextStyle(fontSize: 12)),
            ],
          ),
        )),
        const SizedBox(height: 8),
      ]);
    }

    if (others.isNotEmpty) {
      widgets.addAll([
        const Text('Others:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
        const SizedBox(height: 4),
        ...others.map((other) => Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 2),
          child: Row(
            children: [
              Icon(Icons.extension, size: 12, color: Colors.orange.shade600),
              const SizedBox(width: 6),
              Text('$other', style: const TextStyle(fontSize: 12)),
            ],
          ),
        )),
      ]);
    }

    return widgets;
  }

  List<Widget> _buildAvailableDependencies(Map<String, dynamic> debugData) {
    // Get available dependencies from ALL scopes in the hierarchy
    final availableDeps = _getAvailableDependencies(debugData);

    final widgets = <Widget>[];

    // Group by type
    final controllers = availableDeps.where((dep) => dep['type'] == 'controller').toList();
    final services = availableDeps.where((dep) => dep['type'] == 'service').toList();
    final others = availableDeps.where((dep) => dep['type'] == 'other').toList();

    if (controllers.isNotEmpty) {
      widgets.addAll([
        Row(
          children: [
            const Text('Controllers:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blue.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${controllers.length}',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ...controllers.map((dep) => _buildAvailableDependencyRow(dep)),
        const SizedBox(height: 8),
      ]);
    }

    if (services.isNotEmpty) {
      widgets.addAll([
        Row(
          children: [
            const Text('Services:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${services.length}',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ...services.map((dep) => _buildAvailableDependencyRow(dep)),
        const SizedBox(height: 8),
      ]);
    }

    if (others.isNotEmpty) {
      widgets.addAll([
        Row(
          children: [
            const Text('Others:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${others.length}',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ...others.map((dep) => _buildAvailableDependencyRow(dep)),
      ]);
    }

    return widgets;
  }

  Widget _buildAvailableDependencyRow(Map<String, dynamic> dep) {
    final name = dep['name'] as String;
    final scope = dep['scope'] as String;
    final isLocal = dep['isLocal'] as bool;
    final type = dep['type'] as String;

    Color iconColor;
    IconData icon;

    switch (type) {
      case 'controller':
        iconColor = Colors.blue.shade600;
        icon = Icons.settings;
        break;
      case 'service':
        iconColor = Colors.green.shade600;
        icon = Icons.build;
        break;
      default:
        iconColor = Colors.orange.shade600;
        icon = Icons.extension;
    }

    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 2),
      child: Row(
        children: [
          Icon(icon, size: 12, color: iconColor),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isLocal ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: isLocal ? Colors.purple.shade100 : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              isLocal ? 'LOCAL' : scope,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: isLocal ? Colors.purple.shade700 : Colors.grey.shade600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _getAvailableDependencies(Map<String, dynamic> debugData) {
    final availableDeps = <Map<String, dynamic>>[];

    // Get current scope name and all scopes info
    final actualCurrentScopeName = debugData['actualCurrentScopeName'] as String?;
    final allScopesInfo = debugData['allScopesInfo'] as List<dynamic>? ?? [];
    final scopeStack = debugData['scopeStack'] as List<dynamic>? ?? [];

    // Get all scopes that are in our hierarchy (from current scope up to root)
    final accessibleScopeNames = <String>{};

    // Add current scope
    if (actualCurrentScopeName != null) {
      accessibleScopeNames.add(actualCurrentScopeName);
    }

    // Add all parent scopes in the stack (scopes below current scope in navigation stack)
    final currentScopeIndex = scopeStack.indexOf(actualCurrentScopeName);
    if (currentScopeIndex != -1) {
      // All scopes from 0 to current index are accessible (parent scopes)
      for (int i = 0; i <= currentScopeIndex; i++) {
        accessibleScopeNames.add(scopeStack[i].toString());
      }
    }

    // Add root scope if not already included
    accessibleScopeNames.add('RootScope');
    accessibleScopeNames.add('AppScope');

    // Now collect dependencies from all accessible scopes
    for (final scopeInfo in allScopesInfo) {
      final scopeName = scopeInfo['name']?.toString() ?? '';
      final breakdown = scopeInfo['breakdown'] as Map<String, dynamic>?;
      final isDisposed = scopeInfo['disposed'] as bool? ?? false;

      // Skip disposed scopes
      if (isDisposed) continue;

      // Only include scopes that are accessible
      if (!accessibleScopeNames.contains(scopeName)) continue;

      if (breakdown != null) {
        final controllers = breakdown['controllers'] as List<dynamic>? ?? [];
        final services = breakdown['services'] as List<dynamic>? ?? [];
        final others = breakdown['others'] as List<dynamic>? ?? [];

        final isCurrentScope = scopeName == actualCurrentScopeName;

        // Add controllers
        for (final controller in controllers) {
          availableDeps.add({
            'name': controller.toString(),
            'type': 'controller',
            'scope': scopeName,
            'isLocal': isCurrentScope,
          });
        }

        // Add services
        for (final service in services) {
          availableDeps.add({
            'name': service.toString(),
            'type': 'service',
            'scope': scopeName,
            'isLocal': isCurrentScope,
          });
        }

        // Add others
        for (final other in others) {
          availableDeps.add({
            'name': other.toString(),
            'type': 'other',
            'scope': scopeName,
            'isLocal': isCurrentScope,
          });
        }
      }
    }

    // Remove duplicates (in case same dependency is registered in multiple scopes)
    final seen = <String>{};
    availableDeps.removeWhere((dep) {
      final key = '${dep['type']}_${dep['name']}';
      if (seen.contains(key)) {
        return true; // Remove duplicate
      }
      seen.add(key);
      return false; // Keep this one
    });

    // Sort by scope (local first, then by scope name)
    availableDeps.sort((a, b) {
      // Local dependencies first
      if (a['isLocal'] && !b['isLocal']) return -1;
      if (!a['isLocal'] && b['isLocal']) return 1;

      // Then by type
      final typeOrder = {'controller': 0, 'service': 1, 'other': 2};
      final aTypeOrder = typeOrder[a['type']] ?? 3;
      final bTypeOrder = typeOrder[b['type']] ?? 3;
      if (aTypeOrder != bTypeOrder) return aTypeOrder.compareTo(bTypeOrder);

      // Finally by name
      return (a['name'] as String).compareTo(b['name'] as String);
    });

    return availableDeps;
  }

  Widget _buildSection(String title, List<Widget> children) {
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
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: DefaultTextStyle(
            style: TextStyle(
              color: Colors.grey.shade800,
              fontSize: 13,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontFamily: 'monospace',
                color: Colors.grey.shade800,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScopeRow(String name, String id, bool disposed, String depCount, bool isZenCurrent, bool isActualCurrent) {
    Color borderColor;
    Color backgroundColor;
    Color textColor;
    String statusLabel;

    if (disposed) {
      borderColor = Colors.red.shade300;
      backgroundColor = Colors.red.shade100;
      textColor = Colors.red.shade800;
      statusLabel = 'DISPOSED';
    } else if (isActualCurrent) {
      borderColor = Colors.green.shade400;
      backgroundColor = Colors.green.shade100;
      textColor = Colors.green.shade800;
      statusLabel = 'ACTUAL CURRENT';
    } else if (isZenCurrent) {
      borderColor = Colors.orange.shade400;
      backgroundColor = Colors.orange.shade100;
      textColor = Colors.orange.shade800;
      statusLabel = 'ZEN CURRENT';
    } else {
      borderColor = Colors.grey.shade300;
      backgroundColor = Colors.grey.shade100;
      textColor = Colors.grey.shade800;
      statusLabel = '';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: backgroundColor,
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Icon(
              disposed
                  ? Icons.delete_outline
                  : isActualCurrent
                  ? Icons.radio_button_checked
                  : isZenCurrent
                  ? Icons.warning
                  : Icons.radio_button_unchecked,
              size: 16,
              color: textColor,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontWeight: isActualCurrent ? FontWeight.bold : FontWeight.w500,
                      color: textColor,
                    ),
                  ),
                  Text(
                    'ID: $id | Deps: $depCount',
                    style: TextStyle(
                      fontSize: 11,
                      color: textColor.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            if (statusLabel.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: disposed
                      ? Colors.red.shade200
                      : isActualCurrent
                      ? Colors.green.shade200
                      : Colors.orange.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorRow(String label, String error) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.red.shade100,
          border: Border.all(color: Colors.red.shade300),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.red.shade800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              error,
              style: TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
                color: Colors.red.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}