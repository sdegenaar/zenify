import 'package:flutter/material.dart';
import 'package:zenify/zenify.dart';

/// A debug panel that displays information about the current scope
class ScopeDebugPanel extends StatelessWidget {
  final bool initiallyExpanded;
  final bool showInternalDetails;

  const ScopeDebugPanel({
    super.key,
    this.initiallyExpanded = false,
    this.showInternalDetails = false,
  });

  @override
  Widget build(BuildContext context) {
    final currentScope = Zen.currentScope;

    return Card(
      margin: EdgeInsets.all(8),
      color: Colors.grey.shade100,
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        title: Row(
          children: [
            Icon(Icons.bug_report, color: Colors.red.shade700),
            const SizedBox(width: 8),
            const Text(
              'Scope Debug Panel',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        subtitle: Text(
          'Current Scope: ${currentScope.name ?? 'Unnamed'}',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildScopeInfo(currentScope),
                if (showInternalDetails) ...[
                  const Divider(),
                  _buildScopeHierarchy(currentScope),
                  const Divider(),
                  _buildRegisteredServices(currentScope),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScopeInfo(ZenScope scope) {
    // Use ZenScopeInspector to get the correct information
    final instances = ZenScopeInspector.getAllInstances(scope);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoRow('Scope ID', scope.id),
        _buildInfoRow('Scope Name', scope.name ?? 'Unnamed'),
        _buildInfoRow('Has Parent', scope.parent != null ? 'Yes' : 'No'),
        _buildInfoRow('Child Scopes', scope.childScopes.length.toString()),
        _buildInfoRow('Registered Services', instances.length.toString()),
      ],
    );
  }

  Widget _buildScopeHierarchy(ZenScope scope) {
    // Calculate hierarchy depth
    int depth = 0;
    ZenScope? parentScope = scope.parent;
    while (parentScope != null) {
      depth++;
      parentScope = parentScope.parent;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Scope Hierarchy',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        _buildInfoRow('Hierarchy Depth', depth.toString()),
        const SizedBox(height: 8),
        Text('Parent Chain:'),
        const SizedBox(height: 4),
        _buildParentChain(scope),
      ],
    );
  }

  Widget _buildParentChain(ZenScope scope) {
    List<ZenScope> parentChain = [];
    ZenScope? current = scope;

    while (current != null) {
      parentChain.add(current);
      current = current.parent;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: parentChain.asMap().entries.map((entry) {
        final index = entry.key;
        final currentScope = entry.value;

        return Padding(
          padding: EdgeInsets.only(left: index * 16.0),
          child: Row(
            children: [
              Icon(
                index == 0 ? Icons.arrow_right : Icons.subdirectory_arrow_right,
                size: 16,
                color: Colors.grey,
              ),
              const SizedBox(width: 4),
              Text(
                currentScope.name ?? 'Unnamed Scope',
                style: TextStyle(
                  fontWeight: index == 0 ? FontWeight.bold : FontWeight.normal,
                  color: index == 0 ? Colors.black : Colors.grey.shade700,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRegisteredServices(ZenScope scope) {
    // Use ZenScopeInspector to get the registered services
    final services = ZenScopeInspector.getAllInstances(scope);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Registered Services',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        if (services.isEmpty)
          const Text('No services registered in this scope')
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: services.entries.map((entry) {
              final serviceName = entry.key.toString().split('.').last;
              return Chip(
                label: Text(
                  serviceName,
                  style: const TextStyle(fontSize: 12),
                ),
                backgroundColor: Colors.blue.shade100,
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
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
