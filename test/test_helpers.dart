// test/test_helpers.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/debug/zen_system_stats.dart';
import 'package:zenify/zenify.dart';

/// Helper class for testing with Zen
class ZenTestHelper {
  /// Creates an isolated test environment with its own scope
  static ZenScope createIsolatedTestScope(String testName) {
    // Ensure Flutter binding is initialized
    TestWidgetsFlutterBinding.ensureInitialized();

    // Initialize Zen if not already done
    try {
      Zen.init();
    } catch (e) {
      // Already initialized, continue
    }

    // Configure Zen for testing environment
    ZenConfig.configureTest();

    // Create a unique test scope that won't conflict with other tests
    final scopeName =
        'TestScope-$testName-${DateTime.now().microsecondsSinceEpoch}';

    // Create scope with root as parent to ensure isolation
    final testScope = Zen.createScope(name: scopeName);

    return testScope;
  }

  /// Register dependencies in a given scope or root scope
  static void registerDependencies(
    Map<Type, Function> dependencies, {
    ZenScope? scope,
  }) {
    final targetScope = scope ?? Zen.rootScope;

    // Register each dependency
    for (final entry in dependencies.entries) {
      final factory = entry.value;
      final instance = factory();

      // Use put for all dependencies
      targetScope.put(instance);
    }
  }

  /// Register dependencies in the root scope (convenience method)
  static void registerGlobalDependencies(Map<Type, Function> dependencies) {
    // Ensure Zen is initialized
    try {
      Zen.init();
    } catch (e) {
      // Already initialized, ignore
    }

    // Clear existing dependencies in root scope
    Zen.deleteAll(force: true);

    // Register each dependency using the root scope API
    for (final entry in dependencies.entries) {
      final factory = entry.value;
      final instance = factory();

      // Use put for all dependencies
      Zen.put(instance);
    }
  }

  /// COMPLETELY REWRITTEN - Reset the entire DI system for a fresh test environment
  static void resetDI() {
    try {
      // Step 1: Force dispose ALL child scopes first (this is critical!)
      _forceDisposeAllChildScopes();

      // Step 2: Clear all dependencies from root scope
      _clearRootScopeDependencies();

      // Step 3: Reset the entire Zen system
      Zen.reset();

      // Step 4: Reinitialize completely
      Zen.init();
      ZenConfig.configureTest();

      // Step 5: Verify clean state
      _verifyCleanState();
    } catch (e) {
      ZenLogger.logError('Error resetting DI system', e);

      // Emergency fallback: try multiple resets
      _emergencyReset();
    }
  }

  /// Force dispose all child scopes - THIS WAS MISSING!
  static void _forceDisposeAllChildScopes() {
    try {
      final rootScope = Zen.rootScope;

      // Get all child scopes and dispose them
      final childScopes = List.from(rootScope
          .childScopes); // Copy list to avoid modification during iteration
      for (final child in childScopes) {
        try {
          if (!child.isDisposed) {
            child.dispose();
          }
        } catch (e) {
          // Continue disposing other children even if one fails
        }
      }
    } catch (e) {
      // Ignore errors here, we'll verify clean state later
    }
  }

  /// Clear all dependencies from root scope
  static void _clearRootScopeDependencies() {
    try {
      // Method 1: Global deleteAll
      Zen.deleteAll(force: true);
    } catch (e) {
      // Ignore
    }

    try {
      // Method 2: Manual cleanup of all known test types
      _manualTestTypeCleanup();
    } catch (e) {
      // Ignore
    }
  }

  /// Verify that we actually have a clean state
  static void _verifyCleanState() {
    try {
      // Check that we have only root scope
      final allScopes = Zen.rootScope.childScopes;
      if (allScopes.isNotEmpty) {
        ZenLogger.logWarning(
            'Warning: Found ${allScopes.length} child scopes after reset');
      }

      // Check that root scope has no TestService instances
      final testServices = ZenSystemStats.findAllInstancesOfType<TestService>();
      if (testServices.isNotEmpty) {
        ZenLogger.logWarning(
            'Warning: Found ${testServices.length} TestService instances after reset');

        // Try one more aggressive cleanup
        _emergencyCleanup();
      }
    } catch (e) {
      ZenLogger.logError('Error verifying clean state', e);
    }
  }

  /// Emergency cleanup when normal reset fails
  static void _emergencyCleanup() {
    try {
      // Force clear all dependencies manually
      final types = [TestService, TestController, DependentService];
      for (final type in types) {
        try {
          // Try deleting untagged
          if (type == TestService) Zen.delete<TestService>();
          if (type == TestController) Zen.delete<TestController>();
          if (type == DependentService) Zen.delete<DependentService>();
        } catch (e) {
          // Continue
        }
      }

      // Clear tagged instances
      final testTags = [
        'tag1',
        'tag2',
        'root-tag',
        'child-tag',
        'grandchild-tag',
        'tagged',
        'test'
      ];
      for (final tag in testTags) {
        try {
          Zen.delete<TestService>(tag: tag);
          Zen.delete<TestController>(tag: tag);
          Zen.delete<DependentService>(tag: tag);
        } catch (e) {
          // Continue
        }
      }
    } catch (e) {
      ZenLogger.logError('Emergency cleanup failed', e);
    }
  }

  /// Emergency reset when everything else fails
  static void _emergencyReset() {
    for (int attempt = 0; attempt < 3; attempt++) {
      try {
        Zen.reset();
        Zen.init();
        ZenConfig.configureTest();

        // Check if it worked
        final testServices =
            ZenSystemStats.findAllInstancesOfType<TestService>();
        if (testServices.isEmpty) {
          return; // Success!
        }
      } catch (e) {
        // Continue trying
      }
    }

    ZenLogger.logError(
        'All reset attempts failed - tests may have contaminated state');
  }

  /// Manual cleanup of all known test types and tags
  static void _manualTestTypeCleanup() {
    try {
      // Delete untagged instances
      Zen.delete<TestService>();
      Zen.delete<TestController>();
      Zen.delete<DependentService>();
    } catch (e) {
      // Ignore
    }

    // Delete tagged instances - cover all possible tags used in tests
    final testTags = [
      'tag1',
      'tag2',
      'root-tag',
      'child-tag',
      'grandchild-tag',
      'tagged',
      'test',
      'service1',
      'service2',
      'controller1',
      'root',
      'child'
    ];

    for (final tag in testTags) {
      try {
        Zen.delete<TestService>(tag: tag);
      } catch (e) {
        // Ignore
      }
      try {
        Zen.delete<TestController>(tag: tag);
      } catch (e) {
        // Ignore
      }
      try {
        Zen.delete<DependentService>(tag: tag);
      } catch (e) {
        // Ignore
      }
    }
  }

  /// Enhanced reset with verification - ULTRA AGGRESSIVE VERSION
  static void resetDIWithVerification() {
    try {
      // Do multiple passes of dependency cleanup only
      for (int i = 0; i < 3; i++) {
        _clearRootScopeDependencies();
      }

      // Now do the full reset
      Zen.reset();
      Zen.init();
      ZenConfig.configureTest();
    } catch (e) {
      ZenLogger.logError('Error resetting DI system with verification', e);

      // Fallback to simple reset
      try {
        Zen.reset();
        Zen.init();
        ZenConfig.configureTest();
      } catch (e2) {
        ZenLogger.logError('Fallback reset also failed', e2);
      }
    }
  }

  /// Create a test scope with predefined dependencies
  static ZenScope createScopeWithDependencies(
    String scopeName,
    Map<Type, Function> dependencies,
  ) {
    final scope = createIsolatedTestScope(scopeName);
    registerDependencies(dependencies, scope: scope);
    return scope;
  }

  /// Dispose a scope and verify it's properly cleaned up
  static void disposeAndVerifyScope(ZenScope scope) {
    expect(scope.isDisposed, isFalse,
        reason: 'Scope should not be disposed before calling dispose');

    scope.dispose();

    expect(scope.isDisposed, isTrue,
        reason: 'Scope should be disposed after calling dispose');
  }

  /// Verify that a dependency exists in a scope
  static void verifyDependencyExists<T>(ZenScope scope, {String? tag}) {
    final dependency = scope.find<T>(tag: tag);
    expect(dependency, isNotNull,
        reason:
            'Dependency $T${tag != null ? ' with tag $tag' : ''} should exist');
  }

  /// Verify that a dependency does not exist in a scope
  static void verifyDependencyNotExists<T>(ZenScope scope, {String? tag}) {
    final dependency = scope.find<T>(tag: tag);
    expect(dependency, isNull,
        reason:
            'Dependency $T${tag != null ? ' with tag $tag' : ''} should not exist');
  }

  /// Create multiple test scopes for hierarchy testing
  static List<ZenScope> createScopeHierarchy(List<String> scopeNames) {
    final scopes = <ZenScope>[];

    for (int i = 0; i < scopeNames.length; i++) {
      final parent = i == 0 ? null : scopes[i - 1];
      final scope = Zen.createScope(
        name: scopeNames[i],
        parent: parent,
      );
      scopes.add(scope);
    }

    return scopes;
  }

  /// Wait for all async operations to complete
  static Future<void> waitForAsyncOperations() async {
    // Wait for microtasks
    await Future.microtask(() {});

    // Wait for a short delay to ensure all operations complete
    await Future.delayed(const Duration(milliseconds: 10));
  }

  /// Helper to verify controller lifecycle
  static Future<void> verifyControllerLifecycle(
      ZenController controller) async {
    // Should be initialized immediately - use the correct getter
    expect(controller.isInitialized, isTrue,
        reason: 'Controller should be initialized');

    // Wait for onReady
    await waitForAsyncOperations();

    // Should be ready now - use the correct getter
    expect(controller.isReady, isTrue, reason: 'Controller should be ready');
  }

  /// Create a mock service for testing
  static TestService createMockService(String value) {
    return TestService(value);
  }

  /// Create a mock controller for testing
  static TestController createMockController(String value) {
    return TestController(value);
  }
}

/// Helper class for testing ZenController lifecycle methods
class ZenLifecycleTestHelper {
  /// Process all lifecycle events
  static Future<void> processLifecycleEvents() async {
    // Wait for microtasks to complete
    await Future.microtask(() {});

    // Wait for post-frame callbacks
    await Future.delayed(const Duration(milliseconds: 50));
  }

  /// Wait for controller to be ready
  static Future<void> waitForControllerReady(ZenController controller) async {
    await processLifecycleEvents();

    // Verify the controller is in the expected state - use correct getters
    expect(controller.isInitialized, isTrue);
    expect(controller.isReady, isTrue);
  }
}

// Test helper classes that can be used across tests
class TestService {
  final String value;
  bool disposed = false;

  TestService(this.value);

  void dispose() {
    disposed = true;
  }
}

class TestController extends ZenController {
  final String value;
  bool initialized = false; // Custom property for test tracking
  bool readyCalled = false; // Custom property for test tracking
  bool disposeMethodCalled = false; // Custom property for test tracking

  TestController(this.value);

  @override
  void onInit() {
    super.onInit();
    initialized = true; // Set our custom tracking property
  }

  @override
  void onReady() {
    super.onReady();
    readyCalled = true; // Set our custom tracking property
  }

  @override
  void onClose() {
    disposeMethodCalled = true; // Set our custom tracking property
    super.onClose();
  }
}

class DependentService {
  final TestService dependency;

  DependentService(this.dependency);
}

// Test module for module testing
class TestModule extends ZenModule {
  @override
  String get name => 'TestModule';

  @override
  void register(ZenScope scope) {
    final service = TestService('from module');
    scope.put<TestService>(service, isPermanent: false);
  }
}

/// Debug test utilities
class ZenDebugTestHelper {
  /// Create a scope with known dependency structure for testing
  static ZenScope createStructuredTestScope(String name) {
    final scope = ZenTestHelper.createIsolatedTestScope(name);

    // Add predictable dependencies
    scope.put<TestService>(TestService('service1'));
    scope.put<TestController>(TestController('controller1'));
    scope.put<TestService>(TestService('service2'), tag: 'tagged');

    return scope;
  }

  /// Verify debug map structure
  static void verifyDebugMapStructure(Map<String, dynamic> debugMap) {
    expect(debugMap, containsPair('scopeInfo', isA<Map<String, dynamic>>()));
    expect(debugMap, containsPair('dependencies', isA<Map<String, dynamic>>()));
    expect(debugMap, containsPair('registeredTypes', isA<List>()));
    expect(debugMap, containsPair('children', isA<List>()));
  }

  /// Verify system stats structure
  static void verifySystemStatsStructure(Map<String, dynamic> stats) {
    expect(stats, containsPair('scopes', isA<Map<String, dynamic>>()));
    expect(stats, containsPair('dependencies', isA<Map<String, dynamic>>()));
    expect(stats, containsPair('performance', isA<Map<String, dynamic>>()));
  }

  /// Create a hierarchy for testing with known structure
  static List<ZenScope> createTestHierarchy() {
    final root = Zen.rootScope;
    final child1 = root.createChild(name: 'child1');
    final child2 = root.createChild(name: 'child2');
    final grandChild = child1.createChild(name: 'grandchild');

    return [root, child1, child2, grandChild];
  }
}
