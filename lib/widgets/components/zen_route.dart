import 'package:flutter/material.dart';
import '../../core/core.dart';
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

      // Step 2: Auto-discover parent scope from widget tree
      final parentFromTree = _ZenScopeProvider.maybeOf(context);

      // STRATEGY: Hybrid Discovery
      // 1. Prefer explicit parent (if passed)
      // 2. Prefer Widget Tree (standard behavior)
      // 3. Fallback to Zen.currentScope (Navigator bridge)
      // 4. Fallback to Root (Global default)
      final parentScope =
          widget.parentScope ?? parentFromTree ?? Zen.currentScope;

      if (widget.parentScope != null) {
        ZenLogger.logDebug(
            '🔗 Using explicit parent scope: ${parentScope.name}');
      } else if (parentFromTree != null) {
        ZenLogger.logDebug(
            '🔗 Found parent scope from widget tree: ${parentScope.name}');
      } else {
        ZenLogger.logDebug(
            '🔗 No parent in widget tree, using fallback (current/root): ${parentScope.name}');
      }

      // Step 3: Create new scope with parent
      _scope = ZenScope(name: scopeName, parent: parentScope);

      // BRIDGE: Update the global "current scope" pointer
      // This ensures the NEXT route pushed from here knows this is the active parent
      Zen.setCurrentScope(_scope!);

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
            'Error disposing module: ${_module!.name}', e, stackTrace);
      }
    }

    if (_scope != null && !_scope!.isDisposed) {
      // BRIDGE: Restore the parent scope as the "current scope"
      // This ensures that when we pop, the "active" scope reverts to the parent.
      if (_scope!.parent != null) {
        Zen.setCurrentScope(_scope!.parent!);
      } else {
        Zen.resetCurrentScope();
      }

      try {
        _scope!.dispose();
        ZenLogger.logDebug('🗑️ Scope disposed: ${_scope!.name}');
      } catch (e, stackTrace) {
        ZenLogger.logError(
            'Error disposing scope: ${_scope!.name}', e, stackTrace);
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
    return _ZenScopeProvider(
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

/// InheritedWidget that provides ZenScope access to descendant widgets
///
/// This is the mechanism that enables hierarchical scope discovery.
/// Child widgets can access their nearest ancestor scope using
/// `_ZenScopeProvider.maybeOf(context)`.
class _ZenScopeProvider extends InheritedWidget {
  final ZenScope scope;

  const _ZenScopeProvider({
    required this.scope,
    required super.child,
  });

  @override
  bool updateShouldNotify(_ZenScopeProvider oldWidget) {
    // Only notify if the scope instance changed
    return scope != oldWidget.scope;
  }

  /// Find the nearest ZenScope from the widget tree
  static ZenScope? maybeOf(BuildContext context) {
    final provider =
        context.dependOnInheritedWidgetOfExactType<_ZenScopeProvider>();
    return provider?.scope;
  }

  /// Find the nearest ZenScope from the widget tree (throws if not found)
  static ZenScope of(BuildContext context) {
    final scope = maybeOf(context);
    if (scope == null) {
      throw Exception(
          'No ZenScope found in widget tree. Wrap your widget with ZenRoute or ZenScopeWidget.');
    }
    return scope;
  }
}

/// Extension methods for convenient scope access from BuildContext
extension ZenRouteExtensions on BuildContext {
  /// Gets the current ZenScope from the widget tree
  ZenScope? get zenScope => _ZenScopeProvider.maybeOf(this);

  /// Gets the current ZenScope from the widget tree (throws if not found)
  ZenScope get zenScopeRequired => _ZenScopeProvider.of(this);

  /// Finds a dependency in the current scope
  T findInScope<T>({String? tag}) {
    final scope = zenScope;
    if (scope == null) {
      throw Exception('No ZenScope found. Use this method within a ZenRoute.');
    }
    final result = scope.find<T>(tag: tag);
    if (result == null) {
      throw Exception(
          'Dependency of type $T${tag != null ? ' with tag $tag' : ''} not found in scope');
    }
    return result;
  }

  /// Finds a dependency in the current scope, returning null if not found
  T? findInScopeOrNull<T>({String? tag}) {
    final scope = zenScope;
    return scope?.find<T>(tag: tag);
  }
}
