// lib/widgets/zen_scope_widget.dart
import 'package:flutter/material.dart';
import '../core/zen_scope.dart';
import '../controllers/zen_di.dart';
import '../controllers/zen_controller.dart';

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
  static ZenScope of(BuildContext context, {bool findRoot = false}) {
    final inheritedScope = findRoot
        ? _findRootScopeInheritedWidget(context)
        : context.dependOnInheritedWidgetOfExactType<_InheritedZenScope>();

    if (inheritedScope == null) {
      // If no scope found and we want the root, return global root scope
      if (findRoot) {
        return Zen.rootScope;
      }
      throw StateError('No ZenScopeWidget found in the widget tree');
    }

    return findRoot ? _findRootScope(inheritedScope.scope) : inheritedScope.scope;
  }

  /// Get the current scope from context without creating a dependency
  static ZenScope? maybeOf(BuildContext context, {bool findRoot = false}) {
    final inheritedScope = findRoot
        ? _findRootScopeInheritedWidget(context)
        : context.getInheritedWidgetOfExactType<_InheritedZenScope>();

    if (inheritedScope == null) {
      if (findRoot) {
        return Zen.rootScope;
      }
      return null;
    }

    return findRoot ? _findRootScope(inheritedScope.scope) : inheritedScope.scope;
  }

  /// Find the root scope widget in the widget tree
  static _InheritedZenScope? _findRootScopeInheritedWidget(BuildContext context) {
    _InheritedZenScope? result;

    // Walk up the widget tree to find all scope widgets
    context.visitAncestorElements((element) {
      final widget = element.widget;
      if (widget is _InheritedZenScope) {
        result = widget;
      }
      return true; // Continue visiting
    });

    return result;
  }

  /// Find the root scope in a scope hierarchy
  static ZenScope _findRootScope(ZenScope scope) {
    ZenScope current = scope;
    while (current.parent != null && current.parent != Zen.rootScope) {
      current = current.parent!;
    }
    return current;
  }
}

// lib/widgets/zen_scope_widget.dart
class _ZenScopeWidgetState extends State<ZenScopeWidget> {
  late ZenScope scope;
  ZenController? _createdController;

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
        name: '${widget.name ?? "unnamed"}-temp',
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

      // Create a new scope with the correct parent
      final newScope = ZenScope(
        id: widget.id,
        name: widget.name,
        parent: parentScope,
      );

      // If this is different from our current scope, update it
      if (scope.parent != parentScope) {
        // Update scope reference
        scope = newScope;

        // Create and register controller in the new scope
        _createAndRegisterController();
      }
    }
  }

  void _createAndRegisterController() {
    if (widget.create != null) {
      _createdController = widget.create!();
      if (_createdController != null) {
        Zen.put(_createdController!, scope: scope);
      }
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