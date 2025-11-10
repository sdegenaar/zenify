// lib/testing/zen_test_utilities.dart
import 'package:flutter/material.dart';
import '../controllers/zen_controller.dart';
import '../core/zen_scope.dart';
import '../core/zen_logger.dart';
import '../di/zen_di.dart';
import '../reactive/core/rx_value.dart';

/// Test utility for tracking changes to Rx values
class RxTester<T> {
  final Rx<T> value;
  final List<T> changes = [];
  late final VoidCallback _listener;

  RxTester(this.value) {
    _listener = () => changes.add(value.value);
    value.addListener(_listener);
  }

  void reset() => changes.clear();

  void dispose() => value.removeListener(_listener);

  bool get hasChanged => changes.isNotEmpty;

  T? get lastValue => changes.isEmpty ? null : changes.last;

  bool expectChanges(List<T> expected) {
    if (changes.length != expected.length) return false;
    for (int i = 0; i < changes.length; i++) {
      if (changes[i] != expected[i]) return false;
    }
    return true;
  }
}

/// Test container for integration and widget testing
class ZenTestContainer {
  final ZenScope _scope;

  ZenTestContainer({String? name})
      : _scope = Zen.createScope(name: name ?? 'TestScope') {
    ZenLogger.logDebug(
        'ZenTestContainer created with scope: ${_scope.name} (${_scope.id})');
  }

  /// Register an existing instance
  ///
  /// Use this for eager registration of dependencies.
  T put<T>(T instance, {String? tag, bool isPermanent = false}) {
    ZenLogger.logDebug('Putting $T instance in test container');

    return _scope.put<T>(
      instance,
      tag: tag,
      isPermanent: isPermanent,
    );
  }

  /// Register a lazy factory
  ///
  /// Creates singleton on first access (default behavior).
  /// Set [isPermanent] to true to survive scope cleanup.
  /// Set [alwaysNew] to true to create fresh instance on each find().
  void putLazy<T>(
    T Function() factory, {
    String? tag,
    bool isPermanent = false,
    bool alwaysNew = false,
  }) {
    _scope.putLazy<T>(
      factory,
      tag: tag,
      isPermanent: isPermanent,
      alwaysNew: alwaysNew,
    );

    final behavior = alwaysNew
        ? 'factory (always new)'
        : (isPermanent ? 'permanent' : 'temporary');

    ZenLogger.logDebug('Registered lazy $behavior for $T in test container');
  }

  /// Find a dependency from the test container
  T? find<T>({String? tag}) {
    return _scope.find<T>(tag: tag);
  }

  /// Find a dependency and throw if not found
  T get<T>({String? tag}) {
    final result = find<T>(tag: tag);
    if (result == null) {
      throw Exception(
          'Dependency of type $T${tag != null ? ' with tag $tag' : ''} not found in test container');
    }
    return result;
  }

  /// Check if a dependency exists
  bool exists<T>({String? tag}) {
    return find<T>(tag: tag) != null;
  }

  /// Delete a dependency
  bool delete<T>({String? tag, bool force = false}) {
    return _scope.delete<T>(tag: tag, force: force);
  }

  /// Clear all dependencies
  void clear() {
    final dependencies = _scope.getAllDependencies();
    for (final dependency in dependencies) {
      try {
        // Try to dispose if it's a controller
        if (dependency is ZenController && !dependency.isDisposed) {
          dependency.dispose();
        }
      } catch (e) {
        // Continue clearing even if some fail
        ZenLogger.logDebug(
            'Failed to dispose dependency ${dependency.runtimeType}: $e');
      }
    }

    // Clear the scope's dependencies by getting their types and deleting
    final allDeps = _scope.getAllDependencies();
    for (final dep in allDeps) {
      final tag = _scope.getTagForInstance(dep);
      if (tag != null) {
        _scope.deleteByTag(tag, force: true);
      } else {
        _scope.deleteByType(dep.runtimeType, force: true);
      }
    }

    ZenLogger.logDebug('Cleared all dependencies from test container');
  }

  /// Get all registered dependencies
  List<dynamic> getAllDependencies() {
    return _scope.getAllDependencies();
  }

  /// Dispose all dependencies in the test container
  void dispose() {
    ZenLogger.logDebug('Disposing ZenTestContainer');

    // Dispose the scope
    if (!_scope.isDisposed) {
      _scope.dispose();
    }
  }

  /// Get the test scope
  ZenScope get scope => _scope;

  /// Check if the container is disposed
  bool get isDisposed => _scope.isDisposed;
}

/// Widget for wrapping test widgets with the test container
class ZenTestScope extends StatefulWidget {
  final Widget child;
  final ZenTestContainer container;

  const ZenTestScope({
    required this.child,
    required this.container,
    super.key,
  });

  @override
  State<ZenTestScope> createState() => _ZenTestScopeState();
}

class _ZenTestScopeState extends State<ZenTestScope> {
  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

/// Utility functions for testing
class ZenTestUtils {
  /// Create a test environment with optional setup
  static ZenTestContainer createTestEnvironment({
    String? name,
    void Function(ZenTestContainer container)? setup,
  }) {
    final container = ZenTestContainer(name: name);
    setup?.call(container);
    return container;
  }

  /// Run a test with a clean Zen environment
  static Future<T> runInTestEnvironment<T>(
    Future<T> Function(ZenTestContainer container) test, {
    String? name,
    void Function(ZenTestContainer container)? setup,
  }) async {
    final container = createTestEnvironment(name: name, setup: setup);

    try {
      return await test(container);
    } finally {
      container.dispose();
    }
  }

  /// Wait for all pending reactive updates
  static Future<void> pump() async {
    // Allow any pending microtasks to complete
    await Future.delayed(Duration.zero);
  }

  /// Wait for a specific duration (useful for debounce/throttle testing)
  static Future<void> wait(Duration duration) async {
    await Future.delayed(duration);
  }

  /// Create a mock controller for testing
  ///
  /// This is a convenience method that creates and registers a controller.
  /// Equivalent to: container.put(factory(), tag: tag)
  static T createMockController<T extends ZenController>(
    T Function() factory,
    ZenTestContainer container, {
    String? tag,
  }) {
    final controller = factory();
    container.put<T>(controller, tag: tag);
    return controller;
  }

  /// Verify that a reactive value changes as expected
  static Future<bool> verifyReactiveChanges<T>(
    Rx<T> reactive,
    List<T> expectedChanges,
    Future<void> Function() action,
  ) async {
    final tester = RxTester(reactive);

    try {
      await action();
      await pump(); // Allow updates to propagate

      return tester.expectChanges(expectedChanges);
    } finally {
      tester.dispose();
    }
  }
}

/// Test-specific controller base class with additional utilities
abstract class ZenTestController extends ZenController {
  /// Track all method calls for verification
  final List<String> methodCalls = [];

  /// Track method call with name
  void trackCall(String methodName) {
    methodCalls.add(methodName);
  }

  /// Clear method call history
  void clearCallHistory() {
    methodCalls.clear();
  }

  /// Verify method was called
  bool wasMethodCalled(String methodName) {
    return methodCalls.contains(methodName);
  }

  /// Get call count for method
  int getCallCount(String methodName) {
    return methodCalls.where((call) => call == methodName).length;
  }
}
