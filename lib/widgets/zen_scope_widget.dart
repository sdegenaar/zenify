// lib/widgets/zen_scope_widget.dart
import 'package:flutter/material.dart';
import '../core/zen_scope.dart';
import '../controllers/zen_controller.dart';
import '../di/zen_di.dart';

/// A widget that creates and manages a ZenScope
///
/// This widget creates a new scope in the hierarchy and automatically
/// disposes it when the widget is removed from the tree.
/// Use this to create component-level isolation for dependencies.
class ZenScopeWidget extends StatefulWidget {
  /// Child widget
  final Widget child;

  /// Optional scope ID
  final String? id;

  /// Optional scope name for easier debugging
  final String? name;

  /// Whether to create a root scope (no parent)
  final bool isRoot;

  /// Optional function to create and register a controller with this scope
  final ZenController Function()? create;

  /// Optional existing scope to use directly
  final ZenScope? scope;

  /// Create a scope widget
  const ZenScopeWidget({
    required this.child,
    this.id,
    this.name,
    this.isRoot = false,
    this.create,
    this.scope,
    super.key,
  });

  @override
  State<ZenScopeWidget> createState() => _ZenScopeWidgetState();

  /// Get the current scope from context
  static ZenScope of(BuildContext context) {
    final inheritedScope = context.dependOnInheritedWidgetOfExactType<_InheritedZenScope>();

    if (inheritedScope == null) {
      throw StateError('No ZenScopeWidget found in the widget tree');
    }

    return inheritedScope.scope;
  }

  /// Get the current scope from context without creating a dependency
  static ZenScope? maybeOf(BuildContext context) {
    final inheritedScope = context.getInheritedWidgetOfExactType<_InheritedZenScope>();
    return inheritedScope?.scope;
  }

  /// Find the root scope in the widget tree hierarchy
  ///
  /// This traverses up the widget tree to find the highest level scope.
  /// Use this when you need to access app-level dependencies from deep
  /// in the widget tree.
  static ZenScope rootOf(BuildContext context) {
    ZenScope? currentScope;

    try {
      currentScope = of(context);
    } catch (_) {
      return Zen.rootScope;
    }

    // Walk up the parent chain until we find the root
    ZenScope result = currentScope;
    while (result.parent != null && result.parent != Zen.rootScope) {
      result = result.parent!;
    }

    return result;
  }
}

class _ZenScopeWidgetState extends State<ZenScopeWidget> {
  late ZenScope scope;

  @override
  void initState() {
    super.initState();
    _initializeScope();
  }

  void _initializeScope() {
    if (widget.scope != null) {
      // Use provided scope directly
      scope = widget.scope!;
      _createAndRegisterController();
    } else if (widget.isRoot) {
      // Create root scope
      scope = ZenScope(
        id: widget.id,
        name: widget.name,
      );
      _createAndRegisterController();
    } else {
      // For non-root scopes, we'll create a temporary scope
      // and update it in didChangeDependencies
      scope = ZenScope(
        id: widget.id,
        name: widget.name ?? 'unnamed-temp',
      );
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // If we're not a root scope and don't have a direct scope,
    // update the scope with the correct parent relationship
    if (!widget.isRoot && widget.scope == null) {
      final parentScope = ZenScopeWidget.maybeOf(context) ?? Zen.rootScope;

      // If we don't have a parent yet, or parent has changed, update it
      if (scope.parent != parentScope) {
        // Create a new scope with the correct parent
        final newScope = ZenScope(
          id: widget.id,
          name: widget.name,
          parent: parentScope,
        );

        // Update scope reference
        scope = newScope;

        // Create and register controller in the new scope
        _createAndRegisterController();
      }
    }
  }

  void _createAndRegisterController() {
    if (widget.create != null) {
      final controller = widget.create!();
      Zen.put(controller, scope: scope);
    }
  }

  @override
  void dispose() {
    scope.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _InheritedZenScope(
      scope: scope,
      child: widget.child,
    );
  }
}

/// InheritedWidget that provides the scope to descendant widgets
class _InheritedZenScope extends InheritedWidget {
  final ZenScope scope;

  const _InheritedZenScope({
    required this.scope,
    required super.child,
  });

  @override
  bool updateShouldNotify(_InheritedZenScope oldWidget) {
    return scope != oldWidget.scope;
  }
}