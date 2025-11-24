import 'package:flutter/material.dart';
import '../../core/core.dart';
import '../../di/zen_di.dart';

/// A stateful widget that creates a ZenScope, initializes a ZenModule,
/// and provides the scope to its child widget tree.
///
/// This widget handles the complete lifecycle of module-based dependency injection:
/// - Creates or inherits a ZenScope with stack-based parent resolution
/// - Registers and initializes a ZenModule
/// - Provides scope access to child widgets
/// - Handles cleanup on disposal
/// - Maintains scope stack for hierarchical inheritance
///
/// Key features:
/// - Stack-based hierarchical scope inheritance
/// - Smart auto-dispose defaults
/// - Comprehensive error handling
/// - Layout-aware loading/error states
/// - Debug logging integration
/// - Automatic cleanup when navigating to routes with useParentScope=false
/// - Proper Zen.currentScope synchronization
///
/// Example usage:
/// ```dart
/// ZenRoute(
///   moduleBuilder: () => MyModule(),
///   page: MyPage(),
///   scopeName: 'MyScope',
///   useParentScope: true,
///   autoDispose: true,
/// )
/// ```
class ZenRoute extends StatefulWidget {
  /// Factory function that creates the module instance.
  /// Called during widget initialization.
  final ZenModule Function() moduleBuilder;

  /// The main content widget that will receive the initialized scope.
  final Widget page;

  /// Optional name for the created scope.
  /// If not provided, a unique name will be generated.
  final String? scopeName;

  /// Whether to automatically dispose the scope when the widget is disposed.
  /// If null, uses smart defaults based on parent scope presence.
  final bool? autoDispose;

  /// Custom error handler for module initialization failures.
  /// If not provided, shows a default error UI with retry option.
  final Widget Function(Object error)? onError;

  /// Custom loading widget shown during module initialization.
  /// If not provided, shows a default loading UI that adapts to layout context.
  final Widget? loadingWidget;

  /// Explicit parent scope to inherit from.
  /// Takes precedence over [useParentScope] auto-discovery.
  final ZenScope? parentScope;

  /// Whether to automatically discover and inherit from parent scope.
  /// Uses stack-based tracking for reliable parent resolution.
  /// When false, this route acts as a "reset point" that cleans up other scopes.
  final bool useParentScope;

  /// Creates a ZenRoute widget.
  ///
  /// The [moduleBuilder] and [page] parameters are required.
  /// All other parameters provide fine-grained control over scope behavior.
  const ZenRoute({
    super.key,
    required this.moduleBuilder,
    required this.page,
    this.scopeName,
    this.autoDispose,
    this.onError,
    this.loadingWidget,
    bool? useParentScope, // nullable parameter
    this.parentScope,
  }) : useParentScope =
            useParentScope ?? (parentScope != null); // smart default!

  @override
  State<ZenRoute> createState() => _ZenRouteState();
}

class _ZenRouteState extends State<ZenRoute> {
  /// The created/retrieved scope instance
  ZenScope? _scope;

  /// The initialized module instance
  ZenModule? _module;

  /// Whether the module is currently being initialized
  bool _isLoading = true;

  /// Any error that occurred during initialization
  Object? _error;

  /// The final scope name being used
  String? _scopeName;

  /// The computed auto-dispose setting
  bool? _effectiveAutoDispose;

  /// The resolved parent scope
  ZenScope? _parentScope;

  /// Prevents multiple initialization attempts
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    // Initialization happens in didChangeDependencies to ensure
    // InheritedWidget context is available
  }

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
      _scopeName = widget.scopeName ??
          'ZenRoute_${widget.page.runtimeType}_${widget.page.hashCode.abs()}';

      // Only clean up stack-tracked scopes, not explicit parent scopes
      if (!widget.useParentScope) {
        ZenLogger.logDebug(
            '🧹 Route with useParentScope=false detected. Cleaning up stack-tracked scopes except current: $_scopeName');
        // Only clean up scopes that are actually in the scope stack
        // This preserves manually created scopes (like explicitParent in tests)
        ZenScopeManager.cleanupStackTrackedScopesExcept(_scopeName!);
      }

      // Rest of the method remains the same...
      // Step 2: Add to scope stack BEFORE resolving parent
      ZenScopeStackTracker.pushScope(_scopeName!,
          useParentScope: widget.useParentScope);

      // Step 3: Resolve parent scope using stack-based tracking
      _resolveParentScope();

      // Step 4: Determine auto-dispose behavior
      _determineAutoDisposeBehavior();

      // Step 5: Create or retrieve the scope
      _scope = ZenScopeManager.getOrCreateScope(
        name: _scopeName!,
        parentScope: _parentScope,
        autoDispose: _effectiveAutoDispose,
        useRootAsDefault: true,
      );

      ZenLogger.logDebug(
          '🔗 Created/retrieved scope: ${_scope!.name} with autoDispose: $_effectiveAutoDispose');
      ZenLogger.logDebug('🔗 Scope parent: ${_scope!.parent?.name ?? 'none'}');
      ZenLogger.logDebug(
          '📚 Current scope stack: ${ZenScopeStackTracker.getCurrentStack().join(' -> ')}');

      // Step 6: Create and initialize the module
      _module = widget.moduleBuilder();
      _module!.register(_scope!);
      await _module!.onInit(_scope!);

      // Update Zen.currentScope to match the scope stack
      if (_scope != null) {
        Zen.setCurrentScope(_scope!);
        ZenLogger.logDebug('🔧 Updated Zen.currentScope to: ${_scope!.name}');
      }

      // Step 7: Update UI to show success
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = null;
        });
      }
    } catch (e, stackTrace) {
      ZenLogger.logError(
          'Error initializing ZenModulePage: $_scopeName', e, stackTrace);

      // Remove from stack on error
      if (_scopeName != null) {
        ZenScopeStackTracker.popScope(_scopeName!);
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e;
        });
      }
    }
  }

  /// Resolve parent scope using stack-based tracking and fallbacks
  void _resolveParentScope() {
    if (widget.parentScope != null) {
      // Explicit parent scope provided
      _parentScope = widget.parentScope;
      ZenLogger.logDebug(
          '🔗 Using explicit parent scope: ${_parentScope!.name}');
    } else if (widget.useParentScope) {
      // Step 1: Try stack-based parent resolution (most reliable)
      _parentScope = _findStackBasedParentScope();

      if (_parentScope != null) {
        ZenLogger.logDebug(
            '🔗 Found stack-based parent scope: ${_parentScope!.name}');
      } else {
        // Step 2: Try widget tree (for nested widgets)
        _parentScope = _ZenScopeProvider.maybeOf(context);

        if (_parentScope != null) {
          ZenLogger.logDebug(
              '🔗 Found parent scope from widget tree: ${_parentScope!.name}');
        } else {
          // Step 3: Fallback to most recent persistent scope
          _parentScope = _findMostRecentPersistentScope();
          if (_parentScope != null) {
            ZenLogger.logDebug(
                '🔗 Found fallback parent scope: ${_parentScope!.name}');
          }
        }
      }

      if (_parentScope == null) {
        ZenLogger.logWarning(
            '⚠️ useParentScope=true but no suitable parent scope found');
      }
    }
  }

  /// Find parent scope using the stack tracker (most reliable method)
  ZenScope? _findStackBasedParentScope() {
    if (_scopeName == null) return null;

    return ZenScopeStackTracker.getParentScopeInstance(_scopeName!);
  }

  /// Find the most recent persistent scope that could serve as a parent (fallback)
  ZenScope? _findMostRecentPersistentScope() {
    final allScopes = ZenScopeManager.getAllScopes()
        .where((scope) => !scope.isDisposed && scope.name != _scopeName)
        .toList();

    if (allScopes.isEmpty) return null;

    // Step 1: Exclude RootScope unless it's the only option
    final featureScopes =
        allScopes.where((s) => s.name != 'RootScope').toList();

    if (featureScopes.isEmpty) {
      // Only RootScope available
      return allScopes.firstWhere((s) => s.name == 'RootScope',
          orElse: () => null as dynamic);
    }

    // Step 2: If only one feature scope exists, use it
    if (featureScopes.length == 1) {
      return featureScopes.first;
    }

    // Step 3: Prefer scopes that are in the current stack
    final stackScopes = featureScopes
        .where((scope) => ZenScopeStackTracker.isActive(scope.name ?? ''))
        .toList();

    if (stackScopes.isNotEmpty) {
      // Sort by stack position (deeper = more recent)
      final stack = ZenScopeStackTracker.getCurrentStack();
      stackScopes.sort((a, b) {
        final aIndex = stack.indexOf(a.name ?? '');
        final bIndex = stack.indexOf(b.name ?? '');
        return bIndex.compareTo(aIndex); // Higher index = more recent
      });
      return stackScopes.first;
    }

    // Step 4: Fallback to most recently created scope
    featureScopes.sort((a, b) {
      final aTime =
          ZenScopeStackTracker.getCreationTime(a.name ?? '') ?? DateTime(1970);
      final bTime =
          ZenScopeStackTracker.getCreationTime(b.name ?? '') ?? DateTime(1970);
      return bTime.compareTo(aTime);
    });

    return featureScopes.first;
  }

  /// Determines auto-dispose behavior using smart defaults
  void _determineAutoDisposeBehavior() {
    if (widget.autoDispose != null) {
      // Explicit setting provided
      _effectiveAutoDispose = widget.autoDispose;
    } else if (widget.useParentScope && _parentScope != null) {
      // Has parent scope - default to persistent (false)
      _effectiveAutoDispose = false;
    } else {
      // No parent scope - default to auto-dispose (true)
      _effectiveAutoDispose = (_parentScope == null);
    }

    ZenLogger.logDebug(
        '🔧 Auto-dispose decision: $_effectiveAutoDispose (parent: ${_parentScope?.name ?? 'none'})');
  }

  @override
  void dispose() {
    // Remove from scope stack first
    if (_scopeName != null) {
      ZenScopeStackTracker.popScope(_scopeName!);

      // Update Zen.currentScope to the new top of stack after popping
      final newCurrentScopeName = ZenScopeStackTracker.getCurrentScope();
      if (newCurrentScopeName != null) {
        final newCurrentScope = ZenScopeManager.getScope(newCurrentScopeName);
        if (newCurrentScope != null) {
          Zen.setCurrentScope(newCurrentScope);
          ZenLogger.logDebug(
              '🔙 Updated Zen.currentScope after pop to: ${newCurrentScope.name}');
        }
      } else {
        // Stack is empty, reset to root scope
        Zen.resetCurrentScope();
        ZenLogger.logDebug('🔙 Reset Zen.currentScope to root (stack empty)');
      }
    }

    // Comprehensive cleanup using ZenScopeManager
    if (_scopeName != null && _effectiveAutoDispose != null) {
      try {
        // Give module a chance to clean up
        if (_module != null && _scope != null) {
          _module!.onDispose(_scope!);
        }

        // Let ZenScopeManager handle all disposal logic
        ZenScopeManager.onWidgetDispose(_scopeName!, _effectiveAutoDispose!);
      } catch (e, stackTrace) {
        ZenLogger.logError(
            'Error disposing ZenModulePage: $_scopeName', e, stackTrace);
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

    // Ensure Zen.currentScope stays synchronized on every build
    if (_scope != null && Zen.currentScope != _scope) {
      Zen.setCurrentScope(_scope!);
      ZenLogger.logDebug(
          '🔄 Re-synchronized Zen.currentScope to: ${_scope!.name}');
    }

    // Success state - provide scope to child widget
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
            'Loading ${_scopeName ?? 'Module'}...',
            style: const TextStyle(color: Colors.grey),
          ),
          // Show scope inheritance info if available
          if (_parentScope != null)
            Text(
              'Inheriting from: ${_parentScope!.name}',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.blue,
                fontStyle: FontStyle.italic,
              ),
            ),
          // Show scope stack for debugging
          if (ZenConfig.logLevel.index >= ZenLogLevel.debug.index &&
              ZenScopeStackTracker.getCurrentStack().isNotEmpty)
            Text(
              'Stack: ${ZenScopeStackTracker.getCurrentStack().join(' -> ')}',
              style: const TextStyle(
                fontSize: 10,
                color: Colors.grey,
                fontStyle: FontStyle.italic,
              ),
            ),
          // Show auto-dispose status for debugging
          if (_effectiveAutoDispose != null)
            Text(
              'Auto-dispose: ${_effectiveAutoDispose! ? 'enabled' : 'disabled'}',
              style: const TextStyle(
                fontSize: 10,
                color: Colors.grey,
                fontStyle: FontStyle.italic,
              ),
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
            onPressed: _initializeModule,
            child: const Text('Retry'),
          ),
        ],
      ),
    );

    return hasScaffold ? content : Scaffold(body: content);
  }
}

/// InheritedWidget that provides ZenScope access to descendant widgets
class _ZenScopeProvider extends InheritedWidget {
  final ZenScope scope;

  const _ZenScopeProvider({
    required this.scope,
    required super.child,
  });

  @override
  bool updateShouldNotify(_ZenScopeProvider oldWidget) {
    return scope != oldWidget.scope;
  }

  static ZenScope? maybeOf(BuildContext context) {
    final provider =
        context.dependOnInheritedWidgetOfExactType<_ZenScopeProvider>();
    return provider?.scope;
  }
}

/// Extension methods for convenient scope access from BuildContext
extension ZenModulePageExtensions on BuildContext {
  /// Gets the current ZenScope from the widget tree
  ZenScope? get zenScope => _ZenScopeProvider.maybeOf(this);

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
