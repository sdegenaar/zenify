import 'package:flutter/material.dart';
import '../../core/core.dart';

import '../scope/zen_provider.dart';
import '../../di/zen_di.dart';

/// Route-scoped dependency injection widget
///
/// ZenRoute creates a new [ZenScope], initializes a [ZenModule] with its dependencies,
/// and provides the scope to its child widget tree via InheritedWidget.
///
/// Architecture:
/// - Automatic parent scope discovery via widget tree (InheritedWidget)
/// - Module-based dependency registration with dependency chaining
/// - Automatic lifecycle management (init → onInit → dispose → onDispose)
/// - Clean disposal when widget is removed from tree
///
/// Features:
/// - **Widget tree-based hierarchy**: No global state, uses InheritedWidget for parent discovery
/// - **Module composition**: Modules can declare dependencies on other modules
/// - **Async initialization**: Supports async onInit() for setup tasks
/// - **Error handling**: Shows error UI with retry button
/// - **Loading state**: Displays loading UI during initialization
///
/// Example:
/// ```dart
/// ZenRoute(
///   moduleBuilder: () => FeatureModule(),
///   page: FeaturePage(),
///   scopeName: 'FeatureScope', // Optional name for debugging
/// )
/// ```
///
/// The scope is automatically disposed when this widget is removed from the tree.
class ZenRoute extends StatefulWidget {
  /// Factory function that creates the module instance
  final ZenModule Function() moduleBuilder;

  /// The main content widget that will receive the initialized scope
  final Widget page;

  /// Optional name for the created scope (useful for debugging)
  final String? scopeName;

  /// Custom error handler for module initialization failures
  final Widget Function(Object error)? onError;

  /// Custom loading widget shown during module initialization
  final Widget? loadingWidget;

  /// Optional explicit parent scope (overrides automatic discovery)
  /// Use this when the widget tree structure doesn't match the logical scope hierarchy
  /// (e.g., navigating across different navigator stacks or detached routes).
  final ZenScope? parentScope;

  const ZenRoute({
    super.key,
    required this.moduleBuilder,
    required this.page,
    this.scopeName,
    this.onError,
    this.loadingWidget,
    this.parentScope,
  });

  @override
  State<ZenRoute> createState() => _ZenRouteState();
}

class _ZenRouteState extends State<ZenRoute> {
  /// The created scope instance
  ZenScope? _scope;

  /// The initialized module instance
  ZenModule? _module;

  /// Whether the module is currently being initialized
  bool _isLoading = true;

  /// Any error that occurred during initialization
  Object? _error;

  /// Prevents multiple initialization attempts
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Only initialize once, when dependencies are available
    if (!_initialized) {
      _initialized = true;
      _initializeModule();
    }
  }

  /// Initializes the module and scope with comprehensive error handling
  Future<void> _initializeModule() async {
    try {
      // Reset state for fresh initialization
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Step 1: Determine scope name
      final scopeName = widget.scopeName ??
          'ZenRoute_${widget.page.runtimeType}_${widget.page.hashCode.abs()}';

      // Step 2: Auto-discover parent scope from widget tree.
      // Resolution order:
      //   1. Explicit parentScope (if passed by caller)
      //   2. Nearest ZenProvider ancestor in the widget tree
      //   3. Zen.rootScope — stable, immutable fallback for top-level routes
      //
      // NOTE: We do NOT fall back to Zen.currentScope (removed in V2).
      // The old Zen.currentScope was a mutable global pointer that changed
      // on every route push, creating hidden cross-route coupling. Zen.rootScope
      // is a fixed, well-known anchor — every scope should live somewhere in the
      // hierarchy, and rootScope is the correct default for top-level routes.
      final parentFromTree = context.zenScope;
      final parentScope = widget.parentScope ?? parentFromTree ?? Zen.rootScope;

      if (widget.parentScope != null) {
        ZenLogger.logDebug(
            '🔗 Using explicit parent scope: ${widget.parentScope!.name}');
      } else if (parentFromTree != null) {
        ZenLogger.logDebug(
            '🔗 Found parent scope from widget tree: ${parentFromTree.name}');
      } else {
        ZenLogger.logDebug(
            '🔗 No parent in widget tree — using rootScope as parent');
      }

      // Step 3: Create new scope with parent
      _scope = ZenScope(name: scopeName, parent: parentScope);

      ZenLogger.logDebug(
          '✨ Created scope: ${_scope!.name} with parent: ${_scope!.parent?.name ?? 'none'}');

      // Step 4: Create and register module
      _module = widget.moduleBuilder();

      // Step 5: Register dependency modules first
      for (final dependency in _module!.dependencies) {
        ZenLogger.logDebug(
            '📦 Registering dependency module: ${dependency.name}');
        dependency.register(_scope!);
      }

      // Step 6: Register the main module
      _module!.register(_scope!);
      ZenLogger.logDebug('📦 Registered module: ${_module!.name}');

      // Step 7: Initialize dependency modules
      for (final dependency in _module!.dependencies) {
        await dependency.onInit(_scope!);
        ZenLogger.logDebug(
            '✅ Initialized dependency module: ${dependency.name}');
      }

      // Step 8: Initialize the main module
      await _module!.onInit(_scope!);
      ZenLogger.logDebug('✅ Initialized module: ${_module!.name}');

      // Step 9: Update UI to show success
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = null;
        });
      }
    } catch (e, stackTrace) {
      ZenLogger.logError(
          'Error initializing ZenRoute: ${widget.scopeName}', e, stackTrace);

      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e;
        });
      }
    }
  }

  @override
  void dispose() {
    // Clean disposal: module cleanup then scope disposal
    if (_module != null && _scope != null) {
      try {
        _module!.onDispose(_scope!);
        ZenLogger.logDebug('🧹 Module disposed: ${_module!.name}');
      } catch (e, stackTrace) {
        ZenLogger.logError(
            // coverage:ignore-line
            'Error disposing module: ${_module!.name}',
            e,
            stackTrace); // coverage:ignore-line
      }
    }

    if (_scope != null && !_scope!.isDisposed) {
      try {
        _scope!.dispose();
        ZenLogger.logDebug('🗑️ Scope disposed: ${_scope!.name}');
      } catch (e, stackTrace) {
        ZenLogger.logError(
            // coverage:ignore-line
            'Error disposing scope: ${_scope!.name}',
            e,
            stackTrace); // coverage:ignore-line
      }
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Handle loading state
    if (_isLoading) {
      return widget.loadingWidget ?? _buildDefaultLoadingWidget(context);
    }

    // Handle error state
    if (_error != null) {
      if (widget.onError != null) {
        return widget.onError!(_error!);
      }
      return _buildDefaultErrorWidget(context);
    }

    // Success state - provide scope to child widget via InheritedWidget
    return ZenScopeProvider(
      scope: _scope!,
      child: widget.page,
    );
  }

  /// Builds a layout-aware default loading widget
  Widget _buildDefaultLoadingWidget(BuildContext context) {
    final hasScaffold = Scaffold.maybeOf(context) != null;

    final content = Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            'Loading ${widget.scopeName ?? _module?.name ?? 'Module'}...',
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );

    return hasScaffold ? content : Scaffold(body: content);
  }

  /// Builds a layout-aware default error widget
  Widget _buildDefaultErrorWidget(BuildContext context) {
    final hasScaffold = Scaffold.maybeOf(context) != null;

    final content = Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error, color: Colors.red, size: 64),
          const SizedBox(height: 16),
          const Text(
            'Failed to load module',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            _error.toString(),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              _initialized = false;
              _initializeModule();
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );

    return hasScaffold ? content : Scaffold(body: content);
  }
}
