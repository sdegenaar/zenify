// lib/widgets/zen_provider.dart
import 'package:flutter/material.dart';
import '../controllers/zen_di.dart';
import '../core/zen_logger.dart';
import '../core/zen_scope.dart';

/// Flag to indicate we're running in a test environment
bool isTestEnvironment = false;

/// A widget that registers dependencies in the current scope and provides them to child widgets
class ZenProvider extends StatefulWidget {
  /// Child widget
  final Widget child;

  /// Dependencies to register - provide a map of creators
  /// that will be called once to create dependencies
  final Map<Type, Object Function()> dependencies;

  /// Whether to reuse existing dependencies if they already exist in the scope
  final bool reuse;

  /// Optional scope to use for registration (defaults to root scope)
  final ZenScope? scope;

  /// Control whether to show verbose logs
  final bool verbose;

  const ZenProvider({
    required this.child,
    required this.dependencies,
    this.reuse = true,
    this.scope,
    this.verbose = false,
    super.key,
  });

  @override
  State<ZenProvider> createState() => _ZenProviderState();
}

class _ZenProviderState extends State<ZenProvider> {
  // Store registered instances for debugging and access
  final Map<Type, dynamic> _registeredInstances = {};

  @override
  void initState() {
    super.initState();
    _registerDependencies();
  }

  void _registerDependencies() {
    // Register each dependency
    for (final entry in widget.dependencies.entries) {
      final type = entry.key;
      final factory = entry.value;

      try {
        // If reuse is enabled, check if dependency already exists in the correct scope
        if (widget.reuse) {
          final existing = widget.scope != null
              ? Zen.findDependencyByType(type, scope: widget.scope)
              : Zen.findDependencyByType(type);

          if (existing != null) {
            // Store in local map for direct access
            _registeredInstances[type] = existing;
            if (widget.verbose) {
              ZenLogger.logDebug('ZenProvider reusing existing $type');
            }
            continue; // Skip to next dependency
          }
        }

        // Create instance
        final instance = factory();

        // Store for debugging and direct access
        _registeredInstances[type] = instance;

        // Log what we're registering (if verbose)
        if (widget.verbose) {
          ZenLogger.logDebug('ZenProvider registering $type in ${isTestEnvironment ? 'test' : 'normal'} mode');
        }

        // Register the dependency in the correct scope
        Zen.putDependency(instance, scope: widget.scope);

        // Verify registration was successful in the correct scope
        final found = widget.scope != null
            ? Zen.findDependencyByType(type, scope: widget.scope)
            : Zen.findDependencyByType(type);

        if (found == null) {
          ZenLogger.logWarning('Failed to register $type - not found after registration');
        }
      } catch (e) {
        ZenLogger.logError('Error registering dependency of type $type', e);
      }
    }
  }

  @override
  void dispose() {
    // Check if we should clean up dependencies when widget is removed
    if (!widget.reuse) {
      for (final type in _registeredInstances.keys) {
        // Only attempt to delete dependencies we registered
        final instance = _registeredInstances[type];
        if (instance != null) {
          try {
            // Clean up dependency in the correct scope
            if (widget.verbose) {
              ZenLogger.logDebug('ZenProvider disposing $type');
            }

            if (widget.scope != null) {
              Zen.deleteByType(type, scope: widget.scope);
            } else {
              Zen.deleteByType(type);
            }
          } catch (e) {
            ZenLogger.logError('Error disposing dependency of type $type', e);
          }
        }
      }
    }
    super.dispose();
  }

  // Provide access to registered instances via InheritedWidget
  // This makes testing more reliable as we can access dependencies directly
  @override
  Widget build(BuildContext context) {
    return _ZenDependencyWidget(
      registeredInstances: _registeredInstances,
      child: widget.child,
    );
  }
}

// InheritedWidget to make dependencies available directly in the widget tree
class _ZenDependencyWidget extends InheritedWidget {
  final Map<Type, dynamic> registeredInstances;

  const _ZenDependencyWidget({
    required this.registeredInstances,
    required super.child,
  });

  static _ZenDependencyWidget? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_ZenDependencyWidget>();
  }

  @override
  bool updateShouldNotify(_ZenDependencyWidget oldWidget) {
    // Only notify if the instances actually changed (not just the reference)
    if (registeredInstances.length != oldWidget.registeredInstances.length) {
      return true;
    }

    // Check if any instances changed
    for (final type in registeredInstances.keys) {
      if (!oldWidget.registeredInstances.containsKey(type) ||
          registeredInstances[type] != oldWidget.registeredInstances[type]) {
        return true;
      }
    }

    return false;
  }

}

/// Special test helper that ensures ZenProvider will work in tests
class ZenTest {
  static bool _isTestEnvironment = false;
  static bool get isTestEnvironment => _isTestEnvironment;

  /// Call this at the start of your test to ensure ZenProvider works correctly
  static void setupTestEnvironment() {
    _isTestEnvironment = true;
  }

  /// Reset test environment
  static void resetTestEnvironment() {
    _isTestEnvironment = false;
  }

  /// Directly access a dependency for testing - bypass the Zen lookup mechanism
  static T? get<T>(BuildContext context) {
    final provider = _ZenDependencyWidget.of(context);
    if (provider != null && provider.registeredInstances.containsKey(T)) {
      return provider.registeredInstances[T] as T;
    }
    return null;
  }
}