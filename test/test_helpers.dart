
// test/test_helpers.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

/// Helper class for testing with Zen
class ZenTestHelper {
  /// Creates an isolated test environment with its own scope
  static ZenScope createIsolatedTestScope(String testName) {
    // Ensure Flutter binding is initialized using TestWidgetsFlutterBinding
    TestWidgetsFlutterBinding.ensureInitialized();

    // Configure Zen for testing environment
    ZenConfig.configureTest();

    // Create a unique test scope that won't conflict with other tests
    final scopeName = 'TestScope-$testName-${DateTime.now().microsecondsSinceEpoch}';

    // Use Zen's createScope method instead of directly instantiating
    final testScope = Zen.createScope(name: scopeName);

    return testScope;
  }

  /// Register dependencies directly without widgets
  static void registerDependencies(Map<Type, Function> dependencies) {
    // Ensure Zen is initialized
    try {
      Zen.init();
    } catch (e) {
      // Already initialized, ignore
    }

    // Clear existing dependencies
    Zen.deleteAll(force: true);

    // Register each dependency using the new unified API
    for (final entry in dependencies.entries) {
      final factory = entry.value;
      final instance = factory();

      // Use put for all dependencies
      // The put method now handles both controllers and regular dependencies
      Zen.put(instance);
    }
  }

  /// Reset the entire DI system for a fresh test environment
  static void resetDI() {
    try {
      // Clear container first to ensure no factories remain
      Zen.container.clear();

      // Dispose existing instances
      Zen.dispose();

      // Re-initialize the scope manager
      ZenScopeManager.instance.initialize();

      // Reset use counts
      ZenScopeManager.instance.resetAllUseCounts();

      // Clear reactive system
      Zen.reactiveSystem.clearListeners();
    } catch (e) {
      ZenLogger.logError('Error resetting DI system', e);
    }
  }
}

/// Helper class for testing ZenController lifecycle methods
class ZenLifecycleTestHelper {
  /// Processes all lifecycle events
  static Future<void> processLifecycleEvents() async {
    // Simply wait for microtasks and a small delay
    await Future.microtask(() {});
    await Future.delayed(const Duration(milliseconds: 50));
  }
}