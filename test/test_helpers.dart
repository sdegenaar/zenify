// test/test_helpers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    final scopeName = 'TestScope-$testName-${DateTime
        .now()
        .microsecondsSinceEpoch}';
    final testScope = ZenScope(name: scopeName);

    return testScope;
  }

  /// Register dependencies without using ZenProvider widget
  static void registerDependencies(Map<Type, Function> dependencies) {
    // Ensure Zen is initialized
    try {
      final container = ProviderContainer();
      Zen.init(container);
    } catch (e) {
      // Already initialized, ignore
    }

    // Clear existing dependencies
    Zen.deleteAll(force: true);

    // Directly register each dependency using Zen.putDependency
    for (final entry in dependencies.entries) {
      final factory = entry.value;
      final instance = factory();
      Zen.putDependency(instance);
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