// lib/widgets/zen_provider.dart
import 'package:flutter/material.dart';
import '../controllers/zen_controller.dart';
import '../controllers/zen_di.dart';
import 'zen_scope_widget.dart';

/// A widget that registers dependencies in the current scope and provides them to child widgets
class ZenProvider extends StatefulWidget {
  /// Child widget
  final Widget child;

  /// Dependencies to register - provide a map of creators
  /// that will be called once to create dependencies
  final Map<Type, Function> dependencies;

  /// Whether to reuse existing dependencies if they already exist in the scope
  final bool reuse;

  const ZenProvider({
    required this.child,
    required this.dependencies,
    this.reuse = true,
    Key? key,
  }) : super(key: key);

  @override
  State<ZenProvider> createState() => _ZenProviderState();
}

class _ZenProviderState extends State<ZenProvider> {
  final List<dynamic> _registeredDependencies = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _registerDependencies();
  }

  void _registerDependencies() {
    final scope = ZenScopeWidget.maybeOf(context) ?? Zen.rootScope;

    for (final entry in widget.dependencies.entries) {
      final factory = entry.value;

      // Check if dependency already exists when reuse is true
      if (widget.reuse) {
        final existing = Zen.findDependency<dynamic>(tag: null, scope: scope);
        if (existing != null) {
          continue; // Skip creation if already exists
        }
      }

      // Create and register the dependency
      final instance = factory();

      // Register with the appropriate method based on type
      if (instance is ZenController) {
        _registeredDependencies.add(
            Zen.put(instance, scope: scope)
        );
      } else {
        _registeredDependencies.add(
            Zen.putDependency(instance, scope: scope)
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}