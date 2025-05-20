// lib/zenify/testing/zen_test_utilities.dart
import 'package:flutter/material.dart';
import '../controllers/zen_controller.dart';
import '../core/zen_scope.dart';
import '../reactive/rx_value.dart';
import '../core/zen_logger.dart';
import '../core/zen_config.dart';
import '../di/zen_di.dart';

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

  ZenTestContainer() : _scope = Zen.createScope(name: 'TestScope') {
    if (ZenConfig.enableDebugLogs) {
      ZenLogger.logDebug('ZenTestContainer created with scope: $_scope');
    }
  }

  /// Register a dependency or controller
  T register<T>(T Function() factory, {String? tag, bool permanent = false}) {
    if (ZenConfig.enableDebugLogs) {
      ZenLogger.logDebug('Registering $T in test container');
    }

    // Handle ZenController types differently from other dependencies
    if (factory() is ZenController) {
      // Cast both the factory and its return type to the appropriate controller type
      final controllerFactory = factory as ZenController Function();
      final controller = controllerFactory();

      // Use type-specific registration method based on the actual controller type
      final registeredController = Zen.put(
          controller,
          tag: tag,
          permanent: permanent,
          scope: _scope
      );

      return registeredController as T;
    } else {
      // For non-controller types, use putDependency
      return Zen.putDependency<T>(
          factory(),
          tag: tag,
          permanent: permanent,
          scope: _scope
      );
    }
  }

  /// Find a dependency from the test container
  T? find<T>({String? tag}) {
    if (T.toString().contains('ZenController') || T is ZenController) {
      // This is a controller type
      // We need to use Zen.find for controllers
      return Zen.find(tag: tag, scope: _scope) as T?;
    }
    return Zen.findDependency<T>(tag: tag, scope: _scope);
  }

  /// Dispose all dependencies in the test container
  void dispose() {
    if (ZenConfig.enableDebugLogs) {
      ZenLogger.logDebug('Disposing ZenTestContainer');
    }
    _scope.dispose();
  }

  /// Get the test scope
  ZenScope get scope => _scope;
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
  void dispose() {
    // Container is disposed by test
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}