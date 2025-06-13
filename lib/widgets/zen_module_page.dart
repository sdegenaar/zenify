// lib/widgets/zen_module_page.dart

import 'package:flutter/material.dart';
import '../core/zen_module.dart';
import '../core/zen_scope.dart';
import '../di/zen_di.dart';

/// A widget that creates a scoped environment for a specific module and its page.
/// This is useful for route-specific dependency injection where each route
/// should have its own isolated scope with specific module dependencies.
///
/// Example usage:
/// ```dart
/// ZenModulePage(
///   moduleBuilder: () => HomeModule(),
///   page: const HomePage(),
///   scopeName: 'HomeScope',
/// )
/// ```
class ZenModulePage extends StatefulWidget {
  /// Function that creates the module for this page
  final ZenModule Function() moduleBuilder;

  /// The page widget to display
  final Widget page;

  /// Optional name for the scope (auto-generated if not provided)
  final String? scopeName;

  /// Whether to dispose the scope when this widget is disposed
  final bool autoDispose;

  /// Error widget to show if module loading fails
  final Widget Function(Object error)? onError;

  /// Loading widget to show while module is being loaded
  final Widget? loadingWidget;

  /// Optional parent scope (defaults to root scope)
  final ZenScope? parentScope;

  const ZenModulePage({
    super.key,
    required this.moduleBuilder,
    required this.page,
    this.scopeName,
    this.autoDispose = true,
    this.onError,
    this.loadingWidget,
    this.parentScope,
  });

  @override
  State<ZenModulePage> createState() => _ZenModulePageState();
}

class _ZenModulePageState extends State<ZenModulePage> {
  ZenScope? _scope;
  ZenModule? _module;
  bool _isLoading = true;
  Object? _error;
  String? _scopeName;

  @override
  void initState() {
    super.initState();
    _initializeModule();
  }

  Future<void> _initializeModule() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Generate scope name if not provided
      _scopeName = widget.scopeName ??
          'ZenModulePage_${widget.page.runtimeType}_${DateTime.now().millisecondsSinceEpoch}';

      // Create a new scope for this module with proper parent relationship
      final parentScope = widget.parentScope ?? Zen.rootScope;
      _scope = Zen.createScope(name: _scopeName!, parent: parentScope);

      // Create the module
      _module = widget.moduleBuilder();

      // Register the module's dependencies in the scope
      _module!.register(_scope!);

      // Initialize the module (this returns Future<void>)
      await _module!.onInit(_scope!);

      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = null;
        });
      }
    } catch (e) {
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
    // Clean up the scope and module
    if (_scope != null) {
      try {
        // Dispose the module if it has cleanup logic
        if (_module != null) {
          _module!.onDispose(_scope!);
        }

        // Dispose the scope if auto-dispose is enabled
        if (widget.autoDispose && !_scope!.isDisposed) {
          _scope!.dispose();
        }
      } catch (e) {
        // Log error but don't throw during dispose
        debugPrint('Error disposing ZenModulePage: $e');
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Show loading state
    if (_isLoading) {
      return widget.loadingWidget ??
          const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
    }

    // Show error state
    if (_error != null) {
      if (widget.onError != null) {
        return widget.onError!(_error!);
      }

      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
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
                  setState(() {
                    _isLoading = true;
                    _error = null;
                  });
                  _initializeModule();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    // Provide the scope to the widget tree
    return _ZenScopeProvider(
      scope: _scope!,
      child: widget.page,
    );
  }
}

/// InheritedWidget that provides the current scope to the widget tree
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

  /// Get the current scope from the widget tree
  static ZenScope? maybeOf(BuildContext context) {
    final provider = context.dependOnInheritedWidgetOfExactType<_ZenScopeProvider>();
    return provider?.scope;
  }

  /// Get the current scope from the widget tree, throws if not found
  static ZenScope of(BuildContext context) {
    final scope = maybeOf(context);
    if (scope == null) {
      throw Exception('No ZenScope found in the widget tree. Make sure you are using ZenModulePage.');
    }
    return scope;
  }
}

/// Extension to access the current scope from BuildContext
extension ZenModulePageExtensions on BuildContext {
  /// Get the current ZenScope from the widget tree
  ZenScope? get zenScope => _ZenScopeProvider.maybeOf(this);

  /// Find a dependency in the current scope
  T findInScope<T>({String? tag}) {
    final scope = zenScope;
    if (scope == null) {
      throw Exception('No ZenScope found. Use this method within a ZenModulePage.');
    }
    final result = scope.find<T>(tag: tag);
    if (result == null) {
      throw Exception('Dependency of type $T${tag != null ? ' with tag $tag' : ''} not found in scope');
    }
    return result;
  }

  /// Try to find a dependency in the current scope
  T? findInScopeOrNull<T>({String? tag}) {
    final scope = zenScope;
    return scope?.find<T>(tag: tag);
  }
}

/// Builder widget that provides access to dependencies from the current scope
class ZenScopeBuilder<T> extends StatelessWidget {
  /// Builder function that receives the dependency
  final Widget Function(BuildContext context, T dependency) builder;

  /// Optional tag for the dependency
  final String? tag;

  /// Optional factory function to create the dependency if not found
  final T Function()? create;

  /// Error widget to show if dependency is not found
  final Widget Function(Object error)? onError;

  const ZenScopeBuilder({
    super.key,
    required this.builder,
    this.tag,
    this.create,
    this.onError,
  });

  @override
  Widget build(BuildContext context) {
    try {
      final scope = context.zenScope;
      if (scope == null) {
        throw Exception('No ZenScope found. Use ZenScopeBuilder within a ZenModulePage.');
      }

      T? dependency = scope.find<T>(tag: tag);

      // If not found and we have a factory, create and register it
      if (dependency == null && create != null) {
        final createdDependency = create!();
        scope.put<T>(createdDependency, tag: tag);
        dependency = createdDependency;
      }

      // If still null, throw error
      if (dependency == null) {
        throw Exception('Dependency of type $T${tag != null ? ' with tag $tag' : ''} not found in scope');
      }

      return builder(context, dependency);
    } catch (e) {
      if (onError != null) {
        return onError!(e);
      }

      return Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error, color: Colors.red),
            const SizedBox(height: 8),
            const Text(
              'Dependency Error',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              e.toString(),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
  }
}