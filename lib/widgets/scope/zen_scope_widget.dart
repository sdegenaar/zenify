import 'package:flutter/material.dart';
import 'package:zenify/zenify.dart';

/// Widget-scoped dependency injection provider
///
/// ZenScopeWidget provides a [ZenScope] to its descendants via InheritedWidget.
/// It's the foundational widget for hierarchical dependency injection in Zenify.
///
/// Architecture:
/// - Automatic parent scope discovery from widget tree
/// - Supports both direct scope provision and module-based creation
/// - Clean lifecycle management (widget disposal = scope disposal)
/// - No global state - pure widget tree-based
///
/// Usage patterns:
///
/// **Pattern 1: Provide an existing scope**
/// ```dart
/// final myScope = ZenScope(name: 'MyScope');
/// myScope.put<MyService>(MyService());
///
/// ZenScopeWidget(
///   scope: myScope,
///   child: MyWidget(),
/// )
/// ```
///
/// **Pattern 2: Create scope from module**
/// ```dart
/// ZenScopeWidget(
///   moduleBuilder: () => MyFeatureModule(),
///   scopeName: 'FeatureScope',
///   child: MyFeatureScreen(),
/// )
/// ```
///
/// The scope is automatically disposed when this widget is removed from the tree
/// (only if created by this widget, not if provided externally).
class ZenScopeWidget extends StatefulWidget {
  /// The child widget to which the scope will be provided
  final Widget child;

  /// An existing scope to provide to descendants.
  /// Use this when you already have a scope instance.
  final ZenScope? scope;

  /// A function that creates a module to be registered in a new scope.
  /// Use this for feature modules with dependencies.
  final ZenModule Function()? moduleBuilder;

  /// Optional name for the scope when creating one via moduleBuilder.
  /// Defaults to the module name if not provided.
  final String? scopeName;

  /// Creates a [ZenScopeWidget] that provides a scope to its descendants.
  ///
  /// Either [scope] or [moduleBuilder] must be provided, but not both.
  const ZenScopeWidget({
    super.key,
    required this.child,
    this.scope,
    this.moduleBuilder,
    this.scopeName,
  }) : assert(
            (scope != null && moduleBuilder == null) ||
                (scope == null && moduleBuilder != null),
            'Either scope or moduleBuilder must be provided, but not both');

  /// Finds the nearest [ZenScope] above the given context.
  ///
  /// Returns the scope or throws an exception if none is found.
  static ZenScope of(BuildContext context) {
    final _ZenScopeProvider? provider =
        context.dependOnInheritedWidgetOfExactType<_ZenScopeProvider>();
    if (provider == null) {
      throw ZenScopeNotFoundException(widgetType: 'ZenScopeWidget');
    }
    return provider.scope;
  }

  /// Finds the nearest [ZenScope] above the given context.
  ///
  /// Returns the scope or null if none is found.
  static ZenScope? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_ZenScopeProvider>()
        ?.scope;
  }

  @override
  State<ZenScopeWidget> createState() => _ZenScopeWidgetState();
}

class _ZenScopeWidgetState extends State<ZenScopeWidget> {
  late ZenScope _scope;
  late bool _isOwner; // Track if we created the scope (and should dispose it)
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    // Initialize immediately if we have a direct scope
    if (widget.scope != null) {
      _scope = widget.scope!;
      _isOwner = false;
      _isInitialized = true;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Initialize scope with module if not already done
    if (!_isInitialized && widget.moduleBuilder != null) {
      _initializeScope();
    }
  }

  void _initializeScope() {
    // Auto-discover parent scope from widget tree
    ZenScope? parentScope;
    try {
      if (context.mounted) {
        parentScope = ZenScopeWidget.maybeOf(context);
      }
    } catch (_) {
      // Ignore errors in getting parent scope
    }

    if (parentScope != null) {
      ZenLogger.logDebug('🔗 Found parent scope: ${parentScope.name}');
    }

    // Create a new scope from the module, with parent if available
    final module = widget.moduleBuilder!();
    final scopeName = widget.scopeName ?? module.name;

    // Create the scope with parent
    _scope = ZenScope(name: scopeName, parent: parentScope);

    // Mark as owner since we created it
    _isOwner = true;

    ZenLogger.logDebug(
        '✨ Created scope from module: $scopeName (parent: ${parentScope?.name ?? 'none'})');

    // Register all dependency modules first
    for (final dependency in module.dependencies) {
      ZenLogger.logDebug(
          '📦 Registering dependency module: ${dependency.name}');
      dependency.register(_scope);
    }

    // Then register the main module
    module.register(_scope);
    ZenLogger.logDebug('📦 Registered module: ${module.name}');

    // Run async initialization in the background
    // Dependencies are already registered, so this is for async setup tasks
    _runAsyncInitialization(module);

    _isInitialized = true;
  }

  void _runAsyncInitialization(ZenModule module) {
    // Run async initialization in the background
    (() async {
      try {
        // Initialize dependency modules first
        for (final dependency in module.dependencies) {
          await dependency.onInit(_scope);
          ZenLogger.logDebug(
              '✅ Initialized dependency module: ${dependency.name}');
        }

        // Then initialize the main module
        await module.onInit(_scope);
        ZenLogger.logInfo('✅ Module ${module.name} fully initialized');
      } catch (e, stack) {
        ZenLogger.logError(
            'Module initialization failed for ${module.name}', e, stack);
      }
    })();
  }

  @override
  void didUpdateWidget(ZenScopeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Handle changes to scope or module
    if (widget.scope != oldWidget.scope ||
        widget.moduleBuilder != oldWidget.moduleBuilder) {
      // Dispose the old scope if we own it
      if (_isOwner && !_scope.isDisposed) {
        _scope.dispose();
        ZenLogger.logDebug('🗑️ Disposed old scope: ${_scope.name}');
      }

      // Reset initialization state
      _isInitialized = false;

      // Initialize the new scope
      if (widget.scope != null) {
        _scope = widget.scope!;
        _isOwner = false;
        _isInitialized = true;
      } else {
        _initializeScope();
      }
    }
  }

  @override
  void dispose() {
    // Only dispose the scope if we created it
    if (_isOwner && !_scope.isDisposed) {
      _scope.dispose();
      ZenLogger.logDebug('🗑️ Scope disposed: ${_scope.name}');
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // For moduleBuilder, ensure we wait for initialization
    // This should be instant since registration is synchronous
    if (widget.moduleBuilder != null && !_isInitialized) {
      return const SizedBox.shrink();
    }

    return _ZenScopeProvider(
      scope: _scope,
      child: widget.child,
    );
  }
}

/// Internal InheritedWidget that provides ZenScope to the widget tree.
///
/// This is the core mechanism for hierarchical scope discovery.
/// Widgets can access their nearest ancestor scope using:
/// `context.dependOnInheritedWidgetOfExactType<_ZenScopeProvider>()`.
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
}

/// Extension methods for BuildContext to find a [ZenScope].
extension ZenScopeExtension on BuildContext {
  /// Finds the nearest [ZenScope] above this context.
  ///
  /// This method will look up the widget tree and return the [ZenScope]
  /// provided by the nearest [ZenScopeWidget] ancestor.
  ///
  /// Throws an exception if no [ZenScope] is found.
  ZenScope findScope() {
    return ZenScopeWidget.of(this);
  }

  /// Finds the nearest [ZenScope] above this context, or returns null if none is found.
  ///
  /// Similar to [findScope], but returns null instead of throwing an exception
  /// if no scope is found.
  ZenScope? mayFindScope() {
    return ZenScopeWidget.maybeOf(this);
  }
}
